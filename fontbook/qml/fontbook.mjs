// What Font Book lists, in what order and in what words: the sidebar's
// places, which typefaces each holds, the letters that stand for a
// typeface, and what the info pane says of one. Plain values in and out,
// so `bun test fontbook/` can check it; the C++ Library only reads the
// fonts. Kept to what QML's JavaScript runs (no object spread, no ??=).

// What a font can write (the Library's keys), by name, with the letters
// that stand for it on a card and a line of it for a sample.
export const scripts = {
    latin: { name: "Latin", sample: "Aa", line: "The quick brown fox jumps over the lazy dog and runs away." },
    cyrillic: { name: "Cyrillic", sample: "Жж", line: "Съешь же ещё этих мягких французских булок, да выпей чаю." },
    greek: { name: "Greek", sample: "Αα", line: "Ξεσκεπάζω την ψυχοφθόρα βδελυγμία." },
    armenian: { name: "Armenian", sample: "Աա", line: "Աբգդեզէըթժ իլխծկհձղճմ" },
    georgian: { name: "Georgian", sample: "ა", line: "აბგდევზთიკლმნოპჟრსტუ" },
    hebrew: { name: "Hebrew", sample: "א", line: "אבגדהוזחטיכלמנסעפצקרשת" },
    arabic: { name: "Arabic", sample: "ع", line: "أبجد هوز حطي كلمن سعفص قرشت ثخذ ضظغ" },
    devanagari: { name: "Devanagari", sample: "क", line: "अआइईउऊ कखगघङ चछजझञ" },
    bengali: { name: "Bangla", sample: "ক", line: "অআইঈউঊ কখগঘঙ চছজঝঞ" },
    gurmukhi: { name: "Gurmukhi", sample: "ਕ", line: "ਅਆਇਈਉਊ ਕਖਗਘਙ ਚਛਜਝਞ" },
    gujarati: { name: "Gujarati", sample: "ક", line: "અઆઇઈઉઊ કખગઘઙ ચછજઝઞ" },
    oriya: { name: "Odia", sample: "କ", line: "ଅଆଇଈଉଊ କଖଗଘଙ ଚଛଜଝଞ" },
    tamil: { name: "Tamil", sample: "க", line: "அஆஇஈஉஊ கஙசஞடண தநபம" },
    telugu: { name: "Telugu", sample: "క", line: "అఆఇఈఉఊ కఖగఘఙ చఛజఝఞ" },
    kannada: { name: "Kannada", sample: "ಕ", line: "ಅಆಇಈಉಊ ಕಖಗಘಙ ಚಛಜಝಞ" },
    malayalam: { name: "Malayalam", sample: "ക", line: "അആഇഈഉഊ കഖഗഘങ ചഛജഝഞ" },
    sinhala: { name: "Sinhala", sample: "ක", line: "අආඇඈඉඊ කඛගඝඞ චඡජඣඤ" },
    thai: { name: "Thai", sample: "ก", line: "กขคฆงจฉชซฌญฎฏฐฑฒณดต" },
    lao: { name: "Lao", sample: "ກ", line: "ກຂຄງຈສຊຍດຕຖທນບປຜຝພຟ" },
    tibetan: { name: "Tibetan", sample: "ཀ", line: "ཀཁགངཅཆཇཉཏཐདནཔཕབམ" },
    myanmar: { name: "Myanmar", sample: "က", line: "ကခဂဃငစဆဇဈညဋဌဍဎဏ" },
    khmer: { name: "Khmer", sample: "ក", line: "កខគឃងចឆជឈញដឋឌឍណ" },
    ethiopic: { name: "Ethiopic", sample: "አ", line: "ሀለሐመሠረሰሸቀበተቸኀነኘአ" },
    cherokee: { name: "Cherokee", sample: "Ꭰ", line: "ᎠᎡᎢᎣᎤᎥᎦᎧᎨᎩᎪᎫᎬᎭᎮᎯ" },
    mongolian: { name: "Mongolian", sample: "ᠠ", line: "ᠠᠡᠢᠣᠤᠥᠦᠨᠩᠪᠫᠬᠭᠮᠯᠰ" },
    hangul: { name: "Hangul", sample: "한", line: "다람쥐 헌 쳇바퀴에 타고파" },
    hiragana: { name: "Hiragana", sample: "あ", line: "いろはにほへと ちりぬるを わかよたれそ" },
    katakana: { name: "Katakana", sample: "ア", line: "イロハニホヘト チリヌルヲ ワカヨタレソ" },
    han: { name: "Han", sample: "漢", line: "天地玄黃 宇宙洪荒 日月盈昃 辰宿列張" },
    braille: { name: "Braille", sample: "⠿", line: "⠁⠃⠉⠙⠑⠋⠛⠓⠊⠚⠅⠇⠍⠝⠕⠏" },
    emoji: { name: "Emoji", sample: "😀", line: "😀😃😄😁😆😅😂🙂😉😊😍😎" },
    math: { name: "Mathematical Symbols", sample: "∑", line: "∑∏∫∂∆∇√∞≈≠≤≥±×÷" },
};
// Scripts that say what a typeface is for, ahead of the Latin most carry.
const own = ["arabic", "hebrew", "devanagari", "bengali", "gurmukhi", "gujarati", "oriya", "tamil", "telugu", "kannada", "malayalam", "sinhala",
             "thai", "lao", "tibetan", "myanmar", "khmer", "ethiopic", "cherokee", "mongolian", "armenian", "georgian"];
