// What Notes keeps and lists: a note as paragraphs, the file it is kept in
// (Markdown, a line a paragraph, under a few lines of dates), its name and
// the line under it in the list, the list's sections by date, the folders
// of the sidebar, and searching. The C++ Store only reads and writes files
// and the Editor only shows and edits paragraphs; this decides. Shared
// with bun (notes/notes.test.ts), so it keeps to what QML's JavaScript
// runs: no object spread, no `??=`.
//
// A paragraph is { kind, level, checked, quote, runs }: one of `kinds`; how
// far in a list item stands (0 to 8); a checklist item's mark; whether it
// is quoted; its text as runs of { text, bold, italic, underline, strike }.

export const kinds = ["title", "heading", "subheading", "body", "mono", "bullet", "dash", "number", "check"];
export const deepest = 8;

export function isList(kind) {
    return kind === "bullet" || kind === "dash" || kind === "number" || kind === "check";
}

export function paragraph(kind, text, more) {
    const made = { kind: kind || "body", level: 0, checked: false, quote: false, runs: [] };
    if (text)
        made.runs.push({ text: text, bold: false, italic: false, underline: false, strike: false });
    if (more) {
        for (const key of Object.keys(more))
            made[key] = more[key];
    }
    return made;
}

export function textOf(para) {
    let text = "";
    for (const run of para.runs || [])
        text += run.text;
    return text;
}

// ---------------------------------------------------------------------------
// The file.

const flags = ["bold", "italic", "underline", "strike"];
const marks = { bold: ["**", "**"], italic: ["*", "*"], underline: ["<u>", "</u>"], strike: ["~~", "~~"] };

function isSpace(c) {
    return c === " " || c === "\t" || c === "\u2028" || c === "\u00a0";
}
function isWord(c) {
    return c !== undefined && /[0-9A-Za-z\u00c0-\uffff]/.test(c);
}

// Text as Markdown reads it back unchanged: a backslash before whatever
// would be taken for a mark.
function escaped(text) {
    let out = "";
    for (let at = 0; at < text.length; ++at) {
        const c = text[at], before = text[at - 1], after = text[at + 1];
        if (c === "\\" || c === "*")
            out += "\\" + c;
        else if (c === "~" && (before === "~" || after === "~"))
            out += "\\~";
        else if (c === "<" && (text.startsWith("u>", at + 1) || text.startsWith("/u>", at + 1)))
            out += "\\<";
        else if (c === "_" && !isWord(before) && after !== undefined && !isSpace(after))
            out += "\\_";
        else
            out += c;
    }
    return out;
}

// Runs cut into pieces of text and of space, a stretch of space keeping
// only the marks of both its neighbors: a mark then opens before a letter
// and closes after one, as Markdown wants.
function pieces(runs) {
    const cut = [];
    for (const run of runs) {
        let from = 0;
        const text = run.text || "";
        while (from < text.length) {
            const space = isSpace(text[from]);
            let to = from + 1;
            while (to < text.length && isSpace(text[to]) === space)
                ++to;
            cut.push({ text: text.slice(from, to), space: space, bold: !!run.bold, italic: !!run.italic, underline: !!run.underline, strike: !!run.strike });
            from = to;
        }
    }
    for (let at = 0; at < cut.length; ++at) {
        if (!cut[at].space)
            continue;
        let before = at - 1, after = at + 1;
        while (before >= 0 && cut[before].space)
            --before;
        while (after < cut.length && cut[after].space)
            ++after;
        for (const flag of flags)
            cut[at][flag] = before >= 0 && after < cut.length && cut[before][flag] && cut[after][flag];
    }
    return cut;
}

function inlineOut(runs) {
    let out = "", open = [];
    for (const piece of pieces(runs)) {
        let keep = open.length;
        for (let at = 0; at < open.length; ++at) {
            if (!piece[open[at]]) {
                keep = at;
                break;
            }
        }
        for (let at = open.length - 1; at >= keep; --at)
            out += marks[open[at]][1];
        open = open.slice(0, keep);
        for (const flag of flags) {
            if (piece[flag] && !open.includes(flag)) {
                out += marks[flag][0];
                open.push(flag);
            }
        }
        out += escaped(piece.text);
    }
    for (let at = open.length - 1; at >= 0; --at)
        out += marks[open[at]][1];
    return out;
}

