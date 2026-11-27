import { describe, expect, test } from "bun:test";
import * as Book from "./qml/fontbook.mjs";

const style = (name: string, more: object = {}) => ({ name, file: "/usr/share/fonts/x.ttf", index: 0, postscript: "X-" + name, format: "TrueType", user: false, ...more });
const family = (name: string, more: object = {}) => ({ family: name, styles: [style("Regular")], user: false, mono: false, color: false, format: "TrueType", scripts: ["latin"], first: "Aa", langs: ["en", "fr"], ...more });

const fonts = [
    family("Inter", { styles: [style("Regular"), style("Bold"), style("Italic")] }),
    family("JetBrains Mono", { mono: true }),
    family("Noto Sans CJK JP", { scripts: ["latin", "cyrillic", "hiragana", "katakana", "han", "hangul"], langs: ["ja", "zh-cn", "ko", "en"] }),
    family("Noto Naskh Arabic", { scripts: ["latin", "arabic"], langs: ["ar", "fa"] }),
    family("Noto Color Emoji", { scripts: ["emoji"], color: true, langs: [] }),
    family("Symbols Only", { scripts: [], first: "☎☺", langs: [] }),
    family("Amiri", { user: true, scripts: ["latin", "arabic"], langs: ["ar", "en"] }),
];

describe("what stands for a typeface", () => {
    test("Latin is Aa", () => expect(Book.sample(fonts[0])).toBe("Aa"));
    test("a name says the script it was drawn for", () => {
        expect(Book.sample(fonts[2])).toBe("あ");
        expect(Book.sample(fonts[3])).toBe("ع");
    });
    test("Arabic letters with Latin beside them and no word in the name: Latin", () => expect(Book.sample(fonts[6])).toBe("Aa"));
    test("an emoji font shows a face", () => expect(Book.sample(fonts[4])).toBe("😀"));
    test("symbols alone show their first two", () => {
        expect(Book.sample(fonts[5])).toBe("☎☺");
        expect(Book.specimen(fonts[5])).toBe("☎☺");
    });
    test("the specimen is the alphabet for Latin, a line of the script otherwise", () => {
        expect(Book.specimen(fonts[0]).split("\n").length).toBe(3);
        expect(Book.specimen(fonts[3])).toBe(Book.scripts.arabic.line);
    });
    test("every script has a name, letters and a line", () => {
        for (const key of Object.keys(Book.scripts)) {
            expect(Book.scripts[key].name.length).toBeGreaterThan(0);
            expect(Book.scripts[key].sample.length).toBeGreaterThan(0);
            expect(Book.scripts[key].line.length).toBeGreaterThan(0);
        }
    });
});

describe("what a place lists", () => {
    test("All Fonts is all of them", () => expect(Book.listed(fonts, { section: "all" }).length).toBe(fonts.length));
    test("My Fonts is the user's", () => expect(Book.listed(fonts, { section: "mine" }).map(f => f.family)).toEqual(["Amiri"]));
    test("Fixed Width", () => expect(Book.listed(fonts, { section: "mono" }).map(f => f.family)).toEqual(["JetBrains Mono"]));
    test("a language takes its regional kinds too", () => {
        expect(Book.listed(fonts, { section: "lang:zh" }).map(f => f.family)).toEqual(["Noto Sans CJK JP"]);
        expect(Book.listed(fonts, { section: "lang:ar" }).map(f => f.family)).toEqual(["Noto Naskh Arabic", "Amiri"]);
    });
    test("a collection lists its members", () => {
        expect(Book.listed(fonts, { section: "collection:Work", collections: { Work: ["Amiri", "Inter", "Gone"] } }).map(f => f.family)).toEqual(["Inter", "Amiri"]);
    });
    test("search takes every word, in names and styles", () => {
        expect(Book.listed(fonts, { section: "all", search: "noto arab" }).map(f => f.family)).toEqual(["Noto Naskh Arabic"]);
        expect(Book.listed(fonts, { section: "all", search: "ITALIC" }).map(f => f.family)).toEqual(["Inter"]);
        expect(Book.listed(fonts, { section: "mine", search: "inter" })).toEqual([]);
    });
});

describe("the sidebar", () => {
    test("no heading without rows", () => {
        expect(Book.sections([{ code: "en", name: "English" }], {}).map(s => s.title)).toEqual(["Fonts", "Languages", "Smart Collections"]);
        expect(Book.sections([], { Work: [] }).map(s => s.title)).toEqual(["Fonts", "Collections", "Smart Collections"]);
    });
    test("a language's badge is its code", () => expect(Book.sections([{ code: "ko", name: "Korean" }], {})[1].items[0].badge).toBe("KO"));
    test("titles", () => {
        expect(Book.sectionTitle("mine", [])).toBe("My Fonts");
        expect(Book.sectionTitle("lang:ko", [{ code: "ko", name: "Korean" }])).toBe("Korean");
        expect(Book.sectionTitle("collection:Work", [])).toBe("Work");
    });
});