// A word in a typeface's name that says which script it was drawn for.
const hints = [
    [/\b(JP|Japanese|Mincho|Gothic)\b/, "hiragana"], [/\b(KR|Korean)\b/, "hangul"], [/\b(SC|TC|HK|CJK|Chinese|Hei|Song|Ming|Kai)\b/, "han"],
    [/Arabic|Naskh|Kufi|Nastaliq/i, "arabic"], [/Hebrew/i, "hebrew"], [/Devanagari/i, "devanagari"], [/Bengali|Bangla/i, "bengali"],
    [/Gurmukhi/i, "gurmukhi"], [/Gujarati/i, "gujarati"], [/Oriya|Odia/i, "oriya"], [/Tamil/i, "tamil"], [/Telugu/i, "telugu"],
    [/Kannada/i, "kannada"], [/Malayalam/i, "malayalam"], [/Sinhala/i, "sinhala"], [/Thai\b/i, "thai"], [/\bLao\b/i, "lao"],
    [/Tibetan/i, "tibetan"], [/Myanmar/i, "myanmar"], [/Khmer/i, "khmer"], [/Ethiopic/i, "ethiopic"], [/Cherokee/i, "cherokee"],
    [/Mongolian/i, "mongolian"], [/Armenian/i, "armenian"], [/Georgian/i, "georgian"], [/Emoji/i, "emoji"], [/Braille/i, "braille"],
    [/\bMath\b/i, "math"],
];

// The script a typeface is shown by: the one its name says, else East
// Asian writing where it has it, else Latin, else what else it writes.
export function scriptOf(family) {
    const has = family.scripts || [];
    for (const hint of hints) {
        if (hint[0].test(family.family) && has.includes(hint[1]))
            return hint[1];
    }
    if (family.color && has.includes("emoji"))
        return "emoji";
    if (has.includes("hiragana") && has.includes("han"))
        return "hiragana";
    if (has.includes("hangul") && !has.includes("latin"))
        return "hangul";
    if (has.includes("han"))
        return "han";
    if (has.includes("latin"))
        return "latin";
    for (const key of own) {
        if (has.includes(key))
            return key;
    }
    for (const key of ["cyrillic", "greek", "hangul", "hiragana", "katakana", "braille", "emoji", "math"]) {
        if (has.includes(key))
            return key;
    }
    return "";
}
// The letters on a typeface's card.
export function sample(family) {
    const script = scriptOf(family);
    if (script !== "")
        return scripts[script].sample;
    return family.first || "Aa";
}
// A line of it, for the samples view.
export function line(family) {
    const script = scriptOf(family);
    if (script !== "")
        return scripts[script].line;
    return family.first || "";
}
// The three lines a typeface's page and the info pane open with.
export function specimen(family) {
    const script = scriptOf(family);
    if (script === "latin" || script === "")
        return script === "" && family.first ? family.first : "ABCDEFGHIJKLMNOPQRSTUVWXYZ\nabcdefghijklmnopqrstuvwxyz\n1234567890";
    return scripts[script].line;
}

