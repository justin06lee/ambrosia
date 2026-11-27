// Rich Text Format, read and written: Qt has neither. TextEdit's documents
// are RTF, so this is what lets one made on a Mac open here and one made
// here open there. (Kept to the JavaScript QML's engine runs: no object
// spread, no ??=.) Written to match what Cocoa writes: the samples it is
// tested on (textedit/samples) are Cocoa's own, from textutil.
//
// Both ways go through a plain model, which the app's C++ side turns into
// a QTextDocument and back (src/editor.cpp):
//
//   { view: { width, height } | null,          the text area, in points
//     paragraphs: [ {
//       align: "left" | "center" | "right" | "justify",
//       left, first, right, before, after,     points; `first` from `left`
//       spacing,                               line height, 1 being single
//       tabs: [points…],
//       list: null | { marker, level, id },    level from 0; marker as markers
//       runs: [ { text, family, size, bold, italic, underline, strike,
//                 color, background,            "#rrggbb" or "" for none
//                 script } ]                    "", "super" or "sub"
//     } ] }
//
// A paragraph always has a run, an empty one when it has no text: it says
// what will be typed there. What RTF holds that the model doesn't
// (pictures, tables, links, styles, headers) is left out on reading; a
// table's cells come through as text with tabs between them.

export const markers = ["disc", "circle", "square", "decimal", "lower-alpha", "upper-alpha", "lower-roman", "upper-roman"];

// Bytes 0x80 to 0x9f of Windows-1252; the rest are Latin-1.
const cp1252 = [0x20ac, 0x81, 0x201a, 0x192, 0x201e, 0x2026, 0x2020, 0x2021, 0x2c6, 0x2030, 0x160, 0x2039, 0x152, 0x8d, 0x17d, 0x8f,
                0x90, 0x2018, 0x2019, 0x201c, 0x201d, 0x2022, 0x2013, 0x2014, 0x2dc, 0x2122, 0x161, 0x203a, 0x153, 0x9d, 0x17e, 0x178];
// Bytes 0x80 to 0xff of Mac OS Roman.
const macRoman = "ÄÅÇÉÑÖÜáàâäãåçéèêëíìîïñóòôöõúùûü†°¢£§•¶ß®©™´¨≠ÆØ∞±≤≥¥µ∂∑∏π∫ªºΩæø¿¡¬√ƒ≈∆«»…\u00a0ÀÃÕŒœ–—“”‘’÷◊ÿŸ⁄€‹›ﬁﬂ‡·‚„‰ÂÊÁËÈÍÎÏÌÓÔ\uf8ffÒÚÛÙıˆ˜¯˘˙˚¸˝˛ˇ";
// A font's \fcharset as the code page its \'hh bytes are in; the others
// (0, ANSI, among them) are in the document's own.
const charsets = { 77: 10000, 128: 932, 129: 949, 130: 1361, 134: 936, 136: 950, 161: 1253, 162: 1254, 163: 1258,
                   177: 1255, 178: 1256, 186: 1257, 204: 1251, 222: 874, 238: 1250 };

// Groups whose contents are not the document's text.
const skipped = new Set(["stylesheet", "info", "pict", "object", "header", "headerl", "headerr", "headerf", "footer", "footerl", "footerr",
    "footerf", "footnote", "annotation", "fldinst", "datafield", "themedata", "colorschememapping", "latentstyles", "datastore",
    "generator", "xmlnstbl", "listtext", "pntext", "NeXTGraphic", "nonshppict", "filetbl", "revtbl", "rsidtbl", "mmathPr",
    "bkmkstart", "bkmkend", "template", "operator", "author", "title", "subject", "keywords", "comment", "doccomm", "company",
    "listpicture", "pgdsctbl", "pntxta", "pntxtb", "atnid", "atnauthor", "ftnsep", "ftnsepc", "aftnsep", "aftnsepc", "wgrffmtfilter"]);

const symbols = { tab: "\t", line: "\u2028", emdash: "—", endash: "–", emspace: "\u2003", enspace: "\u2002", qmspace: "\u2005",
                  bullet: "•", lquote: "‘", rquote: "’", ldblquote: "“", rdblquote: "”", cell: "\t", nestcell: "\t" };