describe("words and sizes", () => {
    test("counts", () => {
        expect(Book.stylesText(1)).toBe("1 style");
        expect(Book.stylesText(7)).toBe("7 styles");
        expect(Book.typefacesText(360)).toBe("360 typefaces");
    });
    test("six cards across 781, 18 and a bit apart (macOS 27's window at 1000)", () => {
        const fit = Book.columns(781, 115, 18);
        expect(fit.count).toBe(6);
        expect(fit.gap).toBeCloseTo(18.2, 1);
    });
    test("one card when nothing else fits", () => expect(Book.columns(100, 115, 18)).toEqual({ count: 1, gap: 0 }));
    test("the slider's middle is the measured size", () => {
        expect(Book.cardSize(0.5)).toBe(115);
        expect(Book.sampleSize(0.46)).toBe(33);
        expect(Book.listSize(0)).toBe(13);
        expect(Book.specimenSize(0.34)).toBe(40);
        expect(Book.glyphBox(0.34)).toBe(44);
    });
});

describe("the list's rows", () => {
    test("an opened typeface has its styles under it", () => {
        const rows = Book.rows(fonts.slice(0, 2), ["Inter"]);
        expect(rows.map(r => r.kind)).toEqual(["family", "style", "style", "style", "family"]);
        expect(rows[1].style).toBe("Regular");
        expect(rows[0].styles).toBe(3);
    });
});

describe("the info pane", () => {
    const details = {
        languages: ["English", "French"],
        styles: [
            { name: "Regular", postscript: "Inter-Regular", unique: "Inter Regular 4.0", version: "Version 4.0", glyphs: 2900, file: "/usr/share/fonts/inter/Inter.ttc", copyright: "© Inter", trademark: "", embedding: "Installable embedding.", format: "OpenType TrueType" },
            { name: "Bold", postscript: "Inter-Bold", unique: "Inter Bold 4.0", version: "Version 4.0", glyphs: 2900, file: "/usr/share/fonts/inter/Inter.ttc", copyright: "© Inter", trademark: "", embedding: "Installable embedding.", format: "OpenType TrueType" },
            { name: "Italic", postscript: "Inter-Italic", unique: "Inter Italic 4.0", version: "Version 4.0", glyphs: 2900, file: "/usr/share/fonts/inter/InterItalic.ttc", copyright: "© Inter, italics", trademark: "", embedding: "Installable embedding.", format: "OpenType TrueType" },
        ],
    };
    const told = Book.info(fonts[0], details);
    test("names, one of each style", () => {
        expect(told.identifiers.map(r => r.label)).toEqual(["Family Name", "Style Name", "PostScript Name", "Unique Name"]);
        expect(told.identifiers[1].values.map(v => v.text)).toEqual(["Regular", "Bold", "Italic"]);
    });
    test("what several styles say alike is said once, with how many say it when they differ", () => {
        const copyright = told.usage.find(r => r.label === "Copyright");
        expect(copyright.values).toEqual([{ text: "© Inter", note: "2 styles" }, { text: "© Inter, italics", note: "1 style" }]);
        expect(told.usage.find(r => r.label === "Embedding").values).toEqual([{ text: "Installable embedding.", note: "" }]);
    });
    test("nothing to say, no row", () => expect(told.usage.some(r => r.label === "Trademark")).toBe(false));
    test("details", () => {
        expect(told.details.find(r => r.label === "System Font").values[0].text).toBe("Yes");
        expect(told.details.find(r => r.label === "Glyph Count").values[0].text).toBe("2900");
        expect(told.details.find(r => r.label === "Location").values.length).toBe(2);
    });
    test("languages and scripts", () => {
        expect(told.language[0]).toEqual({ label: "Supported", text: "English • French" });
        expect(told.language[1]).toEqual({ label: "Scripts", text: "Latin" });
    });
    test("a typeface nothing was read of still has its name", () => {
        expect(Book.info(fonts[1], { styles: [], languages: [] }).identifiers[0].values[0].text).toBe("JetBrains Mono");
    });
});

describe("collections", () => {
    test("kept as text; nonsense reads as none", () => {
        expect(Book.parseCollections('{"Work":["Inter",3],"Bad":7}')).toEqual({ Work: ["Inter"] });
        expect(Book.parseCollections("not json")).toEqual({});
        expect(Book.parseCollections("")).toEqual({});
    });
    test("a new one takes a name none has", () => {
        expect(Book.freshName({}, "")).toBe("Untitled");
        expect(Book.freshName({ Untitled: [], "Untitled 2": [] }, "")).toBe("Untitled 3");
    });
    test("made, filled, emptied, renamed, gone: the old value is left as it was", () => {
        const none = {};
        const one = Book.withCollection(none, "Work");
        expect(none).toEqual({});
        const filled = Book.withMember(Book.withMember(one, "Work", "Inter"), "Work", "Inter");
        expect(filled).toEqual({ Work: ["Inter"] });
        expect(one).toEqual({ Work: [] });
        expect(Book.withoutMember(filled, "Work", "Inter")).toEqual({ Work: [] });
        expect(Book.renamed(filled, "Work", " Play ")).toEqual({ Play: ["Inter"] });
        expect(Book.renamed(filled, "Work", "  ")).toBe(filled);
        expect(Book.renamed(Book.withCollection(filled, "Play"), "Work", "Play")["Work"]).toEqual(["Inter"]);
        expect(Book.withoutCollection(filled, "Work")).toEqual({});
    });
    test("names in order", () => expect(Book.collectionNames({ web: [], Fun: [], "Fun 10": [], "Fun 2": [] })).toEqual(["Fun", "Fun 2", "Fun 10", "web"]));
});
