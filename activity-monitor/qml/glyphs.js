.pragma library
// Activity Monitor's glyphs, drawn by hand on the shell's 24-unit grid (see
// shell/icons.js and settings/qml/glyphs.js): `stroke` is drawn `width`
// units wide (1.5 by default) with round caps, `fill` solid. Our own
// shapes; nothing is taken from Apple's.

function circle(cx, cy, r) {
    return `M${cx - r} ${cy}a${r} ${r} 0 1 0 ${2 * r} 0a${r} ${r} 0 1 0 ${-2 * r} 0z`;
}

const ring = circle(12, 12, 9);

var glyphs = {
    // Quit the process: a cross in a ring.
    stop: { stroke: ring + "M8.8 8.8l6.4 6.4M15.2 8.8l-6.4 6.4" },
    // About the process: an i in a ring.
    info: { stroke: ring + "M12 11.2v5.3", fill: circle(12, 7.9, 1.05) },
    // Which processes to list: three dots in a ring.
    more: { stroke: ring, fill: circle(7.9, 12, 1.1) + circle(12, 12, 1.1) + circle(16.1, 12, 1.1) },
    chevronDown: { stroke: "M7 10l5 5 5-5", width: 2.2 },
    // Beside a graph's name that can be changed.
    chevronUpDown: { stroke: "M8 9.5l4-4 4 4M8 14.5l4 4 4-4", width: 2.2 },
    search: { stroke: circle(10.5, 10.5, 6.5) + "M15.3 15.3L20.5 20.5", width: 1.9 },
    cross: { stroke: "M8 8l8 8M16 8l-8 8", width: 2.6 },
    check: { stroke: "M5.5 12.5l4.2 4.2L18.5 7.5", width: 2.2 },
    // Show in Files: an arrow on a disc (the arrow is cut out by the caller
    // drawing it over the disc in the ground's color).
    disc: { fill: circle(12, 12, 10) },
    arrowRight: { stroke: "M7.5 12h9M12.6 8l4 4-4 4", width: 2.4 },
};
