.pragma library
// Disk Utility's glyphs, drawn by hand on the shell's 24-unit grid (see
// shell/icons.js and settings/qml/glyphs.js): `stroke` is drawn `width`
// units wide (1.5 by default) with round caps, `fill` solid. Our own
// shapes; nothing is taken from Apple's.

function circle(cx, cy, r) {
    return `M${cx - r} ${cy}a${r} ${r} 0 1 0 ${2 * r} 0a${r} ${r} 0 1 0 ${-2 * r} 0z`;
}
function rect(x, y, w, h, r) {
    return `M${x + r} ${y}h${w - 2 * r}a${r} ${r} 0 0 1 ${r} ${r}v${h - 2 * r}a${r} ${r} 0 0 1 ${-r} ${r}h${-(w - 2 * r)}a${r} ${r} 0 0 1 ${-r} ${-r}v${-(h - 2 * r)}a${r} ${r} 0 0 1 ${r} ${-r}z`;
}

var glyphs = {
    // A window with its sidebar marked off (Preview's).
    sidebar: { stroke: rect(2.5, 4.5, 19, 15, 3.4) + "M9.2 4.5v15M5.2 8.6h1.6M5.2 11.4h1.6" },
    chevronRight: { stroke: "M9.5 6.5L15 12l-5.5 5.5", width: 2.2 },
    chevronDown: { stroke: "M6.5 9.5l5.5 5.5 5.5-5.5", width: 2.2 },
    check: { stroke: "M5.5 12.5l4.2 4.2L18.5 7.5", width: 2.2 },
    // A drive inside the computer: a flat box, its light at the right of a
    // strip along its foot.
    driveInternal: { stroke: rect(2.5, 6.5, 19, 11, 3) + "M2.5 13.2h19", fill: circle(18, 15.4, 0.95) },
    // One plugged in: the same box, taller in front, a slot under its top.
    driveExternal: { stroke: "M5.6 6h12.8a2 2 0 0 1 1.9 1.4l1.6 5.4v3.2a2 2 0 0 1-2 2H4.1a2 2 0 0 1-2-2v-3.2l1.6-5.4A2 2 0 0 1 5.6 6zM2.3 12.8h19.4", fill: circle(18, 15.4, 0.95) },
    // A volume: a drive seen from the front, lines of its grille.
    volume: { stroke: "M5.6 6.5h12.8a2 2 0 0 1 1.9 1.4l1.4 4.6v3a2 2 0 0 1-2 2H4.3a2 2 0 0 1-2-2v-3l1.4-4.6a2 2 0 0 1 1.9-1.4zM2.5 12.4h19M6.5 15h.01M9 15h.01M11.5 15h.01", fill: circle(17.8, 15, 0.9), width: 1.4 },
    // One that is locked: the same under a padlock.
    volumeLocked: { stroke: "M5.6 9.5h12.8a2 2 0 0 1 1.9 1.3l1.2 3.6v3.1a2 2 0 0 1-2 2H4.5a2 2 0 0 1-2-2v-3.1l1.2-3.6a2 2 0 0 1 1.9-1.3zM2.7 14.6h18.6M10 9.2V6.6a2 2 0 0 1 4 0v2.6", width: 1.4 },
    // Out with it: a bar under a triangle.
    eject: { fill: "M12 5.2l7 8.6H5zM5 16.2h14v2.6H5z" },
    // First Aid: a stethoscope, its two ear tubes meeting in a loop that
    // runs round to the chest piece.
    firstAid: { stroke: "M6 3.8v5.4a4.2 4.2 0 0 0 8.4 0V3.8M10.2 13.4v2.4a4 4 0 0 0 8 0v-1.2" + circle(18.2, 12.2, 2.3), fill: circle(6, 3.8, 0.9) + circle(14.4, 3.8, 0.9), width: 1.6 },
    // Erase: a drive with a cross on a disc at its corner.
    erase: { stroke: "M7.4 6.5h11a2 2 0 0 1 1.9 1.4l1.2 4.4v2.9a2 2 0 0 1-2 2h-6.2M11.2 12.3h10.3" + circle(6.6, 15.2, 4.4) + "M5 13.6l3.2 3.2M8.2 13.6L5 16.8", fill: circle(18.4, 14.8, 0.9), width: 1.4 },
    // Unmount and mount: a drive's top with an arrow off it, or onto it.
    unmount: { stroke: "M3.5 14.6h17M5.4 18.6h13.2M12 11V3.4M8.6 6.6L12 3.2l3.4 3.4", width: 1.6 },
    mount: { stroke: "M3.5 14.6h17M5.4 18.6h13.2M12 3.4V11M8.6 7.6L12 11l3.4-3.4", width: 1.6 },
    // About it: an i in a ring.
    info: { stroke: circle(12, 12, 9) + "M10.6 10.8h1.6v5.6M10 16.4h4.2", fill: circle(11.9, 7.7, 1.15), width: 1.5 },
    // Done, in a ring.
    done: { stroke: circle(12, 12, 9.2) + "M7.8 12.4l2.9 2.9 5.6-6.2", width: 1.7 },
    failed: { stroke: circle(12, 12, 9.2) + "M12 7.2v5.6", fill: circle(12, 16.2, 1.1), width: 1.7 },
};
