.pragma library
// Settings' glyphs, drawn by hand on the shell's 24-unit grid (see
// shell/icons.js, whose paths the shared ones are): `stroke` is drawn
// `width` units wide (1.5 by default) with round caps, `fill` solid with the
// nonzero rule. rect() and polygons run clockwise and circle() the other way,
// so a circle inside a filled outline is a hole. Our own shapes; nothing is
// taken from Apple's.

function circle(cx, cy, r) {
    return `M${cx - r} ${cy}a${r} ${r} 0 1 0 ${2 * r} 0a${r} ${r} 0 1 0 ${-2 * r} 0z`;
}

function rect(x, y, w, h, r) {
    return `M${x + r} ${y}h${w - 2 * r}a${r} ${r} 0 0 1 ${r} ${r}v${h - 2 * r}a${r} ${r} 0 0 1 ${-r} ${r}` +
        `h${2 * r - w}a${r} ${r} 0 0 1 ${-r} ${-r}v${2 * r - h}a${r} ${r} 0 0 1 ${r} ${-r}z`;
}

// A gear of `teeth` teeth around a hole: tooth tops at `outer`, the rim
// between them at `inner`.
function gear(cx, cy, outer, inner, teeth, hole) {
    let d = "";
    const step = 2 * Math.PI / teeth;
    for (let i = 0; i < teeth; ++i) {
        const a = i * step - Math.PI / 2;
        const points = [[a - step * 0.36, inner], [a - step * 0.2, outer], [a + step * 0.2, outer], [a + step * 0.36, inner]];
        for (const [t, r] of points)
            d += (d === "" ? "M" : "L") + (cx + r * Math.cos(t)).toFixed(2) + " " + (cy + r * Math.sin(t)).toFixed(2);
    }
    return d + "Z" + circle(cx, cy, hole);
}

// A flower of six round petals around a dot.
function flower(cx, cy) {
    let d = circle(cx, cy, 1.9);
    for (let i = 0; i < 6; ++i) {
        const a = i * Math.PI / 3 - Math.PI / 2;
        d += circle(+(cx + 5.6 * Math.cos(a)).toFixed(2), +(cy + 5.6 * Math.sin(a)).toFixed(2), 3.1);
    }
    return d;
}

// The speaker by a volume slider, 7.45 × 11 points as System Settings
// draws it: a body 5 tall, its cone flaring to the full height. `k` is
// units to the point, the speaker's middle `cy` units down.
function speakerAt(k, cy) {
    const p = (x, y) => `${+(x * k).toFixed(2)} ${+(cy + y * k).toFixed(2)}`;
    return `M${p(0.54, -2.5)}L${p(2.75, -2.5)}L${p(5.9, -5.25)}Q${p(7.45, -6.28)} ${p(7.45, -4.68)}` +
        `L${p(7.45, 4.68)}Q${p(7.45, 6.28)} ${p(5.9, 5.25)}L${p(2.75, 2.5)}L${p(0.54, 2.5)}` +
        `Q${p(0, 2.5)} ${p(0, 1.96)}L${p(0, -1.96)}Q${p(0, -2.5)} ${p(0.54, -2.5)}Z`;
}

// Its three waves, a point wide, out to 16 points.
function wavesAt(k, cy) {
    const p = (x, y) => `${+(x * k).toFixed(2)} ${+(cy + y * k).toFixed(2)}`;
    return [[10, 2.3, 11], [12, 4, 14.5], [14.5, 5.5, 17.5]]
        .map(([x, h, c]) => `M${p(x, -h)}Q${p(c, 0)} ${p(x, h)}`).join("");
}