export function stylesText(count) {
    return count === 1 ? "1 style" : count + " styles";
}
export function typefacesText(count) {
    return count === 1 ? "1 typeface" : count + " typefaces";
}

// The sidebar: [{ title, items: [{ key, title, glyph, badge }] }]. A
// heading with nothing under it isn't there.
export function sections(languages, collections) {
    const all = [
        { title: "Fonts", items: [{ key: "all", title: "All Fonts", glyph: "grid" }, { key: "mine", title: "My Fonts", glyph: "person" }] },
        { title: "Languages", items: (languages || []).map(language => ({ key: "lang:" + language.code, title: language.name, badge: language.code.toUpperCase().slice(0, 2) })) },
        { title: "Collections", items: collectionNames(collections).map(name => ({ key: "collection:" + name, title: name, glyph: "collection", collection: name })) },
        { title: "Smart Collections", items: [{ key: "mono", title: "Fixed Width", glyph: "gear" }] },
    ];
    return all.filter(section => section.items.length > 0);
}
export function sectionTitle(key, languages) {
    if (key.startsWith("collection:"))
        return key.slice(11);
    for (const section of sections(languages, {})) {
        const item = section.items.find(item => item.key === key);
        if (item)
            return item.title;
    }
    return "All Fonts";
}

// The typefaces a place holds, those whose names (or a style's) hold every
// word searched for.
export function listed(families, options) {
    const section = options.section || "all";
    const words = (options.search || "").toLowerCase().split(/\s+/).filter(word => word !== "");
    const members = section.startsWith("collection:") ? ((options.collections || {})[section.slice(11)] || []) : null;
    const lang = section.startsWith("lang:") ? section.slice(5) : "";
    return families.filter(family => {
        if (section === "mine" && !family.user)
            return false;
        if (section === "mono" && !family.mono)
            return false;
        if (lang !== "" && !(family.langs || []).some(code => code === lang || code.startsWith(lang + "-")))
            return false;
        if (members !== null && !members.includes(family.family))
            return false;
        if (words.length === 0)
            return true;
        const text = (family.family + " " + family.styles.map(style => style.name + " " + (style.postscript || "")).join(" ")).toLowerCase();
        return words.every(word => text.includes(word));
    });
}

// How many cards fit a row and how far apart they stand: at least
// `minGap`, the row filling the width.
export function columns(width, card, minGap) {
    const count = Math.max(1, Math.floor((width + minGap) / (card + minGap)));
    return { count: count, gap: count > 1 ? (width - count * card) / (count - 1) : 0 };
}

// What the size slider (0 to 1) means in each view.
export function cardSize(t) { return Math.round(115 * (0.7 + 0.6 * t)); }
export function sampleSize(t) { return Math.round(12 + 100 * t * t); }
export function listSize(t) { return Math.round(13 + 13 * t); }
export function specimenSize(t) { return Math.round(16 + 70 * t); }
export function glyphBox(t) { return Math.round(26 + 53 * t); }

// The list view's rows: a typeface, and its styles under it when it is
// opened.
export function rows(families, expanded) {
    const out = [];
    for (const family of families) {
        const open = expanded.includes(family.family);
        out.push({ kind: "family", family: family.family, open: open, styles: family.styles.length, format: family.format, user: family.user, item: family });
        if (open) {
            for (const style of family.styles)
                out.push({ kind: "style", family: family.family, style: style.name, item: family });
        }
    }
    return out;
}

// The different things said, each with how many styles say it: [{ text,
// count }], blank ones left out.
export function grouped(values) {
    const out = [];
    for (const value of values) {
        if (!value)
            continue;
        const have = out.find(entry => entry.text === value);
        if (have)
            have.count += 1;
        else
            out.push({ text: value, count: 1 });
    }
    return out;
}

