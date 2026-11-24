// The single source of truth for how ambrosia looks and moves.
//
// Every theme in dist/ (GTK, KDE, the QML shell, fontconfig, the web preview)
// is generated from this file by tools/gen. Never hand-edit generated output.
// DESIGN.md explains the reasoning behind the numbers.
//
// Colors are OKLCH strings, "oklch(L C H)" or "oklch(L C H / A)", so lightness
// steps are perceptually even. The generator converts and gamut-maps to sRGB.

export type Mode = "light" | "dark";
export type Pair<T> = Record<Mode, T>;
export const modes: Mode[] = ["light", "dark"];

/** Hue of the faint warmth in every neutral: paper, not steel. */
const warm = 85;
const neutral = (l: number, a = 1, c = 0.004) => `oklch(${l} ${c} ${warm} / ${a})`;
const white = (a: number) => `oklch(1 0 0 / ${a})`;

// Typography ----------------------------------------------------------------

export const font = {
  // The variable face first: Qt maps the static Inter.ttc (13 MB, every cut
  // in one file) once per weight, which costs each app about 50–75 MB.
  ui: ["Inter Variable", "Inter"],
  mono: ["JetBrains Mono"],
  fallback: { ui: "sans-serif", mono: "monospace" },
} as const;

export interface TextStyle {
  size: number;
  line: number;
  weight: number;
}

export const type = {
  largeTitle: { size: 26, line: 32, weight: 700 },
  title1: { size: 22, line: 28, weight: 700 },
  title2: { size: 17, line: 22, weight: 600 },
  title3: { size: 15, line: 20, weight: 600 },
  headline: { size: 13, line: 16, weight: 600 },
  body: { size: 13, line: 16, weight: 400 },
  callout: { size: 12, line: 15, weight: 400 },
  caption: { size: 11, line: 14, weight: 400 },
  footnote: { size: 10, line: 13, weight: 500 },
} satisfies Record<string, TextStyle>;

/** Inter's dynamic-metrics tracking curve, in em. */
export const tracking = (size: number) => -0.0223 + 0.185 * Math.exp(-0.1745 * size);

// Space and shape ------------------------------------------------------------

export const space = {
  "0": 0, "0.5": 2, "1": 4, "1.5": 6, "2": 8, "3": 12, "4": 16,
  "5": 20, "6": 24, "8": 32, "10": 40, "12": 48, "16": 64,
} as const;

export const radius = {
  window: 16,
  sheet: 16,
  panel: 22, // notifications, launcher
  card: 12, // panel 22 − padding 10
  module: 30, // control center modules: capsules, half the 60 unit
  controlCenter: 44, // its blur region: module 30 + padding 14
  popover: 12,
  row: 6, // popover 12 − padding 6
  control: 8,
  controlSmall: 6,
  tooltip: 8,
  dock: 28, // icon corner 12 + padding 16
  capsule: 9999,
} as const;

/** App-icon corner as a fraction of the icon's size (superellipse). */
export const iconCorner = 0.225;
/** Concentric radii never go below this. */
export const minRadius = 4;

