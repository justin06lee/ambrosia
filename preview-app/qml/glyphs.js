.pragma library
// Preview's glyphs, drawn by hand on the shell's 24-unit grid (see
// shell/icons.js and settings/qml/glyphs.js): `stroke` is drawn `width`
// units wide (1.5 by default) with round caps, `fill` solid. Our own
// shapes; nothing is taken from Apple's.

function circle(cx, cy, r) {
    return `M${cx - r} ${cy}a${r} ${r} 0 1 0 ${2 * r} 0a${r} ${r} 0 1 0 ${-2 * r} 0z`;
}

function rect(x, y, w, h, r) {
    return `M${x + r} ${y}h${w - 2 * r}a${r} ${r} 0 0 1 ${r} ${r}v${h - 2 * r}a${r} ${r} 0 0 1 ${-r} ${r}` +
        `h${2 * r - w}a${r} ${r} 0 0 1 ${-r} ${-r}v${2 * r - h}a${r} ${r} 0 0 1 ${r} ${-r}z`;
}

const lens = circle(10.5, 10.5, 6.5) + "M15.3 15.3L20.5 20.5";

var glyphs = {
    // A window with its sidebar marked off.
    sidebar: { stroke: rect(2.5, 4.5, 19, 15, 3.4) + "M9.2 4.5v15M5.2 8.6h1.6M5.2 11.4h1.6" },
    chevronDown: { stroke: "M7 10l5 5 5-5", width: 2.2 },
    zoomOut: { stroke: lens + "M7.7 10.5h5.6" },
    zoomIn: { stroke: lens + "M7.7 10.5h5.6M10.5 7.7v5.6" },
    // Actual size: a 1 in the lens.
    zoomActual: { stroke: lens + "M9.4 8.9l1.5-1.1v5.6" },
    rotateLeft: { stroke: rect(4.5, 10, 11, 10, 1.8) + "M19.5 15v-3a5.5 5.5 0 0 0-5.5-5.5h-3.5M13 4l-2.5 2.5L13 9" },
    search: { stroke: lens, width: 1.9 },
    cross: { stroke: "M8 8l8 8M16 8l-8 8", width: 2.6 },
    check: { stroke: "M5.5 12.5l4.2 4.2L18.5 7.5", width: 2.2 },
    lock: { stroke: "M6.82 11V7.2a5.18 5.18 0 0 1 10.36 0V11" + rect(4.5, 11, 15, 10.5, 2.6) },
};
