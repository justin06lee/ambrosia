import { describe, expect, test } from "bun:test";
import * as Notes from "./qml/notes.mjs";

const run = (text: string, more: object = {}) => ({ text, bold: false, italic: false, underline: false, strike: false, ...more });
const para = (kind: string, runs: object[] | string, more: object = {}) =>
    ({ kind, level: 0, checked: false, quote: false, runs: typeof runs === "string" ? (runs === "" ? [] : [run(runs)]) : runs, ...more });
const note = (paragraphs: object[], more: object = {}) =>
    ({ created: Date.UTC(2026, 10, 20, 9, 0, 0), modified: Date.UTC(2026, 10, 28, 3, 40, 0), pinned: false, deleted: 0, from: "", extra: [], paragraphs, ...more });
const body = (text: string) => text.split("\n").slice(text.split("\n").indexOf("---", 1) + 1).join("\n");
const there = (n: object) => Notes.parse(Notes.serialize(n), 0);

describe("the file", () => {
    test("a note is written as Markdown under its dates", () => {
        const text = Notes.serialize(note([
            para("title", "Shopping"),
            para("body", [run("Buy "), run("two", { bold: true }), run(" of "), run("each", { italic: true })]),
            para("body", ""),
            para("heading", "Greens"),
            para("check", "Leeks", { checked: true }),
            para("check", "Kale"),
            para("subheading", "Later"),
            para("bullet", "one"),
            para("dash", "two", { level: 1 }),
            para("number", "first"),
            para("number", "second"),
        ], { pinned: true }));
        expect(text).toBe([
            "---", "created: 2026-11-20T09:00:00.000Z", "modified: 2026-11-28T03:40:00.000Z", "pinned: true", "---",
            "# Shopping", "Buy **two** of *each*", "", "## Greens", "- [x] Leeks", "- [ ] Kale", "### Later", "* one", "\t- two", "1. first", "2. second", "",
        ].join("\n"));
    });

    test("what is written reads back the same", () => {
        const written = note([
            para("title", [run("A "), run("big", { underline: true }), run(" day")]),
            para("body", [run("plain "), run("bold", { bold: true }), run("both", { bold: true, italic: true }), run("italic", { italic: true }), run(" end")]),
            para("body", [run("struck", { strike: true }), run(" and "), run("all", { bold: true, italic: true, underline: true, strike: true })]),
            para("body", ""),
            para("body", "\tindented by hand"),
            para("mono", "let a = b * c;"),
            para("mono", ""),
            para("mono", "  ``` not the end"),
            para("check", "done", { checked: true, level: 2 }),
            para("number", "one", { quote: true }),
            para("body", "quoted", { quote: true }),
            para("mono", "quoted code", { quote: true }),
            para("body", ""),
        ], { pinned: true });
        expect(there(written)).toEqual(written);
    });

    test("text that looks like a mark stays text", () => {
        for (const text of ["- not a list", "* nor this", "+ nor this", "# not a heading", "> not a quote", "1. not numbered", "12) nor this", "```", "-", ">",
                            "2 * 3 * 4", "a ** b", "snake_case and _private and __init__", "a ~~ b ~~~ c", "<u>not underlined</u>", "back\\slash \\* star",
                            "[ ] not a box", "---", "   three spaces", "ends in a space ", "**", "*", "_", "~~"]) {
            const written = note([para("title", "T"), para("body", text)]);
            expect(there(written).paragraphs[1]).toEqual(para("body", text));
        }
        const dash = note([para("dash", "[ ] not a box"), para("bullet", "[x] nor this")]);
        expect(there(dash).paragraphs).toEqual(dash.paragraphs);
    });

    test("a mark never opens before a space nor closes after one", () => {
        const written = note([para("body", [run("a"), run(" bold ", { bold: true }), run("b "), run("x", { italic: true }), run(" ", { italic: true }), run("y", { italic: true })])]);
        const text = body(Notes.serialize(written));
        expect(text).toBe("a **bold** b *x y*\n");
        expect(there(written).paragraphs[0].runs.map((r: { text: string }) => r.text).join("")).toBe("a bold b x y");
    });

    test("marks that change one inside another", () => {
        const written = note([para("body", [run("i", { italic: true }), run("ib", { italic: true, bold: true }), run("b", { bold: true }), run("n")])]);
        expect(there(written)).toEqual(written);
        const more = note([para("body", [run("bu", { bold: true, underline: true }), run("u", { underline: true }), run("us", { underline: true, strike: true }), run("s", { strike: true })])]);
        expect(there(more)).toEqual(more);
    });

    test("another app's Markdown is read sensibly", () => {
        const read = Notes.parse("# Title\r\n\r\nSome _emphasis_ and __init__.\n  - nested\n    * deeper\n3) third\n#### Small\n- [X] Done\n```js\ncode *here*\n```\nlast", 1000);
        expect(read.created).toBe(1000);
        expect(read.modified).toBe(1000);
        expect(read.paragraphs.map((p: { kind: string }) => p.kind)).toEqual(["title", "body", "body", "dash", "bullet", "number", "subheading", "check", "mono", "body"]);
        expect(read.paragraphs[2].runs).toEqual([run("Some "), run("emphasis", { italic: true }), run(" and __init__.")]);
        expect(read.paragraphs[3].level).toBe(1);
        expect(read.paragraphs[4].level).toBe(1);
        expect(read.paragraphs[7].checked).toBe(true);
        expect(Notes.textOf(read.paragraphs[8])).toBe("code *here*");
    });

    test("an empty file is a note of one empty paragraph; lines it doesn't know are kept", () => {
        expect(Notes.parse("", 5).paragraphs).toEqual([para("body", "")]);
        const read = Notes.parse("---\ncreated: 2026-01-02T03:04:05.000Z\ntags: a, b\npinned: true\n---\nHello\n", 9);
        expect(read.created).toBe(Date.UTC(2026, 0, 2, 3, 4, 5));
        expect(read.modified).toBe(9);
        expect(read.extra).toEqual(["tags: a, b"]);
        expect(Notes.serialize(read)).toContain("\ntags: a, b\n---\nHello\n");
    });

    test("a deleted note remembers when and from where", () => {
        const gone = note([para("title", "Old")], { deleted: Date.UTC(2026, 10, 27), from: "Work" });
        const back = there(gone);
        expect(back.deleted).toBe(Date.UTC(2026, 10, 27));
        expect(back.from).toBe("Work");
    });
});