const alignments = { ql: "left", qc: "center", qr: "right", qj: "justify", qd: "justify" };

// A list level's number format (\levelnfc) as a marker.
const numberFormats = { 0: "decimal", 1: "upper-roman", 2: "lower-roman", 3: "upper-alpha", 4: "lower-alpha", 23: "disc" };

function hex(r, g, b) {
    return "#" + [r, g, b].map(v => Math.max(0, Math.min(255, v | 0)).toString(16).padStart(2, "0")).join("");
}

/** A font's name in an RTF file as a family and what the name says of its
 *  style: Cocoa writes PostScript names ("Helvetica-BoldOblique",
 *  "TimesNewRomanPSMT"), Word the family's own. */
export function fontFromName(name) {
    let family = name.trim(), bold = false, italic = false;
    const dash = family.lastIndexOf("-");
    if (dash > 0 && !family.includes(" ")) {
        const style = family.slice(dash + 1);
        if (/^((Ultra|Extra|Semi|Demi)?(Regular|Roman|Book|Medium|Light|Thin|Bold|Heavy|Black)?(Italic|Oblique|It|Obl)?(MT)?|W\d)$/i.test(style)) {
            family = family.slice(0, dash);
            bold = /bold|heavy|black/i.test(style);
            italic = /italic|oblique|it$|obl$|itmt$/i.test(style);
        }
    }
    if (!family.includes(" ")) {
        family = family.replace(/(PSMT|PS|MT)$/, "") || family;
        // HelveticaNeue is Helvetica Neue, TrebuchetMS is Trebuchet MS.
        family = family.replace(/([a-z])([A-Z])/g, "$1 $2");
    }
    return { family, bold, italic };
}

/** Reads RTF. `source` holds the file a byte to a character; `decode(page,
 *  bytes)` turns bytes of a code page this doesn't know itself (the East
 *  Asian ones Cocoa writes) into text, and may be left out. */
