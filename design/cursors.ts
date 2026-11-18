// The pointer: every shape it takes, drawn here once. tools/gen turns these
// into the "Ambrosia" cursor theme (Xcursor files for X11 and Wayland clients,
// SVGs for KWin) and into the preview's CSS cursors.
//
// A Mac's pointer is a black arrow with a white rim and a soft shadow; the
// shapes that stand in for it (resize arrows, the I-beam, the crosshair) are
// black with the same rim, and the hands are white with a black one. Ours
// follow that, drawn by hand: no shape here is traced from Apple's.
//
// Everything is in units on a 32-unit canvas, which is the image at the
// nominal size of 24 (the size themes are named by; the image is a third
// larger to leave room for the shadow). At that size a unit is a pixel.

export const canvas = 32;
export const nominal = 24;
/** The Xcursor sizes shipped. Settings' pointer size goes in twelves from 24
 *  to 72; a 2x screen asks for twice the size. KWin itself draws the SVGs. */
export const sizes = [24, 36, 48, 60, 72, 96] as const;

export const ink = "#000000";
export const paper = "#ffffff";
/** How far a rim reaches past its shape. */
const RIM = 1;
const HAND_RIM = 0.9;

/** The shadow under every pointer: the whole silhouette, blurred. */
export const shadow = { dy: 1, blur: 1.1, opacity: 0.4 };

/** The token colors the pointer borrows, by name: the plus on a copy is the
 *  palette's green, and the wheel's wedges are the accents. The generator
 *  resolves them (light mode: a pointer doesn't change with the theme). */
export const borrowed = {
  copy: "green",
  wheel: ["red", "orange", "honey", "green", "blue", "purple", "pink"],
} as const;
export type Colors = { copy: string; wheel: string[] };

/** A group is painted as one shape: every part's rim first, then every
 *  part's ink, so parts that overlap join without a seam. */
export type Group = {
  ink: string;
  rim: string;
  rimWidth: number;
  /** Closed paths, filled. */
  fills?: string[];
  /** Centerlines, stroked with round caps. */
  lines?: { d: string; width: number }[];
  /** SVG painted over the group: glyphs on a badge, the wheel's colors. */
  over?: string;
};

export type Cursor = {
  hot: [number, number];
  /** One list of groups for a still pointer; several for a moving one. */
  frames: Group[][];
  /** Milliseconds a frame stays up, for a moving pointer. */
  delay?: number;
  /** The other names clients ask for this shape by. */
  aliases: string[];
};

// Geometry ---------------------------------------------------------------------------

type P = [number, number];
const n = (v: number) => +v.toFixed(3);
const poly = (points: P[]) => `M${points.map(([x, y]) => `${n(x)} ${n(y)}`).join("L")}Z`;
const turn = (points: P[], degrees: number, [cx, cy]: P = [16, 16]): P[] => {
  const a = (degrees * Math.PI) / 180;
  return points.map(([x, y]) => [
    cx + (x - cx) * Math.cos(a) - (y - cy) * Math.sin(a),
    cy + (x - cx) * Math.sin(a) + (y - cy) * Math.cos(a),
  ]);
};
const shift = (points: P[], dx: number, dy: number): P[] => points.map(([x, y]) => [x + dx, y + dy]);
const disc = (cx: number, cy: number, r: number) =>
  `M${n(cx - r)} ${n(cy)}A${r} ${r} 0 1 0 ${n(cx + r)} ${n(cy)}A${r} ${r} 0 1 0 ${n(cx - r)} ${n(cy)}Z`;
/** A finger: a line from a to b, r thick each side, round at both ends. */
const capsule = ([ax, ay]: P, [bx, by]: P, r: number) => {
  const len = Math.hypot(bx - ax, by - ay);
  const [nx, ny] = [(-(by - ay) / len) * r, ((bx - ax) / len) * r];
  return (
    `M${n(ax + nx)} ${n(ay + ny)}L${n(bx + nx)} ${n(by + ny)}A${r} ${r} 0 0 0 ${n(bx - nx)} ${n(by - ny)}` +
    `L${n(ax - nx)} ${n(ay - ny)}A${r} ${r} 0 0 0 ${n(ax + nx)} ${n(ay + ny)}Z`
  );
};