function inlineIn(source) {
    const runs = [];
    let state = { bold: false, italic: false, underline: false, strike: false };
    let under = false; // italic opened by an underscore
    let buffer = "";
    const flush = () => {
        if (buffer === "")
            return;
        const last = runs[runs.length - 1];
        if (last && flags.every(flag => last[flag] === state[flag]))
            last.text += buffer;
        else
            runs.push({ text: buffer, bold: state.bold, italic: state.italic, underline: state.underline, strike: state.strike });
        buffer = "";
    };
    // A mark opens only before something and closes only after something.
    const fits = (opens, closes, before, after) =>
        (!opens || (after !== undefined && !isSpace(after))) && (!closes || (before !== undefined && !isSpace(before)));
    let at = 0;
    while (at < source.length) {
        const c = source[at];
        if (c === "\\" && at + 1 < source.length && /[\\`*_{}\[\]()#+\-.!~<>|]/.test(source[at + 1])) {
            buffer += source[at + 1];
            at += 2;
            continue;
        }
        if (c === "*") {
            let n = 1;
            while (n < 3 && source[at + n] === "*")
                ++n;
            const bold = n >= 2, italic = n !== 2;
            const opens = (bold && !state.bold) || (italic && !state.italic);
            const closes = (bold && state.bold) || (italic && state.italic);
            if (fits(opens, closes, source[at - 1], source[at + n])) {
                flush();
                if (bold)
                    state.bold = !state.bold;
                if (italic) {
                    state.italic = !state.italic;
                    under = false;
                }
            } else {
                buffer += source.slice(at, at + n);
            }
            at += n;
            continue;
        }
        if (c === "~" && source[at + 1] === "~") {
            if (fits(!state.strike, state.strike, source[at - 1], source[at + 2])) {
                flush();
                state.strike = !state.strike;
            } else {
                buffer += "~~";
            }
            at += 2;
            continue;
        }
        if (c === "<" && source.startsWith("u>", at + 1)) {
            flush();
            state.underline = true;
            at += 3;
            continue;
        }
        if (c === "<" && source.startsWith("/u>", at + 1)) {
            flush();
            state.underline = false;
            at += 4;
            continue;
        }
        if (c === "_") {
            const before = source[at - 1], after = source[at + 1];
            if (!state.italic && !isWord(before) && before !== "_" && after !== undefined && !isSpace(after) && after !== "_") {
                flush();
                state.italic = true;
                under = true;
                ++at;
                continue;
            }
            if (state.italic && under && before !== undefined && !isSpace(before) && before !== "_" && !isWord(after) && after !== "_") {
                flush();
                state.italic = false;
                under = false;
                ++at;
                continue;
            }
        }
        buffer += c;
        ++at;
    }
    flush();
    return runs;
}

// Some of a paragraph's text is bold, italic, underlined or struck.
function marked(para) {
    return (para.runs || []).some(run => run.text !== "" && /[^ \t\u2028\u00a0]/.test(run.text) && flags.some(flag => run[flag]));
}

function iso(when) {
    return new Date(when).toISOString();
}

// A note as its file's text.
export function serialize(note) {
    const lines = ["---", "created: " + iso(note.created), "modified: " + iso(note.modified)];
    if (note.pinned)
        lines.push("pinned: true");
    if (note.deleted)
        lines.push("deleted: " + iso(note.deleted));
    if (note.from)
        lines.push("folder: " + note.from);
    for (const line of note.extra || [])
        lines.push(line);
    lines.push("---");

    const paragraphs = note.paragraphs || [];
    let numbers = [];
    for (let at = 0; at < paragraphs.length; ++at) {
        const para = paragraphs[at];
        const quote = para.quote ? "> " : "";
        if (para.kind === "mono" && marked(para)) {
            // Marks mean nothing between fences: a marked one is a line of
            // its own, in the tags Markdown still reads marks inside.
            lines.push(quote + "<code>" + inlineOut(para.runs) + "</code>");
            numbers = [];
            continue;
        }
        if (para.kind === "mono") {
            // A run of them between fences longer than any in it.
            let end = at, ticks = 3;
            while (end < paragraphs.length && paragraphs[end].kind === "mono" && !marked(paragraphs[end]) && !!paragraphs[end].quote === !!para.quote) {
                const found = /^`+/.exec(textOf(paragraphs[end]));
                if (found)
                    ticks = Math.max(ticks, found[0].length + 1);
                ++end;
            }
            const fence = quote + "`".repeat(ticks);
            lines.push(fence);
            for (; at < end; ++at)
                lines.push(quote + textOf(paragraphs[at]));
            lines.push(fence);
            --at;
            numbers = [];
            continue;
        }
        const level = isList(para.kind) ? Math.max(0, Math.min(deepest, para.level || 0)) : 0;
        let text = inlineOut(para.runs || []);
        let mark = "";
        if (para.kind === "number") {
            numbers = numbers.slice(0, level + 1);
            numbers[level] = (numbers[level] || 0) + 1;
            mark = numbers[level] + ". ";
        } else if (isList(para.kind)) {
            numbers = numbers.slice(0, level);
            mark = para.kind === "bullet" ? "* " : para.kind === "dash" ? "- " : para.checked ? "- [x] " : "- [ ] ";
            // A dash's own text that begins as a checklist's box does.
            if (para.kind !== "check" && /^\[[ xX]\]/.test(text))
                text = "\\" + text;
        } else {
            numbers = [];
            if (para.kind === "title")
                mark = "# ";
            else if (para.kind === "heading")
                mark = "## ";
            else if (para.kind === "subheading")
                mark = "### ";
            else
                text = text.replace(/^([\t ]*)([-+] |[-+]$|#{1,6} |> |>$|```)/, "$1\\$2").replace(/^([\t ]*\d+)([.)] |[.)]$)/, "$1\\$2").replace(/^<code>/, "\\<code>");
        }
        lines.push(quote + "\t".repeat(level) + mark + text);
    }
    return lines.join("\n") + "\n";
}

function levelOf(space) {
    let tabs = 0, spaces = 0;
    for (const c of space) {
        if (c === "\t")
            ++tabs;
        else
            ++spaces;
    }
    return Math.min(deepest, tabs + Math.ceil(spaces / 4));
}

function parseLine(line) {
    let quote = false, rest = line;
    if (rest === ">" || rest.startsWith("> ")) {
        quote = true;
        rest = rest.slice(rest === ">" ? 1 : 2);
    }
    const made = { kind: "body", level: 0, checked: false, quote: quote, runs: [] };
    const code = /^<code>(.*)<\/code>$/.exec(rest);
    if (code) {
        made.kind = "mono";
        made.runs = inlineIn(code[1]);
        return made;
    }
    const heading = /^(#{1,6}) (.*)$/.exec(rest);
    if (heading) {
        made.kind = ["title", "heading", "subheading"][Math.min(3, heading[1].length) - 1];
        made.runs = inlineIn(heading[2]);
        return made;
    }
    const item = /^([\t ]*)(?:([-*+])|\d+[.)])(?: (.*))?$/.exec(rest);
    if (item) {
        let text = item[3] || "";
        made.level = levelOf(item[1]);
        if (item[2] === undefined) {
            made.kind = "number";
        } else {
            const box = /^\[([ xX])\](?: (.*))?$/.exec(text);
            if (box) {
                made.kind = "check";
                made.checked = box[1] !== " ";
                text = box[2] || "";
            } else {
                made.kind = item[2] === "-" ? "dash" : "bullet";
            }
        }
        made.runs = inlineIn(text);
        return made;
    }
    made.runs = inlineIn(rest);
    return made;
}

// A file's text as a note; `stamp` (when the file was last changed) stands
// in for dates the file doesn't give.
export function parse(text, stamp) {
    const note = { created: stamp || 0, modified: stamp || 0, pinned: false, deleted: 0, from: "", extra: [], paragraphs: [] };
    const lines = String(text === undefined || text === null ? "" : text).replace(/\r\n?/g, "\n").split("\n");
    if (lines.length > 0 && lines[lines.length - 1] === "")
        lines.pop();
    let at = 0;
    if (lines[0] === "---") {
        let end = 1;
        while (end < lines.length && lines[end] !== "---")
            ++end;
        if (end < lines.length) {
            for (let k = 1; k < end; ++k) {
                const pair = /^([A-Za-z]+):\s*(.*)$/.exec(lines[k]);
                const key = pair ? pair[1] : "", value = pair ? pair[2].trim() : "";
                if (key === "created" || key === "modified" || key === "deleted") {
                    const when = Date.parse(value);
                    if (!isNaN(when))
                        note[key] = when;
                } else if (key === "pinned") {
                    note.pinned = value === "true";
                } else if (key === "folder") {
                    note.from = value;
                } else {
                    note.extra.push(lines[k]);
                }
            }
            at = end + 1;
        }
    }
    for (; at < lines.length; ++at) {
        const line = lines[at];
        const quoted = line === ">" || line.startsWith("> ");
        const bare = quoted ? line.slice(line === ">" ? 1 : 2) : line;
        const fence = /^(`{3,})[^`]*$/.exec(bare);
        if (fence) {
            let end = at + 1;
            const closes = (candidate) => {
                const inner = quoted && (candidate === ">" || candidate.startsWith("> ")) ? candidate.slice(candidate === ">" ? 1 : 2) : candidate;
                return inner.startsWith(fence[1]) && /^`+\s*$/.test(inner);
            };
            while (end < lines.length && !closes(lines[end]))
                ++end;
            for (let k = at + 1; k < end; ++k) {
                const inner = quoted && (lines[k] === ">" || lines[k].startsWith("> ")) ? lines[k].slice(lines[k] === ">" ? 1 : 2) : lines[k];
                note.paragraphs.push(paragraph("mono", inner, { quote: quoted }));
            }
            at = end;
            continue;
        }
        note.paragraphs.push(parseLine(line));
    }
    if (note.paragraphs.length === 0)
        note.paragraphs.push(paragraph("body", ""));
    return note;
}

// ---------------------------------------------------------------------------
// What a note is called and what the list says under its name.

function shown(text) {
    return text.replace(/[\t\u2028\u00a0]+/g, " ").replace(/ {2,}/g, " ").trim();
}

function saidLines(note) {
    const said = [];
    for (const para of note.paragraphs || []) {
        const text = shown(textOf(para));
        if (text !== "")
            said.push(text);
        if (said.length === 2)
            break;
    }
    return said;
}

export function titleOf(note) {
    const said = saidLines(note);
    return said.length > 0 ? said[0] : "New Note";
}

export function snippetOf(note) {
    const said = saidLines(note);
    return said.length > 1 ? said[1] : "No additional text";
}

export function plainOf(note) {
    return (note.paragraphs || []).map(textOf).join("\n");
}

export function isEmpty(note) {
    return (note.paragraphs || []).every(para => textOf(para).trim() === "");
}

// What a note is known by everywhere but in the editor: a row of the list.
export function entry(folder, id, note) {
    return {
        folder: folder, id: id, created: note.created, modified: note.modified, pinned: !!note.pinned, deleted: note.deleted || 0, from: note.from || "",
        title: titleOf(note), snippet: snippetOf(note), plain: plainOf(note).toLowerCase(),
    };
}

// ---------------------------------------------------------------------------
// Dates, as a Mac's Notes writes them.

const months = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"];
const weekdays = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"];

function dayStart(when) {
    const d = new Date(when);
    return new Date(d.getFullYear(), d.getMonth(), d.getDate()).getTime();
}

// Whole days from one date's day to another's (yesterday to today is 1),
// whatever the clocks did between.
function daysBetween(then, now) {
    return Math.round((dayStart(now) - dayStart(then)) / 86400000);
}

export function clock(when, hour24) {
    const d = new Date(when);
    const minutes = String(d.getMinutes()).padStart(2, "0");
    if (hour24)
        return String(d.getHours()).padStart(2, "0") + ":" + minutes;
    const hour = d.getHours() % 12;
    return (hour === 0 ? 12 : hour) + ":" + minutes + (d.getHours() < 12 ? " AM" : " PM");
}

// A row's date: the time today, Yesterday, the weekday within the week,
// then the date in figures.
export function rowDate(when, now, hour24) {
    const days = daysBetween(when, now);
    if (days <= 0)
        return clock(when, hour24);
    if (days === 1)
        return "Yesterday";
    const d = new Date(when);
    if (days < 7)
        return weekdays[d.getDay()];
    return (d.getMonth() + 1) + "/" + d.getDate() + "/" + String(d.getFullYear() % 100).padStart(2, "0");
}

// Over a note: November 28, 2026 at 3:40 AM.
export function longDate(when, hour24) {
    const d = new Date(when);
    return months[d.getMonth()] + " " + d.getDate() + ", " + d.getFullYear() + " at " + clock(when, hour24);
}

// ---------------------------------------------------------------------------
// The list.

function dateOf(row, by) {
    return by === "created" ? row.created : row.modified;
}

export function sorted(rows, by) {
    const copy = rows.slice();
    if (by === "title")
        copy.sort((a, b) => a.title.toLowerCase() < b.title.toLowerCase() ? -1 : a.title.toLowerCase() > b.title.toLowerCase() ? 1 : b.modified - a.modified);
    else
        copy.sort((a, b) => dateOf(b, by) - dateOf(a, by) || (a.id < b.id ? -1 : 1));
    return copy;
}

// The rows under their headings: Pinned first; then by date (Today,
// Yesterday, Previous 7 Days, Previous 30 Days, this year's months, the
// years before) when sorted by a date and `grouped`; else the rest under
// one heading, shown only when there are pinned ones over it.
export function sections(rows, now, by, grouped, pinnedApart) {
    const made = [];
    const pinned = pinnedApart === false ? [] : rows.filter(row => row.pinned);
    const rest = pinnedApart === false ? rows : rows.filter(row => !row.pinned);
    if (pinned.length > 0)
        made.push({ key: "pinned", title: "Pinned", rows: sorted(pinned, by) });
    const ordered = sorted(rest, by);
    if (by === "title" || !grouped) {
        if (ordered.length > 0)
            made.push({ key: "notes", title: pinned.length > 0 ? "Notes" : "", rows: ordered });
        return made;
    }
    const year = new Date(now).getFullYear();
    for (const row of ordered) {
        const when = dateOf(row, by), days = daysBetween(when, now), d = new Date(when);
        const title = days <= 0 ? "Today" : days === 1 ? "Yesterday" : days <= 7 ? "Previous 7 Days" : days <= 30 ? "Previous 30 Days"
                    : d.getFullYear() === year ? months[d.getMonth()] : String(d.getFullYear());
        const last = made[made.length - 1];
        if (last && last.key === "date:" + title)
            last.rows.push(row);
        else
            made.push({ key: "date:" + title, title: title, rows: [row] });
    }
    return made;
}

// Every word of what was typed is somewhere in the note.
export function found(rows, query) {
    const words = String(query).toLowerCase().split(/\s+/).filter(word => word !== "");
    if (words.length === 0)
        return rows;
    return rows.filter(row => words.every(word => row.plain.includes(word)));
}

export function countText(count) {
    return count === 0 ? "No Notes" : count === 1 ? "1 note" : count + " notes";
}

// ---------------------------------------------------------------------------
// Folders. A folder is a directory; "Notes" is always there; what was
// deleted waits thirty days in one of its own.

export const home = "Notes";
export const deleted = ".deleted";
export const everything = "*";
export const keptDays = 30;

// The sidebar's rows: all of them when there is more than one folder,
// Notes, the others by name, and Recently Deleted while it holds any.
export function sidebar(names, rows) {
    const count = (name) => rows.filter(row => row.folder === name).length;
    const others = names.filter(name => name !== home && name !== deleted && !name.startsWith("."));
    others.sort((a, b) => a.toLowerCase() < b.toLowerCase() ? -1 : a.toLowerCase() > b.toLowerCase() ? 1 : 0);
    const made = [];
    if (others.length > 0)
        made.push({ key: everything, name: "All On My Computer", glyph: "folder", count: rows.filter(row => row.folder !== deleted).length, fixed: true });
    made.push({ key: home, name: home, glyph: "folder", count: count(home), fixed: true });
    for (const name of others)
        made.push({ key: name, name: name, glyph: "folder", count: count(name), fixed: false });
    const gone = count(deleted);
    if (gone > 0)
        made.push({ key: deleted, name: "Recently Deleted", glyph: "trash", count: gone, fixed: true });
    return made;
}

export function inFolder(rows, key) {
    return key === everything ? rows.filter(row => row.folder !== deleted) : rows.filter(row => row.folder === key);
}

// Why a folder can't be called this, or nothing when it can.
export function nameFault(name, names) {
    const wanted = String(name).trim();
    if (wanted === "")
        return "A folder needs a name.";
    if (wanted.includes("/") || wanted.startsWith(".") || wanted.length > 100)
        return "That name can’t be used.";
    if (wanted === "Recently Deleted" || wanted === "All On My Computer")
        return "That name is taken.";
    const lower = wanted.toLowerCase();
    if (names.some(other => other.toLowerCase() === lower))
        return "That name is taken.";
    return "";
}

export function freeName(names) {
    const lower = names.map(name => name.toLowerCase());
    if (!lower.includes("new folder"))
        return "New Folder";
    for (let n = 2; ; ++n) {
        if (!lower.includes("new folder " + n))
            return "New Folder " + n;
    }
}

// A new note's name on disk: when it was made, and a few letters more.
export function newId(now, salt) {
    const d = new Date(now), two = (n) => String(n).padStart(2, "0");
    return "" + d.getFullYear() + two(d.getMonth() + 1) + two(d.getDate()) + "-" + two(d.getHours()) + two(d.getMinutes()) + two(d.getSeconds())
        + "-" + Math.floor((salt === undefined ? Math.random() : salt) * 46656).toString(36).padStart(3, "0");
}

// Which of the deleted have waited their thirty days.
export function expired(rows, now) {
    return rows.filter(row => row.folder === deleted && now - (row.deleted || row.modified) > keptDays * 86400000);
}