describe("a note's name", () => {
    test("the first line that says something, and the next", () => {
        const n = note([para("body", "  "), para("title", [run("Trip "), run("plan", { bold: true })]), para("body", ""), para("check", "pack\tbags"), para("body", "more")]);
        expect(Notes.titleOf(n)).toBe("Trip plan");
        expect(Notes.snippetOf(n)).toBe("pack bags");
        expect(Notes.isEmpty(n)).toBe(false);
    });
    test("nothing written", () => {
        const n = note([para("title", ""), para("body", "  ")]);
        expect(Notes.titleOf(n)).toBe("New Note");
        expect(Notes.snippetOf(n)).toBe("No additional text");
        expect(Notes.isEmpty(n)).toBe(true);
        expect(Notes.snippetOf(note([para("title", "Only")]))).toBe("No additional text");
    });
});

// Saturday, November 28, 2026, 3:40 in the afternoon, here.
const now = new Date(2026, 10, 28, 15, 40).getTime();
const at = (y: number, m: number, d: number, h = 12, min = 0) => new Date(y, m - 1, d, h, min).getTime();
const row = (id: string, modified: number, more: object = {}) =>
    ({ folder: "Notes", id, created: modified, modified, pinned: false, deleted: 0, from: "", title: id, snippet: "", plain: id.toLowerCase(), ...more });

describe("dates", () => {
    test("a row's date", () => {
        expect(Notes.rowDate(at(2026, 11, 28, 3, 5), now, false)).toBe("3:05 AM");
        expect(Notes.rowDate(at(2026, 11, 28, 0, 0), now, false)).toBe("12:00 AM");
        expect(Notes.rowDate(at(2026, 11, 28, 13, 7), now, false)).toBe("1:07 PM");
        expect(Notes.rowDate(at(2026, 11, 28, 13, 7), now, true)).toBe("13:07");
        expect(Notes.rowDate(at(2026, 11, 27, 23, 59), now, false)).toBe("Yesterday");
        expect(Notes.rowDate(at(2026, 11, 25), now, false)).toBe("Wednesday");
        expect(Notes.rowDate(at(2026, 11, 22), now, false)).toBe("Sunday");
        expect(Notes.rowDate(at(2026, 11, 21), now, false)).toBe("11/21/26");
        expect(Notes.rowDate(at(2025, 3, 4), now, false)).toBe("3/4/25");
    });
    test("over a note", () => {
        expect(Notes.longDate(at(2026, 11, 28, 3, 40), false)).toBe("November 28, 2026 at 3:40 AM");
        expect(Notes.longDate(at(2026, 1, 5, 15, 4), true)).toBe("January 5, 2026 at 15:04");
    });
});

