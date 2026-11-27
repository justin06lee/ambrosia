.pragma library
// Font Book's glyphs, drawn by hand on the shell's 24-unit grid (see
// shell/icons.js and settings/qml/glyphs.js): `stroke` is drawn `width`
// units wide (1.5 by default) with round caps, `fill` solid. Our own
// shapes; nothing is taken from Apple's.

function circle(cx, cy, r) {
    return `M${cx - r} ${cy}a${r} ${r} 0 1 0 ${2 * r} 0a${r} ${r} 0 1 0 ${-2 * r} 0z`;
}
function rect(x, y, w, h, r) {
    return `M${x + r} ${y}h${w - 2 * r}a${r} ${r} 0 0 1 ${r} ${r}v${h - 2 * r}a${r} ${r} 0 0 1 ${-r} ${r}h${-(w - 2 * r)}a${r} ${r} 0 0 1 ${-r} ${-r}v${-(h - 2 * r)}a${r} ${r} 0 0 1 ${r} ${-r}z`;
}
// A gear of `teeth` teeth around a hole (settings/qml/glyphs.js): tooth
// tops at `outer`, the rim between them at `inner`.
function gear(cx, cy, outer, inner, teeth, hole) {
    const step = (2 * Math.PI) / teeth;
    const at = (radius, angle) => `${(cx + radius * Math.cos(angle)).toFixed(2)} ${(cy + radius * Math.sin(angle)).toFixed(2)}`;
    let path = "";
    for (let i = 0; i < teeth; ++i) {
        const a = i * step - Math.PI / 2;
        path += (i === 0 ? "M" : "L") + at(inner, a - step * 0.32) + "L" + at(outer, a - step * 0.2) + "L" + at(outer, a + step * 0.2) + "L" + at(inner, a + step * 0.32);
    }
    return path + "Z" + circle(cx, cy, hole);
}

var glyphs = {
    // A window with its sidebar marked off (Preview's).
    sidebar: { stroke: rect(2.5, 4.5, 19, 15, 3.4) + "M9.2 4.5v15M5.2 8.6h1.6M5.2 11.4h1.6" },
    chevronLeft: { stroke: "M14.5 5.5L8 12l6.5 6.5", width: 2.2 },
    chevronRight: { stroke: "M9.5 6.5L15 12l-5.5 5.5", width: 2.2 },
    chevronDown: { stroke: "M6.5 9.5l5.5 5.5 5.5-5.5", width: 2.2 },
    chevronUpDown: { stroke: "M8 9.5l4-4 4 4M8 14.5l4 4 4-4", width: 2.2 },
    // The three views: cards, samples one under another, a list.
    viewGrid: { stroke: rect(3.5, 3.5, 7, 7, 1.8) + rect(13.5, 3.5, 7, 7, 1.8) + rect(3.5, 13.5, 7, 7, 1.8) + rect(13.5, 13.5, 7, 7, 1.8) },
    viewSamples: { stroke: rect(3, 3.5, 18, 7, 2) + rect(3, 13.5, 18, 7, 2) },
    viewList: { stroke: "M8.5 6h12M8.5 12h12M8.5 18h12", fill: circle(4.2, 6, 1.2) + circle(4.2, 12, 1.2) + circle(4.2, 18, 1.2), width: 1.7 },
    // A typeface's page as a specimen: lines of text.
    viewSpecimen: { stroke: "M4 6h16M4 10h16M4 14h16M4 18h10" },
    // About the typeface: a plain i.
    info: { stroke: "M9.8 10.2h2.4v7.6M9.2 17.8h5.6", fill: circle(11.9, 6.3, 1.25), width: 1.6 },
    infoRing: { stroke: circle(12, 12, 9.6) + "M10.6 10.6h1.6v5.9M10 16.5h4.2", fill: circle(11.9, 7.6, 1.1), width: 1.3 },
    search: { stroke: circle(10.5, 10.5, 6.5) + "M15.3 15.3L20.5 20.5", width: 1.9 },
    cross: { stroke: "M8 8l8 8M16 8l-8 8", width: 2.6 },
    check: { stroke: "M5.5 12.5l4.2 4.2L18.5 7.5", width: 2.2 },
    // A font the system holds: it can't be removed.
    lock: { stroke: "M7.6 11V8a4.4 4.4 0 0 1 8.8 0v3", fill: rect(5, 10.6, 14, 10.4, 2.6), width: 1.9 },
    // The sidebar: every font (cards), the user's own (a head in a ring),
    // a collection (one sheet on another), a collection that fills itself
    // (a gear).
    grid: { stroke: rect(3.5, 3.5, 7, 7, 1.8) + rect(13.5, 3.5, 7, 7, 1.8) + rect(3.5, 13.5, 7, 7, 1.8) + rect(13.5, 13.5, 7, 7, 1.8) },
    person: { stroke: circle(12, 12, 9.4) + circle(12, 9.6, 3.1) + "M5.9 18.7a6.6 6.6 0 0 1 12.2 0" },
    collection: { stroke: rect(7.5, 7.5, 13, 13, 2.6) + "M16.5 4.6a2.2 2.2 0 0 0-1.6-.7H6a2.6 2.6 0 0 0-2.6 2.6v8.9a2.2 2.2 0 0 0 .9 1.8" },
    gear: { stroke: gear(12, 12, 9.6, 7.4, 8, 3.1), width: 1.4 },
    // A language's two letters stand in this frame.
    badge: { stroke: rect(2.5, 5.5, 19, 13, 3.2), width: 1.3 },
};
