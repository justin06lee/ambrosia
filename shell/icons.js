.pragma library
// The shell's line icons, on the same 24-unit grid and with the same paths as
// the preview's sprite (preview/index.html): `stroke` is drawn 1.5 units wide
// with round caps, `fill` solid.

function circle(cx, cy, r) {
    return `M${cx - r} ${cy}a${r} ${r} 0 1 0 ${2 * r} 0a${r} ${r} 0 1 0 ${-2 * r} 0z`;
}

function rect(x, y, w, h, r) {
    return `M${x + r} ${y}h${w - 2 * r}a${r} ${r} 0 0 1 ${r} ${r}v${h - 2 * r}a${r} ${r} 0 0 1 ${-r} ${r}` +
        `h${2 * r - w}a${r} ${r} 0 0 1 ${-r} ${-r}v${2 * r - h}a${r} ${r} 0 0 1 ${r} ${-r}z`;
}

var glyphs = {
    drop: { fill: "M12 2.5c3.7 4.6 6.3 8.1 6.3 11.6a6.3 6.3 0 0 1-12.6 0c0-3.5 2.6-7 6.3-11.6z" },
    wifi: {
        stroke: "M2.5 9a14 14 0 0 1 19 0M5.5 12.5a9.5 9.5 0 0 1 13 0M8.5 16a5 5 0 0 1 7 0",
        fill: circle(12, 19.3, 1.2),
    },
    battery: { stroke: rect(2.5, 7.5, 17, 9, 2.5) + "M21.5 10.5v3", fill: rect(4.5, 9.5, 10.5, 5, 1) },
    controls: {
        stroke: rect(3, 4.5, 18, 6.5, 3.25) + rect(3, 13, 18, 6.5, 3.25) + circle(16.5, 7.75, 1.6) + circle(7.5, 16.25, 1.6),
        fill: circle(16.5, 7.75, 1.6) + circle(7.5, 16.25, 1.6),
    },
    search: { stroke: circle(10.5, 10.5, 6) + "M15 15l5 5" },
};