export const size = {
  menubar: { height: 28, itemPadding: 10, icon: 16 },
  dock: { icon: 52, padding: 16, gap: 16, margin: 6, indicator: 4, badge: 18 },
  controlCenter: { unit: 60, gap: 12, padding: 14, columns: 4, toggle: 36, track: 6 },
  /** What the volume and brightness keys show: a capsule as wide as the
   *  control center's modules, under the menu bar's right end. */
  hud: { width: 276, height: 44, padding: 16, glyph: 18, gap: 12 },
  /** A screenshot just taken, floating in the screen's bottom right corner:
   *  the box the picture is fitted in, how far from the screen's edges, its
   *  white edge and its corners. By eye, not measured yet. */
  screenshot: { width: 180, height: 132, margin: 20, border: 2, radius: 8 },
  /** Icons on the desktop (what is in ~/Desktop): an icon, the cell it and
   *  its two lines of name take, the room kept between the icons and the
   *  screen's edges, a picture's white edge, and the corners of a chosen
   *  icon's backing. By eye from macOS 26's defaults (64 pt icons, 12 pt
   *  names), not measured yet. */
  desktop: { icon: 64, cellWidth: 108, cellHeight: 112, margin: 8, edge: 2, radius: 8 },
  /** A Dock stack opened (Downloads): a grid of the folder's newest things,
   *  so many across and at most so many rows before it scrolls; a cell, the
   *  icon in it, and the panel's own padding. By eye, not measured yet. */
  stack: { columns: 4, rows: 4, cell: 96, icon: 56, padding: 16, newest: 24 },
  /** The emoji picker (⌃⌘Space): so many across and so many rows showing
   *  before it scrolls; a cell and the emoji drawn in it, the row a group's
   *  name gets, the strip of groups along the bottom, the field on top, and
   *  the panel's own padding. `recent` is how many it remembers. By eye
   *  from macOS 26, not measured yet. */
  emoji: { columns: 8, rows: 6, cell: 40, glyph: 28, heading: 26, bar: 38, field: 28, padding: 10, recent: 24 },
  /** ⌘Tab's strip of apps: an icon, the room round it its highlight takes
   *  (`pad`), the strip's own margin, the row the chosen app's name gets,
   *  and how small icons may get when there are many. By eye from macOS 26,
   *  not measured yet. */
  switcher: { icon: 104, pad: 10, margin: 14, label: 26, minimum: 40 },
  /** Mission Control: the spaces bar while it shows names only (`bar`), a
   *  space's picture once it is opened (`space`, its height) and the room
   *  round it, the ring round the window the pointer is on, and the capsule
   *  with a window's name under it (`label`, `gap` below the window). By eye
   *  from macOS 26, not measured yet. */
  mission: { bar: 40, space: 96, pad: 12, ring: 4, label: 28, gap: 10 },
  /** The picture while the computer starts (Plymouth): the mark in the
   *  middle of a black screen and a thin bar under it, on a screen 1080
   *  high; a taller screen draws them larger by as much. `field` is where a
   *  disk's password goes. By eye from a Mac starting up, not measured. */
  boot: { mark: 96, bar: 192, track: 4, gap: 56, field: 28, dot: 8 },
  // macOS 26: a titled window's bar is 32, a toolbar 52. The controls sit
  // centered in either, as far from the left edge as from the top.
  titlebar: { height: 32, toolbar: 52 },
  windowControls: { diameter: 14, gap: 9 },
  sidebar: { width: 220, row: 28, rowInset: 10 },
  control: { small: 22, regular: 28, large: 36 },
  row: { compact: 24, regular: 28, large: 44 },
  switch: { width: 36, height: 20, knob: 16 },
  focusRing: { width: 3, offset: 1 },
  scrollbar: { thin: 7, hover: 11, inset: 2 },
  hitTarget: 24,
} as const;

/**
 * Controls as macOS 26 draws them, measured on the Mac (Settings carries the
 * same numbers in settings/qml/Look.qml). The Qt widget style (style/) draws
 * every other app's buttons, boxes and menus from these. They are the Mac's
 * own sizes, so like the window controls they needn't sit on the 2px grid.
 */
export const controls = {
  /** A push button: its height, corner, and the room either side of its title. */
  push: { height: 24, radius: 7, padding: 13, minimumDefault: 64 },
  /** A text field, and the box of a combo or a stepper. */
  field: { height: 24, radius: 5, padding: 6 },
  /** A checkbox and a radio button: the box, its corner, the gap to its label. */
  check: { size: 16, radius: 4, gap: 6 },
  /** A slider's track and its knob; a progress bar is a track alone. */
  slider: { track: 6, knobWidth: 20, knobHeight: 16 },
  /** A pop-up button's arrows, and a stepper's. */
  arrows: { width: 20 },
  /** A menu: its corner and inner margin, a row, the highlight's corner and
   *  the room a rule takes. */
  menu: { radius: 8, margin: 5, row: 22, rowRadius: 5, rowPadding: 9, rule: 11, icon: 16, gap: 6, shortcutGap: 24 },
  /** A tool button's hover, and a tooltip. */
  tool: { radius: 6 },
  tooltip: { radius: 6, padding: 6 },
  /** A segmented control, which is what a tab view's tabs are (Settings'
   *  Segmented.qml): its height and corner, the room either side of a title.
   *  A window's own tabs (Qt's document mode) are taller; `close` is the
   *  button on one of those. */
  tab: { height: 24, radius: 6, padding: 12, document: 28, close: 16 },
  /** A box round a group of controls, and a tab view's pane. Settings' boxes
   *  have corners of 10; other apps put lists edge to edge inside theirs, so
   *  8 here. `padding` is what the box adds to the app's own margins,
   *  `title` how far in its heading starts and `titleGap` the room under it. */
  box: { radius: 8, padding: 4, title: 10, titleGap: 6 },
  /** A row of a list, a tree or a table and its highlight's corner (Files'
   *  rowRadius); a table's header (Settings' tableHeader). */
  row: { height: 24, radius: 6, header: 28 },
  /** How much smaller a table's header and a menu's heading are set. */
  caption: 0.85,
  /** Anything disabled is this opaque. */
  disabled: 0.45,
} as const;

