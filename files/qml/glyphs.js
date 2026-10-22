.pragma library
// Files' line glyphs, drawn by hand on the shell's 24-unit grid (see
// shell/icons.js): `stroke` is drawn `width` units wide (1.5 by default) with
// round caps, `fill` solid. Our own shapes; nothing is taken from Apple's.

function circle(cx, cy, r) {
    return `M${cx - r} ${cy}a${r} ${r} 0 1 0 ${2 * r} 0a${r} ${r} 0 1 0 ${-2 * r} 0z`;
}

function rect(x, y, w, h, r) {
    return `M${x + r} ${y}h${w - 2 * r}a${r} ${r} 0 0 1 ${r} ${r}v${h - 2 * r}a${r} ${r} 0 0 1 ${-r} ${r}` +
        `h${2 * r - w}a${r} ${r} 0 0 1 ${-r} ${-r}v${2 * r - h}a${r} ${r} 0 0 1 ${r} ${-r}z`;
}

var glyphs = {
    back: { stroke: "M14.5 5L7.5 12l7 7", width: 2 },
    forward: { stroke: "M9.5 5l7 7-7 7", width: 2 },
    viewIcons: { stroke: rect(4, 4, 6.5, 6.5, 1.6) + rect(13.5, 4, 6.5, 6.5, 1.6) + rect(4, 13.5, 6.5, 6.5, 1.6) + rect(13.5, 13.5, 6.5, 6.5, 1.6) },
    viewList: {
        stroke: "M9 6.5h11M9 12h11M9 17.5h11",
        fill: circle(4.8, 6.5, 1.25) + circle(4.8, 12, 1.25) + circle(4.8, 17.5, 1.25),
    },
    viewColumns: { stroke: rect(3, 5, 18, 14, 2.5) + "M9 5v14M15 5v14" },
    viewGallery: {
        stroke: rect(3, 4, 18, 11.5, 2.5),
        fill: rect(3, 17.6, 2.6, 2.6, 0.7) + rect(6.85, 17.6, 2.6, 2.6, 0.7) + rect(10.7, 17.6, 2.6, 2.6, 0.7) +
            rect(14.55, 17.6, 2.6, 2.6, 0.7) + rect(18.4, 17.6, 2.6, 2.6, 0.7),
    },
    group: {
        fill: rect(2.5, 6, 5, 4.2, 1) + rect(9.5, 6, 5, 4.2, 1) + rect(16.5, 6, 5, 4.2, 1) +
            rect(2.5, 13.8, 5, 4.2, 1) + rect(9.5, 13.8, 5, 4.2, 1) + rect(16.5, 13.8, 5, 4.2, 1),
    },
    chevronDown: { stroke: "M7 10l5 5 5-5", width: 1.8 },
    share: { stroke: "M8.5 9.5H7a2 2 0 0 0-2 2V19a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2v-7.5a2 2 0 0 0-2-2h-1.5M12 2.8v11.4M8.6 6.2L12 2.8l3.4 3.4" },
    tag: {
        stroke: "M3.5 4.8v6.3a1.6 1.6 0 0 0 .47 1.13l8.3 8.3a1.6 1.6 0 0 0 2.26 0l5.7-5.7a1.6 1.6 0 0 0 0-2.26l-8.3-8.3a1.6 1.6 0 0 0-1.13-.47H4.8a1.3 1.3 0 0 0-1.3 1.3z",
        fill: circle(8, 8, 1.4),
    },
    more: { fill: circle(5, 12, 1.7) + circle(12, 12, 1.7) + circle(19, 12, 1.7) },
    search: { stroke: circle(10.5, 10.5, 6.5) + "M15.3 15.3L20.5 20.5", width: 1.9 },
    recents: { stroke: circle(12, 12, 8.75) + "M12 7v5.2l3.4 2.1" },
    shared: { stroke: "M3 7.5a2 2 0 0 1 2-2h4l2 2h8a2 2 0 0 1 2 2V17a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z" },
    desktop: { stroke: rect(3, 4.5, 18, 15, 2.5) + "M3 15h18" },
    documents: { stroke: "M6.5 3.5h7l4.5 4.5v11a1.5 1.5 0 0 1-1.5 1.5h-10A1.5 1.5 0 0 1 5 19V5a1.5 1.5 0 0 1 1.5-1.5zM13.5 3.5V8H18" },
    downloads: { stroke: circle(12, 12, 8.75) + "M12 7.2v9.2M8.4 12.9l3.6 3.6 3.6-3.6" },
    home: { stroke: "M3.5 11.2L12 4l8.5 7.2M6 9.2V19a1 1 0 0 0 1 1h3.4v-5.2h3.2V20H17a1 1 0 0 0 1-1V9.2" },
    drive: { stroke: rect(2.8, 8.5, 18.4, 9.5, 2.8) + "M6.5 14.6h4", fill: circle(17, 14.6, 1) },
    trash: { stroke: "M4.5 6.5h15M9.5 6.5V4.8a1 1 0 0 1 1-1h3a1 1 0 0 1 1 1v1.7M6.3 6.5l.9 12.6a1.6 1.6 0 0 0 1.6 1.4h6.4a1.6 1.6 0 0 0 1.6-1.4l.9-12.6M10 10v7M14 10v7" },
    disclosure: { stroke: "M10 7.5l4.5 4.5-4.5 4.5", width: 1.8 },
    sortUp: { stroke: "M7.5 14l4.5-4.5 4.5 4.5", width: 1.6 },
    sortDown: { stroke: "M7.5 10l4.5 4.5 4.5-4.5", width: 1.6 },
    pathSeparator: { stroke: "M10 8l4 4-4 4", width: 1.6 },
    check: { stroke: "M5.5 12.5l4.2 4.2L18.5 7.5", width: 2.2 },
    chevronUpDown: { stroke: "M8.5 9.5L12 6l3.5 3.5M8.5 14.5L12 18l3.5-3.5", width: 2 },
    overflow: { stroke: "M6.5 6.5l5.5 5.5-5.5 5.5M12.5 6.5l5.5 5.5-5.5 5.5", width: 2 },
};
