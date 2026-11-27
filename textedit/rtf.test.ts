import { expect, test } from "bun:test";
import { readFileSync } from "node:fs";
// @ts-ignore: a plain module, shared with the QML
import * as Rtf from "./qml/rtf.mjs";

// Cocoa's own RTF (textutil, macOS 27), a byte to a character as the app reads it.
const sample = (name: string) => readFileSync(new URL(`./samples/${name}.rtf`, import.meta.url), "latin1");
const text = (paragraph: any) => paragraph.runs.map((run: any) => run.text).join("");

test("a document from TextEdit: its text, font, tab stop and window", () => {
    const model = Rtf.parse(sample("cocoa-plain"));
    expect(model.paragraphs.map(text)).toEqual([
        "The quick brown fox jumps over the lazy dog.", "",
        "A second paragraph, a little longer than the first one so that it wraps at the edge of the window.",
    ]);
    const first = model.paragraphs[0];
    expect(first.runs[0]).toMatchObject({ family: "Helvetica", size: 12, bold: false, italic: false, color: "", background: "" });
    expect(first.tabs).toEqual([36]);
    expect(first.align).toBe("left");
    expect(model.view).toEqual({ width: 576, height: 420 });
    // The empty paragraph still says what would be typed there.
    expect(model.paragraphs[1].runs).toHaveLength(1);
    expect(model.paragraphs[1].runs[0].family).toBe("Helvetica");
});

test("Cocoa's styles: bold and italic by font name, colors, scripts", () => {
    const model = Rtf.parse(sample("cocoa-styles"));
    const runs = model.paragraphs[0].runs;
    const run = (word: string) => runs.find((r: any) => r.text.trim() === word);
    expect(text(model.paragraphs[0])).toBe("Plain bold italic under strike red yellow x2 H2O");
    expect(run("bold")).toMatchObject({ family: "Helvetica", bold: true, italic: false, size: 16 });
    expect(run("italic")).toMatchObject({ family: "Helvetica", bold: false, italic: true });
    expect(run("under")).toMatchObject({ underline: true, strike: false });
    expect(run("strike")).toMatchObject({ underline: false, strike: true });
    expect(run("red")).toMatchObject({ color: "#fb0007", background: "" });
    expect(run("yellow")).toMatchObject({ background: "#ffff0b" });
    // After the highlight Cocoa writes \cb1, its placeholder: no color.
    expect(run("x")).toMatchObject({ background: "", script: "" });
    expect(runs.filter((r: any) => r.script === "super")[0]).toMatchObject({ text: "2", size: 13.333 });
    expect(runs.filter((r: any) => r.script === "sub")[0]).toMatchObject({ text: "2" });
    expect(runs[runs.length - 1]).toMatchObject({ text: "O", script: "", size: 16 });
});

test("Cocoa's paragraphs: alignment, indents, a line break, escapes", () => {
    const model = Rtf.parse(sample("cocoa-styles"));
    const [, centered, right, justified] = model.paragraphs;
    expect(centered).toMatchObject({ align: "center", after: 24 });
    expect(centered.runs[0]).toMatchObject({ family: "Times", size: 24 });
    expect(text(centered)).toContain("{braces} back\\slash");
    expect(right.align).toBe("right");
    expect(right.runs[0].family).toBe("Courier");
    expect(justified).toMatchObject({ align: "justify", left: 48, first: 24, spacing: 1 });
    expect(text(justified)).toBe("Justified and spaced, with a line break inside.");
});