export function parse(source, decode) {
    const fonts = {};
    const colors = [];
    const lists = [];
    const overrides = {};
    const paragraphs = [];
    let view = null, viewWidth = 0, viewHeight = 0;
    let codepage = 1252;
    let defaultFont = null;

    const freshChar = () => ({ f: null, fs: 24, milli: 0, b: false, i: false, ul: false, strike: false, cf: 0, cb: 0, script: "" });
    const freshPara = () => ({ align: "left", li: 0, fi: 0, ri: 0, sb: 0, sa: 0, sl: 0, slmult: 0, tabs: [], ls: 0, ilvl: 0 });
    let state = { dest: "", char: freshChar(), para: freshPara(), uc: 1 };
    const stack = [];
    let runs = [];
    let bytes = [], bytesPage = 0;
    let skip = 0;
    // The tables as they are read.
    let font = { index: 0, name: "", charset: 0 };
    let color = { r: 0, g: 0, b: 0, any: false };
    let expanded = { index: 0, any: false };
    let list = null, level = null, overrideList = 0;
    let starred = false, first = true;

    function page() {
        if (state.dest !== "")
            return codepage;
        const f = fonts[state.char.f ?? defaultFont];
        return f && charsets[f.charset] !== undefined ? charsets[f.charset] : codepage;
    }
    function decoded(list, from) {
        if (from === 1252)
            return list.map(b => String.fromCharCode(b >= 0x80 && b <= 0x9f ? cp1252[b - 0x80] : b)).join("");
        if (from === 10000)
            return list.map(b => b >= 0x80 ? macRoman[b - 0x80] : String.fromCharCode(b)).join("");
        const text = decode ? decode(from, list) : null;
        return text ?? list.map(b => String.fromCharCode(b)).join("");
    }
    function flush() {
        if (bytes.length === 0)
            return;
        const text = decoded(bytes, bytesPage);
        bytes = [];
        emit(text);
    }
    function byte(value) {
        const from = page();
        if (bytes.length > 0 && from !== bytesPage)
            flush();
        bytesPage = from;
        bytes.push(value);
    }
    function format() {
        const c = state.char;
        const named = fontFromName(fonts[c.f ?? defaultFont]?.name ?? "");
        return {
            family: named.family, size: c.milli > 0 ? c.milli / 1000 : c.fs / 2,
            bold: c.b || named.bold, italic: c.i || named.italic, underline: c.ul, strike: c.strike,
            color: colors[c.cf] ?? "", background: colors[c.cb] ?? "", script: c.script,
        };
    }
    function same(a, b) {
        return a.family === b.family && a.size === b.size && a.bold === b.bold && a.italic === b.italic && a.underline === b.underline
            && a.strike === b.strike && a.color === b.color && a.background === b.background && a.script === b.script;
    }
    function emit(text) {
        switch (state.dest) {
        case "": {
            const now = format();
            const last = runs[runs.length - 1];
            if (last && same(last, now))
                last.text += text;
            else
                runs.push(Object.assign({ text: text }, now));
            break;
        }
        case "fonttbl":
            for (const ch of text) {
                if (ch === ";") {
                    fonts[font.index] = { name: font.name.trim(), charset: font.charset };
                    if (defaultFont === null)
                        defaultFont = font.index;
                    font = { index: font.index, name: "", charset: 0 };
                } else {
                    font.name += ch;
                }
            }
            break;
        case "colortbl":
            for (const ch of text) {
                if (ch === ";") {
                    colors.push(color.any ? hex(color.r, color.g, color.b) : "");
                    color = { r: 0, g: 0, b: 0, any: false };
                }
            }
            break;
        case "expandedcolortbl":
            // Cocoa's own table beside the plain one: an entry left empty
            // there is no color at all (its \cb1 after a highlight).
            for (const ch of text) {
                if (ch === ";") {
                    if (!expanded.any && expanded.index < colors.length)
                        colors[expanded.index] = "";
                    expanded = { index: expanded.index + 1, any: false };
                }
            }
            break;
        case "levelmarker":
            if (level)
                level.marker += text;
            break;
        }
    }
    function markerOf(level) {
        const named = /\{([a-z-]+)\}/.exec(level?.marker ?? "")?.[1];
        if (markers.includes(named))
            return named;
        // What Qt has no mark for comes as the nearest it has.
        if (named === "box" || named === "diamond")
            return "square";
        if (named)
            return /decimal|octal|hex/.test(named) ? "decimal" : /alpha/.test(named) ? "lower-alpha" : /roman/.test(named) ? "lower-roman" : "disc";
        return numberFormats[level?.nfc] ?? "disc";
    }
    function endParagraph() {
        flush();
        const p = state.para;
        if (runs.length === 0)
            runs.push(Object.assign({ text: "" }, format()));
        const made = {
            align: p.align, left: p.li / 20, first: p.fi / 20, right: p.ri / 20, before: p.sb / 20, after: p.sa / 20,
            spacing: p.slmult === 1 && p.sl !== 0 ? Math.round(Math.abs(p.sl) / 240 * 100) / 100 : 1,
            tabs: p.tabs.map(t => t / 20), list: null, runs,
        };
        if (p.ls > 0) {
            const id = overrides[p.ls] ?? p.ls;
            const of = lists.find(l => l.id === id);
            made.list = { marker: markerOf(of?.levels[p.ilvl] ?? of?.levels[0]), level: p.ilvl, id: p.ls };
            // The list sets these; ours does too.
            made.left = 0;
            made.first = 0;
            made.tabs = [];
        }
        paragraphs.push(made);
        runs = [];
    }
    function word(name, value, given) {
        const dest = state.dest;
        if (first) {
            // The first word after a brace says what the group is.
            first = false;
            const star = starred;
            starred = false;
            if (name === "fonttbl" || name === "colortbl" || name === "expandedcolortbl" || name === "listtable"
                || name === "listoverridetable" || name === "levelmarker") {
                state.dest = name;
                return;
            }
            if (skipped.has(name) || (star && !(dest === "listtable" || dest === "listoverridetable"))) {
                state.dest = "skip";
                return;
            }
        }
        if (dest === "skip")
            return;
        if (dest === "fonttbl") {
            if (name === "f")
                font.index = value;
            else if (name === "fcharset")
                font.charset = value;
            return;
        }
        if (dest === "colortbl") {
            if (name === "red" || name === "green" || name === "blue") {
                color[name[0]] = value;
                color.any = true;
            }
            return;
        }
        if (dest === "expandedcolortbl") {
            expanded.any = true;
            return;
        }
        if (dest === "listtable" || dest === "levelmarker") {
            if (name === "list") {
                list = { id: 0, levels: [] };
                lists.push(list);
            } else if (name === "listlevel" && list) {
                level = { nfc: 0, marker: "" };
                list.levels.push(level);
            } else if (name === "levelnfc" && level) {
                level.nfc = value;
            } else if (name === "listid" && list) {
                list.id = value;
            }
            return;
        }
        if (dest === "listoverridetable") {
            if (name === "listid")
                overrideList = value;
            else if (name === "ls")
                overrides[value] = overrideList;
            return;
        }

        const c = state.char, p = state.para;
        const on = !given || value !== 0;
        switch (name) {
        case "par": case "sect": case "page": case "row": case "nestrow": endParagraph(); break;
        case "pard": state.para = freshPara(); break;
        case "plain": state.char = Object.assign(freshChar(), { f: c.f }); break;
        case "ansicpg": codepage = value; break;
        case "mac": codepage = 10000; break;
        case "pc": codepage = 437; break;
        case "pca": codepage = 850; break;
        case "deff": defaultFont = value; break;
        case "uc": state.uc = value; break;
        case "u":
            emit(String.fromCharCode(value < 0 ? value + 65536 : value));
            skip = state.uc;
            break;
        case "f": c.f = value; break;
        case "fs": c.fs = value; c.milli = 0; break;
        case "fsmilli": c.milli = value; break;
        case "b": c.b = on; break;
        case "i": c.i = on; break;
        case "ul": case "uld": case "uldb": case "ulw": case "ulth": case "uldash": case "ulwave": c.ul = on; break;
        case "ulnone": c.ul = false; break;
        case "strike": case "striked": c.strike = on; break;
        case "cf": c.cf = value; break;
        case "cb": case "highlight": case "chcbpat": c.cb = value; break;
        case "super": case "up": c.script = given && value === 0 ? "" : "super"; break;
        case "sub": case "dn": c.script = given && value === 0 ? "" : "sub"; break;
        case "nosupersub": c.script = ""; break;
        case "ql": case "qc": case "qr": case "qj": case "qd": p.align = alignments[name]; break;
        case "li": p.li = value; break;
        case "fi": p.fi = value; break;
        case "ri": p.ri = value; break;
        case "sb": p.sb = value; break;
        case "sa": p.sa = value; break;
        case "sl": p.sl = value; break;
        case "slmult": p.slmult = value; break;
        case "tx": p.tabs = p.tabs.concat([value]); break;
        case "ls": p.ls = value; break;
        case "ilvl": p.ilvl = value; break;
        case "vieww": viewWidth = value; break;
        case "viewh": viewHeight = value; break;
        default:
            if (symbols[name] !== undefined) {
                flush();
                emit(symbols[name]);
            }
        }
    }

    // What is left when the text ends is the last paragraph; an empty one
    // after a list is the end of the text, not one more item.
    let finished = false;
    function finish() {
        if (finished)
            return;
        finished = true;
        flush();
        const ended = runs.length === 0;
        endParagraph();
        if (ended && paragraphs.length > 1)
            paragraphs[paragraphs.length - 1].list = null;
    }

    const n = source.length;
    let i = 0;
    while (i < n && !finished) {
        const ch = source[i];
        if (ch === "{") {
            flush();
            skip = 0;
            stack.push(state);
            state = { dest: state.dest, char: Object.assign({}, state.char), para: Object.assign({}, state.para), uc: state.uc };
            first = true;
            starred = false;
            ++i;
        } else if (ch === "}") {
            flush();
            skip = 0;
            first = false;
            // The outermost brace ends the document, while its last
            // paragraph's font and settings still hold.
            if (stack.length <= 1)
                finish();
            state = stack.pop() ?? { dest: "", char: freshChar(), para: freshPara(), uc: 1 };
            ++i;
        } else if (ch === "\\") {
            const next = source[i + 1] ?? "";
            if (/[a-zA-Z]/.test(next)) {
                let j = i + 1;
                while (j < n && /[a-zA-Z]/.test(source[j]))
                    ++j;
                const name = source.slice(i + 1, j);
                let k = j;
                if (source[k] === "-")
                    ++k;
                while (k < n && source[k] >= "0" && source[k] <= "9")
                    ++k;
                const given = k > j && !(k === j + 1 && source[j] === "-");
                const value = given ? parseInt(source.slice(j, k), 10) : 0;
                i = given ? k : j;
                if (source[i] === " ")
                    ++i;
                flush();
                skip = 0;
                word(name, value, given);
            } else if (next === "'") {
                const value = parseInt(source.slice(i + 2, i + 4), 16);
                i += 4;
                first = false;
                if (skip > 0)
                    --skip;
                else if (!Number.isNaN(value) && state.dest !== "skip")
                    byte(value);
            } else {
                i += 2;
                if (next === "*") {
                    starred = true;
                    continue;
                }
                first = false;
                flush();
                if (next === "\n" || next === "\r") {
                    if (state.dest === "")
                        endParagraph();
                } else if (state.dest !== "skip") {
                    emit(next === "~" ? "\u00a0" : next === "_" ? "\u2011" : next === "-" ? "\u00ad" : "\\{}".includes(next) ? next : "");
                }
            }
        } else if (ch === "\n" || ch === "\r") {
            ++i;
        } else {
            ++i;
            first = false;
            if (skip > 0) {
                --skip;
                continue;
            }
            if (state.dest === "skip")
                continue;
            const code = ch.charCodeAt(0);
            if (code >= 0x80 && code <= 0xff) {
                byte(code);
            } else {
                flush();
                emit(ch);
            }
        }
    }
    finish();
    if (viewWidth > 0 && viewHeight > 0)
        view = { width: viewWidth / 20, height: viewHeight / 20 };
    return { view, paragraphs };
}

