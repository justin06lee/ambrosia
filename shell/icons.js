.pragma library
// The shell's line icons, on the same 24-unit grid and with the same paths as
// the preview's sprite (preview/index.html): `stroke` is drawn 1.5 units wide
// (or `width`) with round caps, `fill` solid with the nonzero rule, so
// overlapping shapes drawn the same way round merge into one.

function circle(cx, cy, r) {
    return `M${cx - r} ${cy}a${r} ${r} 0 1 0 ${2 * r} 0a${r} ${r} 0 1 0 ${-2 * r} 0z`;
}

function rect(x, y, w, h, r) {
    return `M${x + r} ${y}h${w - 2 * r}a${r} ${r} 0 0 1 ${r} ${r}v${h - 2 * r}a${r} ${r} 0 0 1 ${-r} ${r}` +
        `h${2 * r - w}a${r} ${r} 0 0 1 ${-r} ${-r}v${2 * r - h}a${r} ${r} 0 0 1 ${r} ${-r}z`;
}

var glyphs = {
    // The Ambrosia mark: a bowl of ambrosia, heaped in three scoops, with a
    // spoon standing in it.
    bowl: {
        fill: "M18.6 12.4H2.4A8.1 7.2 0 0 0 18.6 12.4Z" +
            circle(6.1, 11.4, 2.9) + circle(10.5, 9.5, 3.7) + circle(14.9, 11.3, 2.9) +
            "M17.25 10.21L22.05 3.51A1.05 1.05 0 0 0 20.35 2.29L15.55 8.99A1.05 1.05 0 0 0 17.25 10.21Z",
    },
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
    right: { stroke: "M9.5 6l6 6-6 6" },
    check: { stroke: "M5.5 12.5l4 4 9-9", width: 2 },
    bluetooth: { stroke: "M7 7.5l10 9-5 4.5V3l5 4.5-10 9" },
    moon: { stroke: "M19.5 14.5A8 8 0 0 1 9.5 4.5a8 8 0 1 0 10 10z" },
    sun: {
        stroke: circle(12, 12, 4) +
            "M12 2.5v2M12 19.5v2M2.5 12h2M19.5 12h2M5.3 5.3l1.4 1.4M17.3 17.3l1.4 1.4M5.3 18.7l1.4-1.4M17.3 6.7l1.4-1.4",
    },
    speaker: { stroke: "M4 9.5h3.5L12 5.5v13l-4.5-4H4zM15.5 9a4 4 0 0 1 0 6M18 6.5a7.5 7.5 0 0 1 0 11" },
    speakerOff: { stroke: "M4 9.5h3.5L12 5.5v13l-4.5-4H4zM15.5 9.5l5 5M20.5 9.5l-5 5" },
    contrast: { stroke: circle(12, 12, 8.5), fill: "M12 3.5v17a8.5 8.5 0 0 0 0-17z" },
    play: { fill: "M8 5.5v13l10-6.5z" },
    pause: { fill: rect(6.5, 5.5, 3.5, 13, 1) + rect(14, 5.5, 3.5, 13, 1) },
    forward: { fill: "M4 6.5v11l7.5-5.5zM12 6.5v11l7.5-5.5z" },
    back: { fill: "M20 6.5v11l-7.5-5.5zM12 6.5v11L4.5 12z" },
    screenshot: {
        stroke: "M4 8.5V6.5a2.5 2.5 0 0 1 2.5-2.5h2M15.5 4h2A2.5 2.5 0 0 1 20 6.5v2M20 15.5v2a2.5 2.5 0 0 1-2.5 2.5h-2M8.5 20h-2A2.5 2.5 0 0 1 4 17.5v-2" +
            circle(12, 12, 3),
    },
    nightlight: { stroke: "M3 17h18M7 17a5 5 0 0 1 10 0M12 6.5V9M5.6 10.6l1.2 1.2M18.4 10.6l-1.2 1.2M8 20.5h8" },
    headphones: { stroke: "M4 14v-2a8 8 0 0 1 16 0v2" + rect(3.5, 13.5, 4, 7, 1.5) + rect(16.5, 13.5, 4, 7, 1.5) },
    speakerbox: { stroke: rect(6.5, 3.5, 11, 17, 2.5) + circle(12, 14.5, 2.5), fill: circle(12, 7.5, 1) },
    gear: {
        stroke: circle(12, 12, 3) + circle(12, 12, 6.5) +
            "M12 2.5v3M12 18.5v3M2.5 12h3M18.5 12h3M5.3 5.3l2.1 2.1M16.6 16.6l2.1 2.1M5.3 18.7l2.1-2.1M16.6 7.4l2.1-2.1",
    },
    folder: { stroke: "M3.5 7.5a2 2 0 0 1 2-2h4l2 2h7a2 2 0 0 1 2 2v8a2 2 0 0 1-2 2h-13a2 2 0 0 1-2-2z" },
    download: { stroke: circle(12, 12, 8.5) + "M12 7.5v8M8.5 12.5 12 16l3.5-3.5" },
    trash: { stroke: "M5 7h14M9.5 7V5h5v2M6.5 7l1 12.5h9l1-12.5M10 10.5v6M14 10.5v6" },
    lock: { stroke: rect(5, 10.5, 14, 10, 2.5) + "M8 10.5V8a4 4 0 0 1 8 0v2.5" },
    power: { stroke: "M12 3.5v8M7.2 6.3a7.5 7.5 0 1 0 9.6 0" },
    globe: {
        stroke: circle(12, 12, 8.5) +
            "M3.5 12h17M12 3.5c2.4 2.5 3.5 5.5 3.5 8.5s-1.1 6-3.5 8.5c-2.4-2.5-3.5-5.5-3.5-8.5s1.1-6 3.5-8.5z",
    },
};