// The arrow ----------------------------------------------------------------------------

/** Where the arrow's tip sits on the canvas; its hotspot. */
const TIP: P = [6, 4];
/** The arrow from its tip: straight down the left side, the notch, the tail
 *  leaning right, then the wing and back up the long edge. */
const arrowShape: P[] = [
  [0, 0], [0, 16.5], [3.7, 13], [6.1, 18.7], [8.6, 17.6], [6.2, 12], [11.6, 12],
];
const arrow: Group = { ink, rim: paper, rimWidth: RIM, fills: [poly(shift(arrowShape, ...TIP))] };

/** Where a badge sits beside the arrow, and how big it is. */
const BADGE: P = [20.5, 22.5];
const BADGE_R = 4.7;
const badge = (fill: string, rim: string, over: string): Group => ({
  ink: fill, rim, rimWidth: 0.8, fills: [disc(...BADGE, BADGE_R)], over,
});
const stroke = (d: string, color: string, width: number) =>
  `<path d="${d}" fill="none" stroke="${color}" stroke-width="${width}" stroke-linecap="round" stroke-linejoin="round"/>`;
const [bx, by] = BADGE;

const gray = "#48484a";

// Arrows that resize -------------------------------------------------------------------

/** A two-headed arrow lying flat through the middle of the canvas. */
const twoHeaded: P[] = [
  [7, 16], [11.6, 12.3], [11.6, 15.15], [20.4, 15.15], [20.4, 12.3], [25, 16],
  [20.4, 19.7], [20.4, 16.85], [11.6, 16.85], [11.6, 19.7],
];
/** The same with a bar across its middle: what moves a divider. */
const divider: P[] = [
  [6, 16], [10.2, 12.5], [10.2, 15.15], [15.2, 15.15], [15.2, 8], [16.8, 8], [16.8, 15.15], [21.8, 15.15],
  [21.8, 12.5], [26, 16], [21.8, 19.5], [21.8, 16.85], [16.8, 16.85], [16.8, 24], [15.2, 24], [15.2, 16.85],
  [10.2, 16.85], [10.2, 19.5],
];
/** One head and its half of the shaft, for the four-way arrow. */
const fourWayArm: P[] = [[16, 5.5], [19.5, 9.7], [16.85, 9.7], [16.85, 16], [15.15, 16], [15.15, 9.7], [12.5, 9.7]];
const black = (points: P[][]): Group => ({ ink, rim: paper, rimWidth: RIM, fills: points.map(poly) });

// Lines ---------------------------------------------------------------------------------

const lines = (width: number, ...d: string[]): Group => ({
  ink, rim: paper, rimWidth: 0.75, lines: d.map((path) => ({ d: path, width })),
});
/** The I-beam: a stem, a serif curling out at each end, and the small bar
 *  that marks the baseline. */
const beam = [
  "M16 8.4V23.6",
  "M13 6.6C14.6 6.6 16 7.1 16 8.8C16 7.1 17.4 6.6 19 6.6",
  "M13 25.4C14.6 25.4 16 24.9 16 23.2C16 24.9 17.4 25.4 19 25.4",
  "M14.6 18.2H17.4",
];
/** The same on its side, for text set top to bottom. */
const beamFlat = [
  "M8.4 16H23.6",
  "M6.6 13C6.6 14.6 7.1 16 8.8 16C7.1 16 6.6 17.4 6.6 19",
  "M25.4 13C25.4 14.6 24.9 16 23.2 16C24.9 16 25.4 17.4 25.4 19",
  "M18.2 14.6V17.4",
];

