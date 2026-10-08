// KDE/Qt color schemes (~/.local/share/color-schemes/*.colors). The format only
// takes opaque "r,g,b", so translucent labels and fills are flattened onto the
// background of the set they appear in.

import * as t from "../../../design/tokens";
import type { Mode } from "../../../design/tokens";
import { toKde, withAlpha, type RGBA } from "../color";
import { flat, type Resolved, type ResolvedMode } from "../resolve";
import { HEADER, pt } from "./shared";

function colorSet(m: ResolvedMode, bg: RGBA, alternate: RGBA): Record<string, RGBA> {
  const a = m.accents[t.accent.default]!;
  return {
    BackgroundNormal: bg,
    BackgroundAlternate: alternate,
    DecorationFocus: a.bg,
    DecorationHover: a.bg,
    ForegroundActive: flat(a.text, bg),
    ForegroundInactive: flat(m.label.secondary, bg),
    ForegroundLink: flat(a.text, bg),
    ForegroundNegative: flat(m.status.error, bg),
    ForegroundNeutral: flat(m.status.warning, bg),
    ForegroundNormal: flat(m.label.primary, bg),
    ForegroundPositive: flat(m.status.success, bg),
    ForegroundVisited: flat(m.palette.purple!, bg),
  };
}

function selectionSet(m: ResolvedMode): Record<string, RGBA> {
  const a = m.accents[t.accent.default]!;
  const on = (c: RGBA) => flat(c, a.bg);
  return {
    BackgroundNormal: a.bg,
    BackgroundAlternate: a.pressed,
    DecorationFocus: a.bg,
    DecorationHover: a.bg,
    ForegroundActive: a.fg,
    ForegroundInactive: on(withAlpha(a.fg, 0.7)),
    ForegroundLink: a.fg,
    ForegroundNegative: a.fg,
    ForegroundNeutral: a.fg,
    ForegroundNormal: a.fg,
    ForegroundPositive: a.fg,
    ForegroundVisited: on(withAlpha(a.fg, 0.85)),
  };
}

const section = (name: string, entries: Record<string, RGBA | string | number>) =>
  `[${name}]\n${Object.entries(entries)
    .map(([k, v]) => `${k}=${typeof v === "object" ? toKde(v) : v}`)
    .join("\n")}`;

type Extra = { General?: Record<string, string>; KDE?: Record<string, string>; WM?: Record<string, string> };

export function kde(r: Resolved, mode: Mode, extra: Extra = {}): string {
  const m = r.modes[mode];
  const window = m.bg.window;
  const content = m.bg.content;
  // Complementary areas (lock screen, OSDs) are always the dark palette.
  const dark = r.modes.dark;
  const title = mode === "light" ? "Light" : "Dark";

  const windowSet = colorSet(m, window, flat(m.fill.quaternary, window));
  return [
    `# ${HEADER}`,
    section("ColorEffects:Disabled", {
      Color: mode === "light" ? "56,56,56" : "112,111,110",
      ColorAmount: 0, ColorEffect: 0, ContrastAmount: 0.65, ContrastEffect: 1, IntensityAmount: 0.1, IntensityEffect: 2,
    }),
    section("ColorEffects:Inactive", {
      ChangeSelectionColor: "true", Color: "112,111,110", ColorAmount: 0.025, ColorEffect: 2,
      ContrastAmount: 0.1, ContrastEffect: 2, Enable: "false", IntensityAmount: 0, IntensityEffect: 0,
    }),
    section("Colors:Button", colorSet(m, m.bg.control, flat(m.fill.primary, m.bg.control))),
    section("Colors:Complementary", colorSet(dark, dark.bg.window, flat(dark.fill.quaternary, dark.bg.window))),
    section("Colors:Header", windowSet),
    section("Colors:Header][Inactive", windowSet),
    section("Colors:Selection", selectionSet(m)),
    section("Colors:Tooltip", colorSet(m, m.bg.elevated, m.bg.elevated)),
    section("Colors:View", colorSet(m, content, flat(m.fill.quaternary, content))),
    section("Colors:Window", windowSet),
    section("General", { ColorScheme: `Ambrosia${title}`, Name: `Ambrosia ${title}`, shadeSortColumn: "true", ...extra.General }),
    section("KDE", { contrast: 4, ...extra.KDE }),
    section("WM", {
      activeBackground: window,
      activeBlend: flat(m.label.primary, window),
      activeForeground: flat(m.label.primary, window),
      inactiveBackground: window,
      inactiveBlend: flat(m.label.tertiary, window),
      inactiveForeground: flat(m.label.tertiary, window),
      ...extra.WM,
    }),
    "",
  ].join("\n\n");
}

/** A QFont string, the form kdeglobals stores fonts in. */
const qfont = (family: string, px: number, weight: number) => `${family},${pt(px)},-1,5,${weight},0,0,0,0,0,0,0,0,0,0,1`;

/**
 * The Ambrosia session's kdeglobals defaults (/etc/xdg/ambrosia/kdeglobals):
 * the light scheme plus the type scale's fonts. A user's own settings win.
 */
export function kdeglobals(r: Resolved): string {
  const ui = t.font.ui[0];
  const mono = t.font.mono[0];
  const { body, callout, footnote, headline } = t.type;
  return kde(r, "light", {
    General: {
      font: qfont(ui, body.size, body.weight),
      menuFont: qfont(ui, body.size, body.weight),
      toolBarFont: qfont(ui, callout.size, callout.weight),
      smallestReadableFont: qfont(ui, footnote.size, 400),
      fixed: qfont(mono, body.size, 400),
    },
    // Plasma applies this look-and-feel's defaults at login (session/look-and-feel).
    KDE: { LookAndFeelPackage: "org.ambrosia.desktop" },
    WM: { activeFont: qfont(ui, headline.size, headline.weight) },
  });
}