function twips(points) {
    return Math.round(points * 20);
}

function escaped(text) {
    let out = "";
    for (let i = 0; i < text.length; ++i) {
        const ch = text[i], code = text.charCodeAt(i);
        if (ch === "\\" || ch === "{" || ch === "}")
            out += "\\" + ch;
        else if (ch === "\t")
            out += "\\tab ";
        else if (ch === "\u2028" || ch === "\n")
            out += "\\line ";
        else if (code < 0x20)
            out += "";
        else if (code < 0x80)
            out += ch;
        else
            // The code unit as RTF's signed sixteen bits, and a `?` for
            // readers that know no Unicode.
            out += "\\u" + (code > 32767 ? code - 65536 : code) + "?";
    }
    return out;
}

function fontClass(family) {
    if (/mono|courier|menlo|consol|code|typewriter|terminal/i.test(family))
        return "fmodern";
    if (/times|serif|georgia|garamond|palatino|baskerville|roman|book|charter/i.test(family) && !/sans/i.test(family))
        return "froman";
    return /helvetica|arial|sans|inter|verdana|tahoma|grotesk|gothic|system/i.test(family) ? "fswiss" : "fnil";
}

/** A list item's number as its marker writes it: 3 is "3.", "c.", "iii.". */
export function ordinal(marker, n) {
    const letters = (n) => {
        let out = "";
        for (; n > 0; n = Math.floor((n - 1) / 26))
            out = String.fromCharCode(97 + (n - 1) % 26) + out;
        return out;
    };
    const roman = (n) => {
        let out = "";
        for (const [value, mark] of [[1000, "m"], [900, "cm"], [500, "d"], [400, "cd"], [100, "c"], [90, "xc"], [50, "l"], [40, "xl"], [10, "x"], [9, "ix"], [5, "v"], [4, "iv"], [1, "i"]])
            for (; n >= value; n -= value)
                out += mark;
        return out;
    };
    switch (marker) {
    case "decimal": return n + ".";
    case "lower-alpha": return letters(n) + ".";
    case "upper-alpha": return letters(n).toUpperCase() + ".";
    case "lower-roman": return roman(n) + ".";
    case "upper-roman": return roman(n).toUpperCase() + ".";
    case "circle": return "◦";
    case "square": return "▪";
    default: return "•";
    }
}