/** The control colors the palette has no role for. */
export const controlColor = {
  /** A button's face, and pressed. */
  face: { light: "oklch(0.18 0.006 85 / 0.106)", dark: white(0.075) },
  facePressed: { light: "oklch(0.18 0.006 85 / 0.17)", dark: white(0.15) },
  /** An empty checkbox, a slider's or progress bar's track. */
  track: { light: "oklch(0.18 0.006 85 / 0.125)", dark: white(0.2) },
  /** A text field and its hairline. */
  field: { light: "oklch(1 0 0)", dark: white(0.1) },
  fieldBorder: { light: "oklch(0.18 0.006 85 / 0.16)", dark: white(0.14) },
  /** A slider's knob. */
  knob: { light: "oklch(1 0 0)", dark: "oklch(0.92 0 0)" },
  /** A menu, its rim and its rules; a tooltip takes the same. */
  menu: { light: "oklch(0.96 0 0)", dark: "oklch(0.265 0.004 85)" },
  menuRim: { light: "oklch(0.86 0 0)", dark: "oklch(0.42 0.004 85)" },
  menuRule: { light: "oklch(0.885 0 0)", dark: "oklch(0.36 0.004 85)" },
  /** A scroll bar's thumb, at rest and under the pointer. */
  scroller: { light: "oklch(0.18 0.006 85 / 0.35)", dark: white(0.35) },
  scrollerHover: { light: "oklch(0.18 0.006 85 / 0.55)", dark: white(0.55) },
  /** A box's fill, over the window. */
  box: { light: "oklch(0.18 0.006 85 / 0.035)", dark: white(0.04) },
  /** A chosen row where the keyboard isn't: in a list without the focus, or
   *  a window behind (Files' selectionInactive). */
  rowUnfocused: { light: "oklch(0.893 0 0)", dark: "oklch(0.39 0.008 100)" },
} as const;

// Color ----------------------------------------------------------------------

export interface ModeColors {
  bg: { window: string; content: string; sidebar: string; elevated: string; control: string };
  label: { primary: string; secondary: string; tertiary: string; quaternary: string };
  fill: { primary: string; secondary: string; tertiary: string; quaternary: string };
  separator: string;
  border: string;
  shadow: string;
}

export const color: Pair<ModeColors> = {
  light: {
    bg: {
      window: neutral(0.962, 1, 0.003),
      content: neutral(0.997, 1, 0.002),
      sidebar: neutral(0.94),
      elevated: neutral(0.985, 1, 0.002),
      control: neutral(1, 1, 0),
    },
    label: {
      primary: neutral(0.18, 0.88, 0.006),
      secondary: neutral(0.18, 0.52, 0.006),
      tertiary: neutral(0.18, 0.28, 0.006),
      quaternary: neutral(0.18, 0.12, 0.006),
    },
    fill: {
      primary: neutral(0.18, 0.1, 0.006),
      secondary: neutral(0.18, 0.075, 0.006),
      tertiary: neutral(0.18, 0.05, 0.006),
      quaternary: neutral(0.18, 0.03, 0.006),
    },
    separator: neutral(0.18, 0.1, 0.006),
    border: neutral(0.18, 0.14, 0.006),
    shadow: "oklch(0.16 0.02 60)",
  },
  dark: {
    bg: {
      window: neutral(0.255),
      content: neutral(0.205),
      sidebar: neutral(0.29, 1, 0.005),
      elevated: neutral(0.31, 1, 0.005),
      control: neutral(0.4, 1, 0.005),
    },
    label: {
      primary: white(0.9),
      secondary: white(0.56),
      tertiary: white(0.3),
      quaternary: white(0.14),
    },
    fill: {
      primary: white(0.16),
      secondary: white(0.12),
      tertiary: white(0.08),
      quaternary: white(0.05),
    },
    separator: white(0.12),
    border: white(0.14),
    shadow: "oklch(0.08 0.01 60)",
  },
};

