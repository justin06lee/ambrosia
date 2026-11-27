.pragma library
// TextEdit's glyphs, drawn by hand on the shell's 24-unit grid (see
// shell/icons.js and settings/qml/glyphs.js): `stroke` is drawn `width`
// units wide (1.5 by default) with round caps, `fill` solid. Our own
// shapes; nothing is taken from Apple's.

function circle(cx, cy, r) {
    return `M${cx - r} ${cy}a${r} ${r} 0 1 0 ${2 * r} 0a${r} ${r} 0 1 0 ${-2 * r} 0z`;
}

var glyphs = {
    chevronDown: { stroke: "M7 9.5l5 5 5-5", width: 2.4 },
    chevronUpDown: { stroke: "M8 9.5l4-4 4 4M8 14.5l4 4 4-4", width: 2.2 },
    chevronLeft: { stroke: "M14.5 6.5L9 12l5.5 5.5", width: 2.2 },
    chevronRight: { stroke: "M9.5 6.5L15 12l-5.5 5.5", width: 2.2 },
    alignLeft: { stroke: "M4 6.5h16M4 12h11M4 17.5h16", width: 1.8 },
    alignCenter: { stroke: "M4 6.5h16M6.5 12h11M4 17.5h16", width: 1.8 },
    alignRight: { stroke: "M4 6.5h16M9 12h11M4 17.5h16", width: 1.8 },
    alignJustify: { stroke: "M4 6.5h16M4 12h16M4 17.5h16", width: 1.8 },
    list: { stroke: "M9.5 6.5h10.5M9.5 12h10.5M9.5 17.5h10.5", fill: circle(5, 6.5, 1.5) + circle(5, 12, 1.5) + circle(5, 17.5, 1.5), width: 1.8 },
    search: { stroke: circle(10.5, 10.5, 6.5) + "M15.3 15.3L20.5 20.5", width: 1.9 },
    cross: { stroke: "M8 8l8 8M16 8l-8 8", width: 2.6 },
    check: { stroke: "M5.5 12.5l4.2 4.2L18.5 7.5", width: 2.2 },
};