describe("the list", () => {
    const rows = [
        row("today-early", at(2026, 11, 28, 1)), row("today-late", at(2026, 11, 28, 14)), row("yesterday", at(2026, 11, 27)),
        row("week", at(2026, 11, 22)), row("week-edge", at(2026, 11, 21)), row("month", at(2026, 11, 1)), row("month-edge", at(2026, 10, 29)),
        row("october", at(2026, 10, 28)), row("march", at(2026, 3, 3)), row("last-year", at(2025, 12, 31)), row("old", at(2019, 6, 1)),
        row("pinned-old", at(2020, 1, 1), { pinned: true }), row("pinned-new", at(2026, 11, 28, 9), { pinned: true }),
    ];
    test("sections by date, pinned first", () => {
        const made = Notes.sections(rows, now, "edited", true);
        expect(made.map((s: { title: string, rows: { id: string }[] }) => [s.title, s.rows.map(r => r.id)])).toEqual([
            ["Pinned", ["pinned-new", "pinned-old"]],
            ["Today", ["today-late", "today-early"]],
            ["Yesterday", ["yesterday"]],
            ["Previous 7 Days", ["week", "week-edge"]],
            ["Previous 30 Days", ["month", "month-edge"]],
            ["October", ["october"]],
            ["March", ["march"]],
            ["2025", ["last-year"]],
            ["2019", ["old"]],
        ]);
    });
    test("by name, or not grouped: one heading, shown only under pinned ones", () => {
        const byTitle = Notes.sections(rows, now, "title", true);
        expect(byTitle.map((s: { title: string }) => s.title)).toEqual(["Pinned", "Notes"]);
        expect(byTitle[1].rows[0].id).toBe("last-year");
        const plain = Notes.sections(rows.filter(r => !r.pinned), now, "edited", false);
        expect(plain.map((s: { title: string }) => s.title)).toEqual([""]);
        expect(Notes.sections([], now, "edited", true)).toEqual([]);
        const deleted = Notes.sections(rows, now, "edited", true, false);
        expect(deleted[0].title).toBe("Today");
        expect(deleted[0].rows.map((r: { id: string }) => r.id)).toEqual(["today-late", "pinned-new", "today-early"]);
    });
    test("by the day made", () => {
        const two = [row("a", at(2026, 11, 28), { created: at(2026, 1, 1) }), row("b", at(2026, 1, 1), { created: at(2026, 11, 28) })];
        expect(Notes.sections(two, now, "created", true).map((s: { title: string, rows: { id: string }[] }) => [s.title, s.rows[0].id])).toEqual([["Today", "b"], ["January", "a"]]);
    });
    test("searching: every word, anywhere", () => {
        const some = [row("a", now, { plain: "trip plan\npack bags" }), row("b", now, { plain: "plan the party" }), row("c", now, { plain: "bags" })];
        expect(Notes.found(some, "PLAN  ba").map((r: { id: string }) => r.id)).toEqual(["a"]);
        expect(Notes.found(some, "plan").map((r: { id: string }) => r.id)).toEqual(["a", "b"]);
        expect(Notes.found(some, "  ").length).toBe(3);
    });
    test("how many", () => {
        expect(Notes.countText(0)).toBe("No Notes");
        expect(Notes.countText(1)).toBe("1 note");
        expect(Notes.countText(42)).toBe("42 notes");
    });
});

describe("folders", () => {
    const rows = [row("a", now), row("b", now, { folder: "Work" }), row("c", now, { folder: "Work" }), row("d", now, { folder: ".deleted", deleted: now - 31 * 86400000 }),
                  row("e", now, { folder: ".deleted", deleted: now - 29 * 86400000 })];
    test("the sidebar", () => {
        expect(Notes.sidebar(["Notes"], [row("a", now)]).map((r: { name: string, count: number }) => [r.name, r.count])).toEqual([["Notes", 1]]);
        expect(Notes.sidebar(["work b", "Notes", ".deleted", "Work", "art"], rows).map((r: { name: string, count: number }) => [r.name, r.count])).toEqual([
            ["All On My Computer", 3], ["Notes", 1], ["art", 0], ["Work", 2], ["work b", 0], ["Recently Deleted", 2],
        ]);
    });
    test("what is in one", () => {
        expect(Notes.inFolder(rows, "*").map((r: { id: string }) => r.id)).toEqual(["a", "b", "c"]);
        expect(Notes.inFolder(rows, "Work").length).toBe(2);
        expect(Notes.inFolder(rows, ".deleted").length).toBe(2);
    });
    test("names", () => {
        expect(Notes.nameFault(" ", [])).not.toBe("");
        expect(Notes.nameFault("a/b", [])).not.toBe("");
        expect(Notes.nameFault(".hidden", [])).not.toBe("");
        expect(Notes.nameFault("work", ["Notes", "Work"])).toBe("That name is taken.");
        expect(Notes.nameFault("Recently Deleted", [])).toBe("That name is taken.");
        expect(Notes.nameFault("Recipes", ["Notes", "Work"])).toBe("");
        expect(Notes.freeName(["Notes"])).toBe("New Folder");
        expect(Notes.freeName(["Notes", "new folder", "New Folder 2"])).toBe("New Folder 3");
    });
    test("a new note's file name, and which deleted ones are due", () => {
        expect(Notes.newId(at(2026, 11, 28, 3, 4), 0)).toBe("20261128-030400-000");
        expect(Notes.newId(at(2026, 1, 2, 13, 14), 0.5)).toMatch(/^20260102-131400-[0-9a-z]{3}$/);
        expect(Notes.expired(rows, now).map((r: { id: string }) => r.id)).toEqual(["d"]);
    });
    test("an entry of the list", () => {
        const e = Notes.entry("Work", "x", note([para("title", "Trip"), para("body", "Pack BAGS")], { pinned: true }));
        expect(e).toMatchObject({ folder: "Work", id: "x", title: "Trip", snippet: "Pack BAGS", pinned: true, plain: "trip\npack bags" });
    });
});