export const palette: Record<string, Pair<string>> = {
  red: { light: "oklch(0.63 0.22 25)", dark: "oklch(0.68 0.21 25)" },
  orange: { light: "oklch(0.72 0.18 52)", dark: "oklch(0.76 0.17 54)" },
  yellow: { light: "oklch(0.84 0.17 88)", dark: "oklch(0.87 0.16 90)" },
  green: { light: "oklch(0.68 0.18 148)", dark: "oklch(0.74 0.18 148)" },
  mint: { light: "oklch(0.78 0.13 175)", dark: "oklch(0.82 0.13 175)" },
  teal: { light: "oklch(0.68 0.11 200)", dark: "oklch(0.74 0.11 200)" },
  cyan: { light: "oklch(0.72 0.13 225)", dark: "oklch(0.78 0.12 225)" },
  blue: { light: "oklch(0.6 0.2 258)", dark: "oklch(0.66 0.19 258)" },
  indigo: { light: "oklch(0.52 0.2 280)", dark: "oklch(0.6 0.19 280)" },
  purple: { light: "oklch(0.58 0.2 305)", dark: "oklch(0.65 0.19 305)" },
  pink: { light: "oklch(0.63 0.22 5)", dark: "oklch(0.69 0.21 5)" },
  brown: { light: "oklch(0.6 0.06 65)", dark: "oklch(0.66 0.06 65)" },
  gray: { light: "oklch(0.6 0.01 85)", dark: "oklch(0.66 0.01 85)" },
};

/** Status roles, as names in `palette`. */
export const status = { destructive: "red", error: "red", warning: "orange", success: "green" } as const;

/** User-selectable accents. Everything else about each accent is derived. */
export const accent = {
  default: "blue",
  options: {
    blue: { light: "oklch(0.6 0.19 255)", dark: "oklch(0.66 0.18 255)" },
    purple: { light: "oklch(0.56 0.2 300)", dark: "oklch(0.64 0.19 300)" },
    pink: { light: "oklch(0.62 0.21 355)", dark: "oklch(0.68 0.2 355)" },
    red: { light: "oklch(0.6 0.21 25)", dark: "oklch(0.66 0.2 25)" },
    orange: { light: "oklch(0.7 0.18 50)", dark: "oklch(0.74 0.17 52)" },
    honey: { light: "oklch(0.8 0.15 80)", dark: "oklch(0.82 0.14 80)" },
    green: { light: "oklch(0.64 0.17 148)", dark: "oklch(0.7 0.17 148)" },
    graphite: { light: "oklch(0.55 0.01 85)", dark: "oklch(0.68 0.01 85)" },
  } as Record<string, Pair<string>>,
  /** Minimum contrast for white text on the accent before falling back to ink. */
  fgContrast: 3,
  /** Minimum contrast for accent-colored text on `bg.content`. */
  textContrast: 4.5,
  /** Opacity of the accent behind selected text. */
  highlight: 0.28,
};

/** Close, minimize and zoom: macOS 26's own, measured in both modes (Terminal,
 *  2026-10-28), which are the same. Inactive windows show them in
 *  `fill.primary` on the window. */
export const windowControls: Record<"close" | "minimize" | "zoom", Pair<string>> = {
  close: { light: "oklch(0.678 0.166 23.4)", dark: "oklch(0.678 0.166 23.4)" },
  minimize: { light: "oklch(0.851 0.152 91.8)", dark: "oklch(0.851 0.152 91.8)" },
  zoom: { light: "oklch(0.74 0.159 144)", dark: "oklch(0.74 0.159 144)" },
};

/** The half point just inside each lit light's edge: a deeper shade of its
 *  own colour, measured at 2x (System Settings light, Terminal dark). Inactive
 *  lights keep a ring of black. */
export const windowControlRims: Record<"close" | "minimize" | "zoom", Pair<string>> = {
  close: { light: "oklch(0.612 0.211 27.1)", dark: "oklch(0.588 0.21 27.5)" },
  minimize: { light: "oklch(0.813 0.165 88)", dark: "oklch(0.786 0.16 87.2)" },
  zoom: { light: "oklch(0.671 0.195 143.2)", dark: "oklch(0.644 0.193 143.1)" },
};

/** The glyphs all three lights show while the pointer is over them, fitted to
 *  macOS 26's at 2x (dark and light): filled shapes on the light's 14-unit
 *  box, black at `opacity`. Close is an × of two `stroke`-wide bars cut square
 *  at its box; minimize a capsule between two centres; zoom a square split
 *  along its rising diagonal into two triangles, `gap` apart. A window that
 *  can't go full screen (System Settings) shows plus on zoom instead: the
 *  minimize capsule and its upright twin. */
