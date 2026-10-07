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
  ui: ["Inter", "Inter Variable"],
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
  sidebar: 10, // window 16 − inset 6
  panel: 22,
  card: 12, // panel 22 − padding 10
  popover: 12,
  row: 6, // popover 12 − padding 6
  control: 8,
  controlSmall: 6,
  tooltip: 8,
  dock: 20, // icon corner 12 + padding 8
  capsule: 9999,
} as const;

/** App-icon corner as a fraction of the icon's size (superellipse). */
export const iconCorner = 0.225;
/** Concentric radii never go below this. */
export const minRadius = 4;

export const size = {
  menubar: { height: 28, itemPadding: 10, icon: 16 },
  dock: { icon: 52, padding: 8, gap: 6, margin: 6, indicator: 4 },
  titlebar: { height: 40, toolbar: 52 },
  windowControls: { diameter: 12, gap: 8, inset: 20 },
  sidebar: { width: 220, inset: 6, row: 28 },
  control: { small: 22, regular: 28, large: 36 },
  row: { compact: 24, regular: 28, large: 44 },
  switch: { width: 36, height: 20, knob: 16 },
  focusRing: { width: 3, offset: 1 },
  scrollbar: { thin: 7, hover: 11, inset: 2 },
  hitTarget: 24,
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

export const windowControls = {
  close: "oklch(0.68 0.2 28)",
  minimize: "oklch(0.83 0.16 82)",
  zoom: "oklch(0.72 0.19 145)",
};

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

export const input = {
  scrollDeceleration: 0.998,
  rubberBand: 0.55,
  tooltipDelay: 600,
  scrollbarHide: 800,
} as const;