// The info pane's four parts for a typeface: each [{ label, values:
// [{ text, note }] }], a row with nothing to say left out. `details` is
// the Library's (what the files say); `scripts` the family's keys.
export function info(family, details) {
    const styles = (details && details.styles) || [];
    const plain = styles[0] || {};
    const said = (label, values, counted) => {
        const groups = grouped(values);
        if (groups.length === 0)
            return null;
        return { label: label, values: groups.map(group => ({ text: String(group.text), note: counted && groups.length > 1 ? stylesText(group.count) : "" })) };
    };
    const rows = (list) => list.filter(row => row !== null);
    const writes = (family.scripts || []).filter(key => scripts[key] && key !== "emoji" && key !== "math" && key !== "braille").map(key => scripts[key].name);
    const language = [];
    if (details && details.languages && details.languages.length > 0)
        language.push({ label: "Supported", text: details.languages.join(" • ") });
    if (writes.length > 0)
        language.push({ label: "Scripts", text: writes.sort().join(" • ") });
    return {
        language: language,
        identifiers: rows([
            said("Family Name", [family.family], false),
            said("Style Name", styles.map(style => style.name), false),
            said("PostScript Name", styles.map(style => style.postscript), false),
            said("Unique Name", styles.map(style => style.unique), false),
        ]),
        usage: rows([
            said("Copyright", styles.map(style => style.copyright), true),
            said("Trademark", styles.map(style => style.trademark), true),
            said("License", styles.map(style => style.license), true),
            said("Embedding", styles.map(style => style.embedding), true),
        ]),
        details: rows([
            said("Format", styles.map(style => style.format), true),
            said("System Font", [family.user ? "No" : "Yes"], false),
            said("Designer", styles.map(style => style.designer), true),
            said("Manufacturer", styles.map(style => style.manufacturer), true),
            said("Glyph Count", plain.glyphs ? [String(plain.glyphs)] : [], false),
            said("Location", styles.map(style => style.file), true),
            said("Version", styles.map(style => style.version), true),
        ]),
    };
}

// Collections: { name: [family] }, kept as text between launches.
export function parseCollections(text) {
    try {
        const read = JSON.parse(text || "{}");
        const out = {};
        for (const name of Object.keys(read)) {
            if (Array.isArray(read[name]))
                out[name] = read[name].filter(member => typeof member === "string");
        }
        return out;
    } catch (error) {
        return {};
    }
}
export function collectionNames(collections) {
    return Object.keys(collections || {}).sort((a, b) => a.localeCompare(b, undefined, { sensitivity: "base", numeric: true }));
}
function copied(collections) {
    const out = {};
    for (const name of Object.keys(collections))
        out[name] = collections[name].slice();
    return out;
}
// A name no collection has yet: "Untitled", "Untitled 2", …
export function freshName(collections, base) {
    const start = base || "Untitled";
    let name = start;
    for (let n = 2; collections[name] !== undefined; ++n)
        name = start + " " + n;
    return name;
}
export function withCollection(collections, name) {
    const out = copied(collections);
    if (out[name] === undefined)
        out[name] = [];
    return out;
}
export function withoutCollection(collections, name) {
    const out = copied(collections);
    delete out[name];
    return out;
}
// Renamed; a blank name, or one another collection has, changes nothing.
export function renamed(collections, from, to) {
    const name = (to || "").trim();
    if (name === "" || name === from || collections[from] === undefined || collections[name] !== undefined)
        return collections;
    const out = {};
    for (const key of Object.keys(collections))
        out[key === from ? name : key] = collections[key].slice();
    return out;
}
export function withMember(collections, name, family) {
    const out = copied(collections);
    if (out[name] !== undefined && !out[name].includes(family))
        out[name].push(family);
    return out;
}
export function withoutMember(collections, name, family) {
    const out = copied(collections);
    if (out[name] !== undefined)
        out[name] = out[name].filter(member => member !== family);
    return out;
}