// Hands ---------------------------------------------------------------------------------

const hand = (parts: string[]): Group => ({ ink: paper, rim: ink, rimWidth: HAND_RIM, fills: parts });
const FINGER = 1.45;
/** The palm under the pointing hand and the fist: knuckles to wrist. */
const palm = "M11.85 15.5V19.6C11.85 22 13.4 23.4 14.2 24.8V26.3H22.9V24.8C23.7 23.4 25.05 21.4 25.05 19V15.5Z";
const pointing = hand([
  capsule([13.3, 16.5], [13.3, 6.1], FINGER),
  capsule([16.7, 16.5], [16.7, 11.5], FINGER),
  capsule([20.1, 16.5], [20.1, 12.3], FINGER),
  capsule([23.6, 16.5], [23.6, 13.4], FINGER),
  capsule([12.6, 20.6], [9.2, 16.6], 1.55),
  palm,
]);
const open = hand([
  capsule([13.3, 16.5], [12.5, 8], FINGER),
  capsule([16.7, 16.5], [16.5, 6.4], FINGER),
  capsule([20.1, 16.5], [20.5, 7.3], FINGER),
  capsule([23.5, 17], [24.5, 10], 1.35),
  capsule([12.6, 21], [8.6, 16], 1.55),
  palm,
]);
const fist = hand([
  capsule([13.3, 16.5], [13.3, 12.4], FINGER),
  capsule([16.7, 16.5], [16.7, 11.6], FINGER),
  capsule([20.1, 16.5], [20.1, 12], FINGER),
  capsule([23.6, 16.5], [23.6, 13.1], FINGER),
  capsule([12.4, 19.6], [10.8, 16.4], 1.55),
  palm,
]);

// The wheel -----------------------------------------------------------------------------

/** The busy pointer: a wheel in the accents' colors, turning once a second.
 *  A Mac shows a wheel of its own here; this one is ours. */
const WHEEL_FRAMES = 30;
const wheel = (wheelColors: string[], cx: number, cy: number, r: number, turned: number): Group => {
  const step = 360 / wheelColors.length;
  // Each wedge runs from the hub to the rim between two curved spokes.
  const spoke = (degrees: number): { rim: P; bend: P } => ({
    rim: turn([[cx, cy - r]], degrees, [cx, cy])[0]!,
    bend: turn([[cx, cy - r * 0.55]], degrees - 24, [cx, cy])[0]!,
  });
  const wedges = wheelColors.map((color, i) => {
    const a = spoke(turned + i * step);
    const b = spoke(turned + (i + 1) * step);
    return (
      `<path d="M${n(cx)} ${n(cy)}Q${n(a.bend[0])} ${n(a.bend[1])} ${n(a.rim[0])} ${n(a.rim[1])}` +
      `A${r} ${r} 0 0 1 ${n(b.rim[0])} ${n(b.rim[1])}Q${n(b.bend[0])} ${n(b.bend[1])} ${n(cx)} ${n(cy)}Z" fill="${color}"/>`
    );
  });
  // A little light from above and a darker edge, so it reads as a bead of
  // glass rather than a sticker.
  const gloss =
    `<defs><radialGradient id="gloss" gradientUnits="userSpaceOnUse" cx="${n(cx)}" cy="${n(cy - r * 0.5)}" r="${n(r * 0.95)}">` +
    `<stop offset="0" stop-color="${paper}" stop-opacity="0.5"/><stop offset="1" stop-color="${paper}" stop-opacity="0"/></radialGradient></defs>` +
    `<path d="${disc(cx, cy, r)}" fill="url(#gloss)"/>` +
    `<path d="${disc(cx, cy, r - 0.2)}" fill="none" stroke="${ink}" stroke-opacity="0.14" stroke-width="0.4"/>`;
  return { ink: wheelColors[0]!, rim: paper, rimWidth: RIM, fills: [disc(cx, cy, r)], over: wedges.join("") + gloss };
};
const turning = (colors: string[], cx: number, cy: number, r: number, under: Group[] = []) =>
  Array.from({ length: WHEEL_FRAMES }, (_, i) => [...under, wheel(colors, cx, cy, r, (360 / WHEEL_FRAMES) * i)]);