export const windowGlyphs = {
  opacity: 0.5,
  close: { box: [3.5, 10.5], stroke: 2 },
  minimize: { ends: [4, 10], radius: 1 },
  zoom: { box: [4, 10], gap: 1.4 },
  plus: { ends: [4, 10], radius: 1 },
} as const;

// Materials and elevation ---------------------------------------------------

export interface Material {
  blur: number;
  saturate: number;
  tint: Pair<string>;
}

export const material = {
  thin: {
    blur: 20, saturate: 1.6,
    tint: { light: neutral(0.99, 0.38, 0.003), dark: neutral(0.22, 0.38) },
  },
  regular: {
    blur: 28, saturate: 1.8,
    tint: { light: neutral(0.99, 0.55, 0.003), dark: neutral(0.22, 0.5) },
  },
  thick: {
    blur: 36, saturate: 1.8,
    tint: { light: neutral(0.99, 0.72, 0.003), dark: neutral(0.24, 0.68) },
  },
  clear: {
    blur: 4, saturate: 1.2,
    tint: { light: white(0.12), dark: white(0.14) },
  },
  /** Blur only, for surfaces whose content carries the glass (control center). */
  backdrop: {
    blur: 10, saturate: 1,
    tint: { light: white(0), dark: white(0) },
  },
} satisfies Record<string, Material>;

export const glass = {
  rim: { light: white(0.65), dark: white(0.16) },
  edge: { light: neutral(0.18, 0.12, 0.006), dark: "oklch(0 0 0 / 0.5)" },
  noise: 0.02,
  refraction: { edge: 14, strength: 0.55, dispersion: 0.015, specularAngle: -45, specular: 0.6 },
};

/** [x, y, blur, spread, opacity of the mode's shadow ink] */
export type ShadowLayer = [number, number, number, number, number];

export const shadow: Record<string, Pair<ShadowLayer[]>> = {
  window: {
    light: [[0, 24, 64, 0, 0.26], [0, 2, 8, 0, 0.1]],
    dark: [[0, 24, 64, 0, 0.6], [0, 2, 8, 0, 0.4]],
  },
  windowInactive: {
    light: [[0, 12, 32, 0, 0.16], [0, 1, 4, 0, 0.08]],
    dark: [[0, 12, 32, 0, 0.45], [0, 1, 4, 0, 0.3]],
  },
  popover: {
    light: [[0, 12, 40, 0, 0.22], [0, 1, 3, 0, 0.12]],
    dark: [[0, 12, 40, 0, 0.5], [0, 1, 3, 0, 0.35]],
  },
  panel: {
    light: [[0, 10, 30, 0, 0.2], [0, 1, 2, 0, 0.08]],
    dark: [[0, 10, 30, 0, 0.45], [0, 1, 2, 0, 0.3]],
  },
  control: {
    light: [[0, 0.5, 1.5, 0, 0.18]],
    dark: [[0, 0.5, 1.5, 0, 0.4]],
  },
};

// Motion and input -----------------------------------------------------------

export interface Spring {
  /** Seconds, roughly the time to settle. */
  response: number;
  /** 1 = critically damped (no overshoot); lower = bouncier. */
  damping: number;
}

export const spring = {
  snappy: { response: 0.24, damping: 0.92 },
  smooth: { response: 0.38, damping: 1 },
  bouncy: { response: 0.45, damping: 0.72 },
  gesture: { response: 0.32, damping: 0.86 },
} satisfies Record<string, Spring>;

/** Exits use this fraction of the entrance spring's response. */
export const exitScale = 0.7;

/** Opacity-only changes, in ms, on a decelerating curve. */
export const fade = { fast: 120, base: 200, slow: 320 } as const;
export const fadeCurve = [0.3, 0, 0, 1] as const;

/**
 * Sequences that aren't a single spring, in ms, measured frame by frame from
 * screen recordings of the reference. Opacity follows `fadeCurve`.
 */
export const choreography = {
  controlCenter: { blurIn: 60, fadeIn: 100, fadeInDelay: 16, lightUpDelay: 70, lightUp: 160, fadeOut: 200 },
  /** The keys' display comes at once, stays this long after the last
   *  press, and fades. Not measured yet: by eye, until there is a recording. */
  hud: { fadeIn: 80, linger: 1500, fadeOut: 300 },
  /** A screenshot's thumbnail slides in from the screen's edge, floats this
   *  long, and slides back out. By eye. */
  screenshot: { slide: 320, linger: 5000 },
};

export const input = {
  scrollDeceleration: 0.998,
  rubberBand: 0.55,
  tooltipDelay: 600,
  scrollbarHide: 800,
} as const;