test("Cocoa's lists: markers, levels, and no item after the last", () => {
    const model = Rtf.parse(sample("cocoa-styles"));
    const items = model.paragraphs.filter((p: any) => p.list);
    expect(items.map((p: any) => [text(p), p.list.marker, p.list.level, p.list.id])).toEqual([
        ["One", "disc", 0, 1], ["Two", "disc", 0, 1], ["Nested", "circle", 1, 1], ["First", "decimal", 0, 2], ["Second", "decimal", 0, 2],
    ]);
    // The marker Cocoa writes as text ({\listtext …}) is not the item's.
    expect(items.every((p: any) => p.left === 0 && p.first === 0)).toBe(true);
    const last = model.paragraphs[model.paragraphs.length - 1];
    expect(text(last)).toBe("");
    expect(last.list).toBeNull();
    // What is typed there next is in the font the text ended in.
    expect(last.runs[0]).toMatchObject({ family: "Times", size: 12 });
});

test("other scripts: Windows-1252 bytes, \\u with no stand-in, surrogate pairs", () => {
    const model = Rtf.parse(sample("cocoa-scripts"));
    expect(text(model.paragraphs[0])).toBe("Café — “quotes” 日本語のテキスト 한국어 中文 😀 naïve");
});

test("bytes of a font's own code page go through the decoder", () => {
    const shiftJis = (page: number, bytes: number[]) => page === 932 ? new TextDecoder("shift_jis").decode(new Uint8Array(bytes)) : null;
    const rtf = "{\\rtf1\\ansi\\ansicpg1252{\\fonttbl\\f0\\fswiss\\fcharset0 Helvetica;\\f1\\fnil\\fcharset128 HiraginoSans-W3;}"
        + "\\f0\\fs24 A \\f1 \\'93\\'fa\\'96\\'7b\\f0  B \\'e9}";
    const model = Rtf.parse(rtf, shiftJis);
    expect(text(model.paragraphs[0])).toBe("A 日本 B é");
    expect(model.paragraphs[0].runs[1].family).toBe("Hiragino Sans");
    // Mac OS Roman, as old Mac files have it.
    expect(text(Rtf.parse("{\\rtf1\\mac{\\fonttbl\\f0 Geneva;}\\f0 caf\\'8e \\'d2x\\'d3}").paragraphs[0])).toBe("café “x”");
});

test("Word's RTF: its tables and fields are passed over, its text kept", () => {
    const rtf = "{\\rtf1\\ansi\\deff0{\\fonttbl{\\f0\\froman\\fcharset0 Times New Roman;}{\\f1\\fswiss\\fcharset0 Arial{\\*\\falt Helvetica};}}"
        + "{\\colortbl;\\red255\\green0\\blue0;}{\\stylesheet{\\s0 Normal;}{\\s1 heading 1;}}{\\info{\\title A title}{\\author Someone}}"
        + "{\\*\\generator Msftedit;}\\pard\\qc\\b\\f1\\fs28 Heading\\b0\\par\n"
        + "\\pard\\f0\\fs24 An em dash \\u8212\\'97 and a {\\field{\\*\\fldinst HYPERLINK \"http://example.com\"}{\\fldrslt{\\ul\\cf1 link}}} here.\\par\n"
        + "{\\pict\\wmetafile8 0102030405}Caf\\'e9\\~au\\_lait \\emdash  \\ldblquote q\\rdblquote\\par}";
    const model = Rtf.parse(rtf);
    expect(model.paragraphs.map(text)).toEqual(["Heading", "An em dash — and a link here.", "Café au‑lait — “q”", ""]);
    expect(model.paragraphs[0]).toMatchObject({ align: "center" });
    expect(model.paragraphs[0].runs[0]).toMatchObject({ family: "Arial", size: 14, bold: true });
    expect(model.paragraphs[1].runs.find((r: any) => r.text === "link")).toMatchObject({ underline: true, color: "#ff0000", family: "Times New Roman" });
    expect(model.paragraphs[1].runs[0]).toMatchObject({ underline: false, color: "" });
});