// The pointers --------------------------------------------------------------------------

const still = (hot: P, groups: Group[], aliases: string[] = []): Cursor => ({ hot, frames: [groups], aliases });

export const pointers = (colors: Colors): Record<string, Cursor> => ({
  default: still(TIP, [arrow], ["left_ptr", "arrow", "top_left_arrow", "dnd-move", "dnd-none", "dnd-ask"]),
  pointer: still([13.3, 4.7], [pointing], [
    "pointing_hand", "hand1", "hand2", "9d800788f1b08800ae810202380a0822", "e29285e634086352946a0e7090d73106",
  ]),
  text: still([16, 16], [lines(1, ...beam)], ["xterm", "ibeam"]),
  "vertical-text": still([16, 16], [lines(1, ...beamFlat)], ["048008013003cff3c00c801001200000"]),
  crosshair: still([16, 16], [lines(1, "M16 5V27", "M5 16H27")], ["cross", "tcross", "cross_reverse"]),
  cell: still([16, 16], [{
    ink: paper, rim: ink, rimWidth: HAND_RIM,
    fills: [poly([[14, 7], [18, 7], [18, 25], [14, 25]]), poly([[7, 14], [25, 14], [25, 18], [7, 18]])],
  }], ["plus"]),

  grab: still([16.5, 16], [open], ["openhand", "5aca4d189052212118709018842178c0", "9141b49c8149039304290b508d208c40"]),
  grabbing: still([16.5, 16], [fist], [
    "closedhand", "fcf21c00b30f7e3f83fe0dfd12e71cff", "208530c400c041818281048008011002",
  ]),

  copy: still(TIP, [arrow, badge(colors.copy, paper, stroke(`M${bx - 2.4} ${by}H${bx + 2.4}M${bx} ${by - 2.4}V${by + 2.4}`, paper, 1.3))], [
    "dnd-copy", "1081e37283d90000800003c07f3ef6bf", "6407b0e94181790501fd1e167b474872", "b66166c04f8c3109214a4fbd64a50fc8",
  ]),
  alias: still(TIP, [arrow, badge(paper, gray, stroke(
    `M${bx - 2.2} ${by + 2.3}C${bx - 2.2} ${by - 0.4} ${bx - 0.6} ${by - 1.2} ${bx + 2.3} ${by - 1.2}M${bx + 0.6} ${by - 3}L${bx + 2.4} ${by - 1.2}L${bx + 0.6} ${by + 0.6}`,
    ink, 1.1,
  ))], [
    "link", "dnd-link", "3085a0e285430894940527032f8b26df", "640fb0e74195791501fd1ed57b41487f", "a2a266d0498c3104214a47bd64ab0fc8",
  ]),
  "not-allowed": still(TIP, [arrow, badge(gray, paper,
    `<path d="${disc(bx, by, BADGE_R - 1.3)}" fill="${paper}"/>` +
    stroke(`M${n(bx - 2.5)} ${n(by - 2.5)}L${n(bx + 2.5)} ${n(by + 2.5)}`, gray, 1.3),
  )], [
    "no-drop", "dnd-no-drop", "forbidden", "crossed_circle", "circle", "03b6e0fcb3499374a867c041f52298f0",
  ]),
  "context-menu": still(TIP, [arrow, {
    ink: paper, rim: gray, rimWidth: 0.8,
    fills: [`M17 18.4H24.4Q25 18.4 25 19V26.4Q25 27 24.4 27H17Q16.4 27 16.4 26.4V19Q16.4 18.4 17 18.4Z`],
    over: stroke("M18.3 20.7H23.1M18.3 22.7H23.1M18.3 24.7H23.1", gray, 0.9),
  }]),
  help: still(TIP, [arrow, badge(paper, gray,
    stroke(`M${bx - 1.7} ${by - 1.3}A1.75 1.75 0 1 1 ${bx + 0.9} ${by + 0.1}C${bx + 0.2} ${by + 0.5} ${bx} ${by + 0.8} ${bx} ${by + 1.4}`, ink, 1.1) +
    `<circle cx="${bx}" cy="${by + 3}" r="0.7" fill="${ink}"/>`,
  )], ["question_arrow", "whats_this", "left_ptr_help", "d9ce0ab605698f320427677b458ad60b", "5c6cd98b3f3ebcb1f9c7f1c204630408"]),

  "ew-resize": still([16, 16], [black([twoHeaded])], [
    "size_hor", "h_double_arrow", "sb_h_double_arrow", "e-resize", "w-resize", "left_side", "right_side",
    "028006030e0e7ebffc7f7070c0600140",
  ]),
  "ns-resize": still([16, 16], [black([turn(twoHeaded, 90)])], [
    "size_ver", "v_double_arrow", "sb_v_double_arrow", "n-resize", "s-resize", "top_side", "bottom_side",
    "00008160000006810000408080010102",
  ]),
  "nwse-resize": still([16, 16], [black([turn(twoHeaded, 45)])], [
    "size_fdiag", "nw-resize", "se-resize", "top_left_corner", "bottom_right_corner", "c7088f0f3e6c8088236ef8e1e3e70000",
  ]),
  "nesw-resize": still([16, 16], [black([turn(twoHeaded, -45)])], [
    "size_bdiag", "ne-resize", "sw-resize", "top_right_corner", "bottom_left_corner", "fcf1c3c7cd4491d801f1e1c78f100000",
  ]),
  "col-resize": still([16, 16], [black([divider])], ["split_h", "14fef782d02440884392942c11205230"]),
  "row-resize": still([16, 16], [black([turn(divider, 90)])], ["split_v", "2870a09082c103050810ffdffffe0204"]),
  move: still([16, 16], [black([0, 90, 180, 270].map((a) => turn(fourWayArm, a)))], [
    "all-scroll", "fleur", "size_all", "4498f0e0c1937ffe01fd06f973665830", "9081237383d90e509aa00f00170e968f",
  ]),

  "zoom-in": still([14, 14], [
    { ink, rim: paper, rimWidth: 0.8, lines: [{ d: "M19.2 19.2L25.2 25.2", width: 2.6 }], fills: [disc(14, 14, 7.2)] },
    { ink: paper, rim: paper, rimWidth: 0, fills: [disc(14, 14, 5.6)], over: stroke("M11 14H17M14 11V17", ink, 1.4) },
  ], ["f41c0e382c94c0958e07017e42b00462"]),
  "zoom-out": still([14, 14], [
    { ink, rim: paper, rimWidth: 0.8, lines: [{ d: "M19.2 19.2L25.2 25.2", width: 2.6 }], fills: [disc(14, 14, 7.2)] },
    { ink: paper, rim: paper, rimWidth: 0, fills: [disc(14, 14, 5.6)], over: stroke("M11 14H17", ink, 1.4) },
  ], ["f41c0e382c97c0938e07017e42800402"]),

  wait: { hot: [16, 16], frames: turning(colors.wheel, 16, 16, 7.5), delay: 33, aliases: ["watch", "clock"] },
  progress: {
    hot: TIP, frames: turning(colors.wheel, ...BADGE, BADGE_R, [arrow]), delay: 33,
    aliases: [
      "left_ptr_watch", "half-busy", "00000000000000020006000e7e9ffc3f", "08e8e1c95fe2fc01f976f1e063a24ccd",
      "3ecb610c1bf2410f44200f48c40d3599",
    ],
  },
});
