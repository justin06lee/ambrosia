.pragma library
// Notes' glyphs, drawn by hand on the shell's 24-unit grid (see
// shell/icons.js and settings/qml/glyphs.js): `stroke` is drawn `width`
// units wide (1.5 by default) with round caps, `fill` solid. Our own
// shapes; nothing is taken from Apple's.

function circle(cx, cy, r) {
    return `M${cx - r} ${cy}a${r} ${r} 0 1 0 ${2 * r} 0a${r} ${r} 0 1 0 ${-2 * r} 0z`;
}
function rect(x, y, w, h, r) {
    return `M${x + r} ${y}h${w - 2 * r}a${r} ${r} 0 0 1 ${r} ${r}v${h - 2 * r}a${r} ${r} 0 0 1 ${-r} ${r}h${-(w - 2 * r)}a${r} ${r} 0 0 1 ${-r} ${-r}v${-(h - 2 * r)}a${r} ${r} 0 0 1 ${r} ${-r}z`;
}

const folder = "M2.8 8a2.2 2.2 0 0 1 2.2-2.2h3.9l2 2.2h8.1a2.2 2.2 0 0 1 2.2 2.2v7.3a2.2 2.2 0 0 1-2.2 2.2H5a2.2 2.2 0 0 1-2.2-2.2z";

var glyphs = {
    // A window with its sidebar marked off (Preview's).
    sidebar: { stroke: rect(2.5, 4.5, 19, 15, 3.4) + "M9.2 4.5v15M5.2 8.6h1.6M5.2 11.4h1.6" },
    chevronRight: { stroke: "M9.5 6.5L15 12l-5.5 5.5", width: 2.2 },
    chevronLeft: { stroke: "M14.5 6.5L9 12l5.5 5.5", width: 2.2 },
    chevronDown: { stroke: "M6.5 9.5l5.5 5.5 5.5-5.5", width: 2.2 },
    check: { stroke: "M5.5 12.5l4.2 4.2L18.5 7.5", width: 2.2 },
    folder: { stroke: folder },
    // A folder with a plus in a disc over its corner.
    folderPlus: {
        stroke: "M14.2 19.7H4.4a2.2 2.2 0 0 1-2.2-2.2V7.6a2.2 2.2 0 0 1 2.2-2.2h3.9l2 2.2h7.5a2.2 2.2 0 0 1 2.2 2.2v1.1M19.2 14.7v5M16.7 17.2h5",
        dimStroke: "",
    },
    trash: { stroke: "M4.5 6.5h15M9.5 6.5V4.8a1 1 0 0 1 1-1h3a1 1 0 0 1 1 1v1.7M6.3 6.5l.9 12.6a1.6 1.6 0 0 0 1.6 1.4h6.4a1.6 1.6 0 0 0 1.6-1.4l.9-12.6M10 10v7M14 10v7" },
    more: { fill: circle(4.8, 12, 1.8) + circle(12, 12, 1.8) + circle(19.2, 12, 1.8) },
    search: { stroke: circle(10.5, 10.5, 6.5) + "M15.3 15.3L20.5 20.5", width: 1.9 },
    // A sheet with a pencil laid across its corner.
    compose: { stroke: "M11.5 4.6H7a3 3 0 0 0-3 3V17a3 3 0 0 0 3 3h9.4a3 3 0 0 0 3-3v-4.5M19.6 3.4l1.1 1.1-8.2 8.3-2 .8.8-2z" },
    // Two rows: a ticked ring and an empty one, each before a line.
    checklist: { stroke: circle(5.6, 7.2, 3.1) + circle(5.6, 16.8, 3.1) + "M4.3 7.3l1 1 1.7-2.1M12.2 7.2h8.6M12.2 16.8h8.6", width: 1.45 },
    pin: { stroke: "M9 3.5h6M10 3.5v5.2l-2.6 3.6v1.4h9.2v-1.4L14 8.7V3.5M12 13.7v6.8" },
    close: { stroke: "M7.5 7.5l9 9M16.5 7.5l-9 9", width: 2.6 },
    clear: { fill: circle(12, 12, 8.5) + "M8.9 9.9l1-1 2.1 2.1 2.1-2.1 1 1-2.1 2.1 2.1 2.1-1 1-2.1-2.1-2.1 2.1-1-1 2.1-2.1z" },
};