test("font names: PostScript ones come apart into family and style", () => {
    expect(Rtf.fontFromName("Helvetica-BoldOblique")).toEqual({ family: "Helvetica", bold: true, italic: true });
    expect(Rtf.fontFromName("HelveticaNeue-Light")).toEqual({ family: "Helvetica Neue", bold: false, italic: false });
    expect(Rtf.fontFromName("TimesNewRomanPS-ItalicMT")).toEqual({ family: "Times New Roman", bold: false, italic: true });
    expect(Rtf.fontFromName("TimesNewRomanPSMT")).toEqual({ family: "Times New Roman", bold: false, italic: false });
    expect(Rtf.fontFromName("ArialMT")).toEqual({ family: "Arial", bold: false, italic: false });
    expect(Rtf.fontFromName("Menlo-Regular")).toEqual({ family: "Menlo", bold: false, italic: false });
    expect(Rtf.fontFromName("Times New Roman")).toEqual({ family: "Times New Roman", bold: false, italic: false });
    expect(Rtf.fontFromName("Inter Variable")).toEqual({ family: "Inter Variable", bold: false, italic: false });
    expect(Rtf.fontFromName("Source-Code")).toEqual({ family: "Source-Code", bold: false, italic: false });
});

test("what is written reads back the same", () => {
    for (const name of ["cocoa-plain", "cocoa-styles", "cocoa-scripts"]) {
        const model = Rtf.parse(sample(name));
        const again = Rtf.parse(Rtf.write(model));
        expect(again).toEqual(model);
    }
});

test("writing: seven-bit, Cocoa's words, a list's numbers as text for readers without lists", () => {
    const run = (text: string, more = {}) => ({ text, family: "Helvetica", size: 12, bold: false, italic: false, underline: false, strike: false,
                                                 color: "", background: "", script: "", ...more });
    const paragraph = (runs: any[], more = {}) => ({ align: "left", left: 0, first: 0, right: 0, before: 0, after: 0, spacing: 1, tabs: [], list: null, runs, ...more });
    const model = {
        view: { width: 576, height: 420 },
        paragraphs: [
            paragraph([run("Naïve "), run("bold", { bold: true }), run(" “x” 😀 {a}\\b")], { spacing: 1.5, align: "center" }),
            paragraph([run("one")], { list: { marker: "lower-roman", level: 0, id: 1 } }),
            paragraph([run("two", { background: "#ffff00" })], { list: { marker: "lower-roman", level: 0, id: 1 } }),
            paragraph([run("after", { size: 10.25 })]),
        ],
    };
    const rtf = Rtf.write(model);
    expect(/^[\x09\x0a\x20-\x7e]*$/.test(rtf)).toBe(true);
    expect(rtf.startsWith("{\\rtf1\\ansi\\ansicpg1252\\cocoartf")).toBe(true);
    expect(rtf).toContain("\\vieww11520\\viewh8400");
    expect(rtf).toContain("\\sl360\\slmult1\\qc");
    expect(rtf).toContain("\\b bold\\b0  \\u8220?x\\u8221? \\u-10179?\\u-8704? \\{a\\}\\\\b");
    expect(rtf).toContain("{\\*\\levelmarker \\{lower-roman\\}.}");
    expect(rtf).toContain("\\ls1\\ilvl0 {\\listtext\\tab ii.\\tab }");
    expect(rtf).toContain("\\fs21\\fsmilli10250");
    // The highlight ends with Cocoa's placeholder color.
    expect(rtf).toContain("\\cb2 two\\\n");
    expect(rtf).toContain("\\cb1 after");
    expect(Rtf.parse(rtf)).toEqual(model);
    expect(Rtf.plain(model)).toBe("Naïve bold “x” 😀 {a}\\b\none\ntwo\nafter");
});

test("a list's numbers", () => {
    expect([1, 4, 9, 14, 40].map(n => Rtf.ordinal("lower-roman", n))).toEqual(["i.", "iv.", "ix.", "xiv.", "xl."]);
    expect([1, 26, 27, 52, 53].map(n => Rtf.ordinal("upper-alpha", n))).toEqual(["A.", "Z.", "AA.", "AZ.", "BA."]);
    expect(Rtf.ordinal("decimal", 12)).toBe("12.");
    expect(Rtf.ordinal("disc", 3)).toBe("•");
});