// The signal's arcs about a point just above the wedge's tip, 48.5°
// either side: the middle one and the outer one (2 of them), or just the
// outer (-1), just the middle (1), or both dimmed (-2). The wedge is a
// 35° sector about its own tip.
function wifiArc(r) {
    const dx = +(r * 0.749).toFixed(2), y = +(19.8 - r * 0.663).toFixed(2);
    return `M${+(12 - dx).toFixed(2)} ${y}A${r} ${r} 0 0 1 ${+(12 + dx).toFixed(2)} ${y}`;
}
function wifiArcs(lit) {
    return { 3: wifiArc(7.23) + wifiArc(13.15), 2: wifiArc(7.23), "-1": wifiArc(13.15), "-2": wifiArc(7.23) + wifiArc(13.15) }[lit];
}
function wifiWedge() {
    return "M12 21.9L9.19 17.89A4.9 4.9 0 0 1 14.81 17.89Z";
}

var glyphs = {
    // The window's own
    back: { stroke: "M14.5 5L7.5 12l7 7", width: 2 },
    forward: { stroke: "M9.5 5l7 7-7 7", width: 2 },
    search: { stroke: circle(10.5, 10.5, 6.5) + "M15.3 15.3L20.5 20.5", width: 1.9 },
    chevronRight: { stroke: "M9.5 5.5l6.5 6.5-6.5 6.5", width: 2.2 },
    chevronUpDown: { stroke: "M7.9 8.25L12 5.25l4.1 3M7.9 15.75l4.1 3 4.1-3", width: 2.25 },
    check: { stroke: "M5.5 12.5l4.2 4.2L18.5 7.5", width: 2.2 },
    help: { stroke: "M9 9.2a3.1 3.1 0 1 1 4.6 2.7c-1 .6-1.6 1.2-1.6 2.4v.4", width: 2, fill: circle(12, 18, 1.25) },
    cross: { stroke: "M8 8l8 8M16 8l-8 8", width: 2.6 },

    // The panes, white on their colored squares
    wifi: {
        stroke: "M3 9.5a13 13 0 0 1 18 0M6 13a8.5 8.5 0 0 1 12 0M9 16.5a4.2 4.2 0 0 1 6 0",
        fill: circle(12, 19.4, 1.5),
        width: 2.3,
    },
    bluetooth: { stroke: "M7 7.5l10 9-5 4.5V3l5 4.5-10 9", width: 2 },
    network: {
        stroke: circle(12, 12, 8.5) +
            "M3.5 12h17M12 3.5c2.4 2.5 3.5 5.5 3.5 8.5s-1.1 6-3.5 8.5c-2.4-2.5-3.5-5.5-3.5-8.5s1.1-6 3.5-8.5z",
        width: 1.8,
    },
    // Displays' brightness: a small sun of dots, a large one of rays.
    sunLow: { fill: circle(12, 12, 4.2) + [0, 1, 2, 3, 4, 5, 6, 7].map(i => circle(12 + 8.2 * Math.cos(i * Math.PI / 4), 12 + 8.2 * Math.sin(i * Math.PI / 4), 1.25)).join("") },
    sunHigh: {
        stroke: circle(12, 12, 4.4) + [0, 1, 2, 3, 4, 5, 6, 7].map(i => {
            const c = Math.cos(i * Math.PI / 4), s = Math.sin(i * Math.PI / 4);
            return `M${(12 + 7.6 * c).toFixed(2)} ${(12 + 7.6 * s).toFixed(2)}L${(12 + 10.4 * c).toFixed(2)} ${(12 + 10.4 * s).toFixed(2)}`;
        }).join(""),
        width: 1.7,
    },
    // Network's services: a wired port, a phone's shared connection.
    ethernet: { stroke: "M8.2 7.2L3.4 12l4.8 4.8M15.8 7.2l4.8 4.8-4.8 4.8", fill: circle(8.9, 12, 1.25) + circle(12, 12, 1.25) + circle(15.1, 12, 1.25), width: 2 },
    cellular: { fill: rect(3.5, 15, 3, 5.5, 1) + rect(8.5, 11.5, 3, 9, 1) + rect(13.5, 8, 3, 12.5, 1) + rect(18.5, 4, 3, 16.5, 1) },
    battery: { stroke: rect(2.5, 7.5, 17, 9, 2.5) + "M21.5 10.5v3", fill: rect(4.6, 9.6, 10.5, 4.8, 1), width: 1.8 },
    energy: { fill: "M13.5 2L5 13.6h6.2L10 22l8.5-11.6h-6.2z" },
    general: { fill: gear(12, 12, 9.5, 7.2, 10, 3.2) },
    accessibility: {
        stroke: circle(12, 12, 9) + "M7.3 10l4.7 1.1 4.7-1.1M12 11.1v3.3M12 14.4l-2.6 4.3M12 14.4l2.6 4.3",
        fill: circle(12, 7.2, 1.6),
        width: 1.8,
    },
    appearance: { stroke: circle(12, 12, 8.5), fill: "M12 3.5v17a8.5 8.5 0 0 0 0-17z", width: 2 },
    dock: { stroke: rect(3, 4.5, 18, 15, 3), fill: rect(6, 14.5, 12, 2.6, 1.3), width: 1.8 },
    displays: {
        stroke: circle(12, 12, 3.6) +
            "M12 2.8v2.2M12 19v2.2M2.8 12H5M19 12h2.2M5.5 5.5l1.5 1.5M17 17l1.5 1.5M5.5 18.5L7 17M17 7l1.5-1.5",
        fill: circle(12, 12, 3.6),
        width: 2,
    },
    menubar: {
        stroke: rect(3, 4.5, 18, 6.5, 3.25) + rect(3, 13, 18, 6.5, 3.25),
        fill: circle(16.5, 7.75, 1.9) + circle(7.5, 16.25, 1.9),
        width: 1.8,
    },
    spotlight: { stroke: circle(10.5, 10.5, 6) + "M15 15l5 5", width: 2.4 },
    wallpaper: { fill: flower(12, 12) },
    notifications: { stroke: rect(3.5, 6, 14.5, 14.5, 3.5), fill: circle(18.2, 5.8, 3.1), width: 2 },
    // Play, in a ring (Sound's alert preview).
    play: { stroke: "M12 2.6a9.4 9.4 0 1 1 0 18.8a9.4 9.4 0 1 1 0-18.8z", width: 1.4, fill: "M10 8.2v7.6l6.2-3.8z" },
    // The ends of a volume slider: drawn at 13 and 17 points, each a point
    // low of the track's middle, as System Settings has them.
    volumeLow: { fill: speakerAt(24 / 13, 7.5 * 24 / 13) },
    volumeHigh: { fill: speakerAt(24 / 17, 9.5 * 24 / 17), stroke: wavesAt(24 / 17, 9.5 * 24 / 17), width: 24 / 17 },
    sound: {
        fill: "M3.5 9.2h3.8L12 5v14l-4.7-4.2H3.5z",
        stroke: "M15.3 8.8a4.5 4.5 0 0 1 0 6.4M18 6.2a8.2 8.2 0 0 1 0 11.6",
        width: 1.9,
    },
    // A microphone with its level beside it, all four dots lit at the loud
    // end, one at the quiet end (Sound's input volume).
    mic: {
        stroke: "M9 9.3v2.6a6.6 6.6 0 0 0 13.2 0V9.3M15.6 18.5v4.1M10.3 22.6h11",
        fill: rect(11.95, 0.7, 7.3, 15.4, 3.65) + circle(2.6, 5, 1.7) + circle(2.6, 10.5, 1.7) +
            circle(2.6, 16.1, 1.7) + circle(2.6, 21.8, 1.7),
        width: 1.7,
    },
    micQuiet: {
        stroke: "M9 9.3v2.6a6.6 6.6 0 0 0 13.2 0V9.3M15.6 18.5v4.1M10.3 22.6h11",
        fill: rect(11.95, 0.7, 7.3, 15.4, 3.65) + circle(2.6, 21.8, 1.7),
        dim: circle(2.6, 5, 1.7) + circle(2.6, 10.5, 1.7) + circle(2.6, 16.1, 1.7),
        width: 1.7,
    },
    // Wi-Fi's: a lock for a network with a password; its signal, lit to
    // as many bars as it has (the rest dim); the ⋯ in a ring that opens a
    // network's menu; the check by the one in use.
    lock: { stroke: "M6.82 11V6.7a5.18 5.18 0 0 1 10.36 0V11", fill: rect(3.7, 9.84, 16.6, 13.66, 2.6), width: 2.2 },
    signal3: { stroke: wifiArcs(3), fill: wifiWedge(), width: 3.2 },
    signal2: { stroke: wifiArcs(2), dimStroke: wifiArcs(-1), fill: wifiWedge(), width: 3.2 },
    signal1: { dimStroke: wifiArcs(-2), fill: wifiWedge(), width: 3.2 },
    info: { stroke: circle(12, 12, 10.9), fill: circle(12, 7.3, 1.45) + rect(10.95, 10.2, 2.1, 8.2, 1.05), width: 1.41 },
    more: { stroke: circle(12, 12, 10.9), fill: circle(7.4, 12, 1.5) + circle(12, 12, 1.5) + circle(16.6, 12, 1.5), width: 1.41 },
    tick: { stroke: "M6.1 12.6l3.45 4.95L17.9 6.45", width: 2.4 },
    // Bluetooth's: a device, by what it says it is.
    headphones: { stroke: "M4.8 15V12a7.2 7.2 0 0 1 14.4 0v3", fill: rect(3.2, 13.6, 4.4, 7.4, 1.8) + rect(16.4, 13.6, 4.4, 7.4, 1.8), width: 1.5 },
    speaker: { stroke: rect(6.3, 2.5, 11.4, 19, 2.6) + circle(12, 14.9, 3.3), fill: circle(12, 7.4, 1.4), width: 1.4 },
    gamepad: {
        stroke: "M7.2 7.6h9.6a4.4 4.4 0 0 1 4.3 3.5l1 5.3a2.5 2.5 0 0 1-4.4 2l-2-2.5H8.3l-2 2.5a2.5 2.5 0 0 1-4.4-2l1-5.3a4.4 4.4 0 0 1 4.3-3.5zM7.6 10.3v3.4M5.9 12h3.4",
        fill: circle(15.8, 11, 1) + circle(17.9, 13, 1),
        width: 1.4,
    },
    keyboard: {
        stroke: rect(2, 6.5, 20, 11, 2.2),
        // Five keys, four under them, and the space bar.
        fill: [0, 1, 2, 3, 4].map(i => rect(4.6 + i * 3.2, 9, 1.8, 1.7, 0.4)).join("") +
            [0, 1, 2, 3].map(i => rect(6.2 + i * 3.2, 11.6, 1.8, 1.7, 0.4)).join("") + rect(7.4, 14.2, 9.2, 1.7, 0.6),
        width: 1.4,
    },
    mouse: { stroke: "M12 2.8a5.6 5.6 0 0 1 5.6 5.6v7.2a5.6 5.6 0 0 1-11.2 0V8.4A5.6 5.6 0 0 1 12 2.8zM12 6.2v2.6", width: 1.5 },
    phone: { stroke: rect(6.6, 2, 10.8, 20, 2.6), fill: rect(10, 3.7, 4, 1.3, 0.65), width: 1.4 },
    computer: { stroke: rect(4.4, 5, 15.2, 10.6, 1.6) + "M1.8 18.6h20.4", width: 1.5 },
    watch: { stroke: rect(6.6, 6.2, 10.8, 11.6, 3) + "M9 6.2l.6-3.6h4.8L15 6.2M9 17.8l.6 3.6h4.8l.6-3.6", width: 1.4 },
    device: { stroke: rect(6.6, 2.5, 10.8, 19, 2.6) + "M9.6 9.4l4.8 4.3-2.4 2.1V7.6l2.4 2.1-4.8 4.3", width: 1.3 },
    focus: { fill: "M19.5 14.5A8 8 0 0 1 9.5 4.5a8 8 0 1 0 10 10z" },
    lockscreen: { stroke: "M8 10.5V8a4 4 0 0 1 8 0v2.5", fill: rect(5, 10.5, 14, 10, 2.5), width: 2.2 },
    privacy: {
        fill: rect(6.6, 6.2, 2.6, 9, 1.3) + rect(9.6, 3.6, 2.6, 10, 1.3) + rect(12.6, 4.2, 2.6, 10, 1.3) +
            rect(15.6, 6.4, 2.6, 9, 1.3) +
            "M6.6 12.5H18.2V15A6.8 6.8 0 0 1 11.4 21.8H11.2A6 6 0 0 1 6.6 19.6L3.4 15.6A1.5 1.5 0 0 1 5.6 13.6L6.6 14.6Z",
    },
    password: { stroke: circle(8, 12, 3.8) + "M11.8 12h8.7M17.6 12v3M20.5 12v2.4", width: 2.2 },
    users: {
        fill: circle(15.8, 7.6, 2.7) + "M11.8 19.5A4.6 4.6 0 0 1 20.8 18.3V19.5Z" +
            circle(9, 8.4, 3.2) + "M3 20.5A6 6 0 0 1 15 20.5Z",
    },
    keyboard: {
        stroke: rect(2.5, 6, 19, 12, 2.5),
        fill: rect(5, 8.6, 2, 2, 0.5) + rect(8.2, 8.6, 2, 2, 0.5) + rect(11.4, 8.6, 2, 2, 0.5) + rect(14.6, 8.6, 2, 2, 0.5) +
            rect(17.4, 8.6, 1.8, 2, 0.5) + rect(6.6, 11.6, 2, 2, 0.5) + rect(9.8, 11.6, 2, 2, 0.5) + rect(13, 11.6, 2, 2, 0.5) +
            rect(16.2, 11.6, 2, 2, 0.5) + rect(7.5, 14.6, 9, 1.6, 0.8),
        width: 1.8,
    },
    mouse: { stroke: rect(7, 3.5, 10, 17, 5) + "M12 7v3", width: 1.9 },
    trackpad: { stroke: rect(4, 5, 16, 14, 2.5) + "M4 14.5h16M12 14.5V19", width: 1.8 },
    printer: { stroke: "M7 9V4h10v5M7 14.5h10V20H7z" + rect(3.5, 9, 17, 8, 2), width: 1.8 },

    // General's pages
    desktop: { stroke: rect(3, 4, 18, 12.5, 2) + "M9 20.5h6M12 16.5v4", width: 1.9 },
    laptop: { stroke: rect(5, 5, 14, 10, 1.5) + "M2.5 18.5h19", width: 1.9 },
    update: {
        stroke: "M18.6 13.4A6.8 6.8 0 0 1 6.3 16.1M5.4 10.6A6.8 6.8 0 0 1 17.7 7.9M17.9 4.3v3.8h-3.8M6.1 19.7v-3.8h3.8",
        width: 2,
    },
    storage: { stroke: rect(2.8, 8.5, 18.4, 9.5, 2.8) + "M6.5 14.6h4", fill: circle(17, 14.6, 1.1), width: 1.8 },
    datetime: { stroke: circle(12, 12, 8.5) + "M12 7v5.2l3.4 2.1", width: 1.9 },
    language: {
        stroke: circle(12, 12, 8.5) +
            "M3.5 12h17M12 3.5c2.4 2.5 3.5 5.5 3.5 8.5s-1.1 6-3.5 8.5c-2.4-2.5-3.5-5.5-3.5-8.5s1.1-6 3.5-8.5z",
        width: 1.8,
    },
    loginitems: {
        stroke: "M9.5 7h10M9.5 12h10M9.5 17h10",
        fill: circle(5.5, 7, 1.4) + circle(5.5, 12, 1.4) + circle(5.5, 17, 1.4),
        width: 2,
    },
};
