// Resolves design/tokens.ts into concrete sRGB colors and solved springs, per
// mode. Every target formats this model; none of them read tokens.ts directly
// for colors, so derived values (accents, flattened labels) agree everywhere.

import * as t from "../../design/tokens";
import type { Mode, ModeColors, ShadowLayer } from "../../design/tokens";
import { contrast, ensureContrast, oklchToRgba, over, parseOklch, rgba, withAlpha, type RGBA } from "./color";
import { solveSpring, type SolvedSpring } from "./spring";

export interface ResolvedAccent {
  bg: RGBA;
  fg: RGBA;
  text: RGBA;
  hover: RGBA;
  pressed: RGBA;
  highlight: RGBA;
}

type Resolve<T> = { [K in keyof T]: T[K] extends string ? RGBA : Resolve<T[K]> };

export interface ResolvedMode extends Resolve<ModeColors> {
  palette: Record<string, RGBA>;
  status: Record<keyof typeof t.status, RGBA>;
  accents: Record<string, ResolvedAccent>;
  material: Record<keyof typeof t.material, { blur: number; saturate: number; tint: RGBA }>;
  glass: { rim: RGBA; edge: RGBA };
  shadows: Record<string, { layers: ShadowLayer[]; color: RGBA }>;
}

export interface Resolved {
  modes: Record<Mode, ResolvedMode>;
  springs: Record<keyof typeof t.spring, SolvedSpring>;
  /** The same springs at `exitScale` × response, for things leaving. */
  exits: Record<keyof typeof t.spring, SolvedSpring>;
  windowControls: Record<keyof typeof t.windowControls, RGBA>;
}

const mapValues = <T, U>(obj: Record<string, T>, fn: (v: T, k: string) => U) =>
  Object.fromEntries(Object.entries(obj).map(([k, v]) => [k, fn(v, k)]));

function resolveAccent(source: string, mode: Mode, content: RGBA, ink: RGBA): ResolvedAccent {
  const base = parseOklch(source);
  const bg = oklchToRgba(base);
  const whiteText: RGBA = { r: 255, g: 255, b: 255, a: 1 };
  const fg = contrast(whiteText, bg) >= t.accent.fgContrast ? whiteText : ink;
  const toward = mode === "light" ? -1 : 1;
  const text = oklchToRgba(ensureContrast(base, content, t.accent.textContrast, toward));
  const shift = (dl: number) => oklchToRgba({ ...base, l: Math.min(1, Math.max(0, base.l + dl)) });
  return {
    bg,
    fg,
    text,
    hover: shift(mode === "light" ? -0.04 : 0.04),
    pressed: shift(mode === "light" ? -0.08 : -0.04),
    highlight: withAlpha(bg, t.accent.highlight),
  };
}

function resolveMode(mode: Mode): ResolvedMode {
  const c = t.color[mode];
  const content = rgba(c.bg.content);
  // Text on light accents (honey, yellow) uses the light theme's opaque ink.
  const ink = over(rgba(t.color.light.label.primary), { r: 255, g: 255, b: 255, a: 1 });
  const palette = mapValues(t.palette, (p) => rgba(p[mode]));
  return {
    bg: mapValues(c.bg, rgba) as ResolvedMode["bg"],
    label: mapValues(c.label, rgba) as ResolvedMode["label"],
    fill: mapValues(c.fill, rgba) as ResolvedMode["fill"],
    separator: rgba(c.separator),
    border: rgba(c.border),
    shadow: rgba(c.shadow),
    palette,
    status: mapValues(t.status, (name) => palette[name]!) as ResolvedMode["status"],
    accents: mapValues(t.accent.options, (p) => resolveAccent(p[mode], mode, content, ink)),
    material: mapValues(t.material, (m) => ({ blur: m.blur, saturate: m.saturate, tint: rgba(m.tint[mode]) })) as ResolvedMode["material"],
    glass: { rim: rgba(t.glass.rim[mode]), edge: rgba(t.glass.edge[mode]) },
    shadows: mapValues(t.shadow, (s) => ({ layers: s[mode], color: rgba(c.shadow) })),
  };
}

export function resolve(): Resolved {
  return {
    modes: { light: resolveMode("light"), dark: resolveMode("dark") },
    springs: mapValues(t.spring, solveSpring) as Resolved["springs"],
    exits: mapValues(t.spring, (s) => solveSpring({ ...s, response: s.response * t.exitScale })) as Resolved["exits"],
    windowControls: mapValues(t.windowControls, rgba) as Resolved["windowControls"],
  };
}

/** Flattens a translucent color onto an opaque background. */
export const flat = (color: RGBA, bg: RGBA) => over(color, { ...bg, a: 1 });