const numbered = (marker) => !["disc", "circle", "square"].includes(marker);

/** Writes the model as RTF, in Cocoa's dialect. */
export function write(model) {
    const fonts = [];
    const fontIndex = (family) => {
        let at = fonts.indexOf(family);
        if (at < 0)
            at = fonts.push(family) - 1;
        return at;
    };
    // The first color is Cocoa's placeholder for none.
    const colors = [];
    const colorIndex = (color) => {
        if (!color)
            return null;
        let at = colors.indexOf(color.toLowerCase());
        if (at < 0)
            at = colors.push(color.toLowerCase()) - 1;
        return at + 2;
    };
    // The lists, numbered as they first come, and each level's marker.
    const lists = [];
    const listIndex = (id) => {
        let at = lists.findIndex(l => l.id === id);
        if (at < 0)
            at = lists.push({ id, levels: [] }) - 1;
        return at;
    };
    for (const paragraph of model.paragraphs) {
        if (!paragraph.list)
            continue;
        const levels = lists[listIndex(paragraph.list.id)].levels;
        for (let l = 0; l <= paragraph.list.level; ++l)
            levels[l] = l === paragraph.list.level ? paragraph.list.marker : levels[l] ?? paragraph.list.marker;
    }

    let body = "";
    let para = "";
    let char = null;
    const counters = {};
    model.paragraphs.forEach((paragraph, index) => {
        let settings = "\\pard";
        let item = "";
        if (paragraph.list) {
            const at = listIndex(paragraph.list.id), depth = paragraph.list.level;
            const inset = 720 * (depth + 1);
            settings += `\\tx${inset - 500}\\tx${inset}\\pardeftab720\\li${inset}\\fi-${inset}`;
            const counts = counters[at] ?? (counters[at] = []);
            counts[depth] = (counts[depth] ?? 0) + 1;
            counts.length = depth + 1;
            item = `\\ls${at + 1}\\ilvl${depth}`;
            item += ` {\\listtext\\tab ${escaped(ordinal(paragraph.list.marker, counts[depth]))}\\tab }`;
        } else {
            for (const tab of paragraph.tabs ?? [])
                settings += "\\tx" + twips(tab);
            if (paragraph.left)
                settings += "\\li" + twips(paragraph.left);
            if (paragraph.first)
                settings += "\\fi" + twips(paragraph.first);
        }
        if (paragraph.right)
            settings += "\\ri" + twips(paragraph.right);
        if (paragraph.before)
            settings += "\\sb" + twips(paragraph.before);
        if (paragraph.after)
            settings += "\\sa" + twips(paragraph.after);
        if (paragraph.spacing && paragraph.spacing !== 1)
            settings += `\\sl${Math.round(paragraph.spacing * 240)}\\slmult1`;
        settings += { center: "\\qc", right: "\\qr", justify: "\\qj" }[paragraph.align] ?? "\\pardirnatural";
        settings += "\\partightenfactor0";
        if (settings !== para) {
            body += settings + "\n";
            para = settings;
        }
        body += item;
        for (const run of paragraph.runs) {
            let words = "";
            const f = fontIndex(run.family || "Helvetica");
            const half = Math.round(run.size * 2), exact = Math.abs(run.size * 2 - half) > 0.001;
            const cf = colorIndex(run.color) ?? 0, cb = colorIndex(run.background) ?? (char && char.cb > 0 ? 1 : 0);
            if (!char || char.f !== f)
                words += "\\f" + f;
            if (!char || char.size !== run.size)
                words += "\\fs" + half + (exact ? "\\fsmilli" + Math.round(run.size * 1000) : "");
            if ((char?.bold ?? false) !== !!run.bold)
                words += run.bold ? "\\b" : "\\b0";
            if ((char?.italic ?? false) !== !!run.italic)
                words += run.italic ? "\\i" : "\\i0";
            if ((char?.underline ?? false) !== !!run.underline)
                words += run.underline ? "\\ul" : "\\ulnone";
            if ((char?.strike ?? false) !== !!run.strike)
                words += run.strike ? "\\strike" : "\\strike0\\striked0";
            if ((char?.script ?? "") !== (run.script ?? ""))
                words += run.script === "super" ? "\\super" : run.script === "sub" ? "\\sub" : "\\nosupersub";
            if (!char || char.cf !== cf)
                words += "\\cf" + cf;
            if ((char?.cb ?? 0) !== cb)
                words += "\\cb" + cb;
            char = { f, size: run.size, bold: !!run.bold, italic: !!run.italic, underline: !!run.underline, strike: !!run.strike,
                     script: run.script ?? "", cf, cb };
            if (words !== "")
                body += words + " ";
            body += escaped(run.text);
        }
        if (index < model.paragraphs.length - 1)
            body += "\\\n";
    });

    const part = (color, at) => parseInt(color.slice(1 + 2 * at, 3 + 2 * at), 16);
    let out = "{\\rtf1\\ansi\\ansicpg1252\\cocoartf2822\n\\cocoatextscaling0\\cocoaplatform0";
    out += "{\\fonttbl" + (fonts.length ? fonts : ["Helvetica"]).map((family, i) => `\\f${i}\\${fontClass(family)}\\fcharset0 ${escaped(family)};`).join("") + "}\n";
    out += "{\\colortbl;\\red255\\green255\\blue255;" + colors.map(c => `\\red${part(c, 0)}\\green${part(c, 1)}\\blue${part(c, 2)};`).join("") + "}\n";
    out += "{\\*\\expandedcolortbl;;" + colors.map(c => "\\cssrgb" + [0, 1, 2].map(at => "\\c" + Math.round(part(c, at) / 255 * 100000)).join("") + ";").join("") + "}\n";
    if (lists.length > 0) {
        out += "{\\*\\listtable" + lists.map((list, at) => "{\\list\\listtemplateid" + (at + 1) + "\\listhybrid" + list.levels.map((marker, depth) => {
            const count = numbered(marker);
            const nfc = Object.keys(numberFormats).find(k => numberFormats[k] === marker) ?? 23;
            const inset = 720 * (depth + 1);
            return `{\\listlevel\\levelnfc${nfc}\\levelnfcn${nfc}\\leveljc0\\leveljcn0\\levelfollow0\\levelstartat1\\levelspace360\\levelindent0`
                + `{\\*\\levelmarker \\{${marker}\\}${count ? "." : ""}}`
                + (count ? `{\\leveltext\\leveltemplateid${at * 100 + depth + 1}\\'02\\'0${depth}.;}{\\levelnumbers\\'01;}`
                         : `{\\leveltext\\leveltemplateid${at * 100 + depth + 1}\\'01${escaped(ordinal(marker, 1))};}{\\levelnumbers;}`)
                + `\\fi-360\\li${inset}\\lin${inset} }`;
        }).join("") + `{\\listname ;}\\listid${at + 1}}`).join("\n") + "}\n";
        out += "{\\*\\listoverridetable" + lists.map((_, at) => `{\\listoverride\\listid${at + 1}\\listoverridecount0\\ls${at + 1}}`).join("") + "}\n";
    }
    out += "{\\*\\generator Ambrosia TextEdit;}";
    out += "\\paperw11900\\paperh16840\\margl1440\\margr1440";
    if (model.view)
        out += `\\vieww${twips(model.view.width)}\\viewh${twips(model.view.height)}`;
    out += "\\viewkind0\n";
    return out + body + "}";
}

/** The text alone, a paragraph to a line. */
export function plain(model) {
    return model.paragraphs.map(p => p.runs.map(r => r.text).join("")).join("\n");
}
