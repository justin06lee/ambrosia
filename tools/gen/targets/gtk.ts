// GTK themes as color overrides on top of the stock themes:
//   gtk-4.0/gtk.css    libadwaita ≥ 1.6 CSS variables, light and dark in one file
//   gtk-3.0/gtk-*.css  named colors for adw-gtk3 / Adwaita GTK3, one file per mode
//                      (GTK3 has no prefers-color-scheme, so the active one is copied)
// Both also draw client-side titlebars' window controls as our traffic lights,
// with the glyphs Files draws (assets/*.svg beside each CSS file).

import * as t from "../../../design/tokens";
import type { Mode } from "../../../design/tokens";
import { toCss, type RGBA } from "../color";
import type { Resolved, ResolvedMode } from "../resolve";
import { HEADER, fontStack, pt, svgPath, windowGlyphPolygons } from "./shared";

const WHITE: RGBA = { r: 255, g: 255, b: 255, a: 1 };
const DARK_FG: RGBA = { r: 0, g: 0, b: 0, a: 0.8 };

/** The shared role → color mapping, in libadwaita's vocabulary. */
function roles(m: ResolvedMode, mode: Mode): Record<string, RGBA> {
  const a = m.accents[t.accent.default]!;
  const fg = m.label.primary;
  return {
    "accent-bg-color": a.bg,
    "accent-fg-color": a.fg,
    "accent-color": a.text,
    "destructive-bg-color": m.status.destructive,
    "destructive-fg-color": WHITE,
    "success-bg-color": m.status.success,
    "success-fg-color": WHITE,
    "warning-bg-color": m.status.warning,
    "warning-fg-color": DARK_FG,
    "error-bg-color": m.status.error,
    "error-fg-color": WHITE,
    "window-bg-color": m.bg.window,
    "window-fg-color": fg,
    "view-bg-color": m.bg.content,
    "view-fg-color": fg,
    "headerbar-bg-color": m.bg.window,
    "headerbar-fg-color": fg,
    "headerbar-border-color": m.separator,
    "headerbar-backdrop-color": m.bg.window,
    "headerbar-shade-color": m.separator,
    "headerbar-darker-shade-color": m.fill.primary,
    "sidebar-bg-color": m.bg.sidebar,
    "sidebar-fg-color": fg,
    "sidebar-backdrop-color": m.bg.sidebar,
    "sidebar-border-color": m.separator,
    "sidebar-shade-color": m.separator,
    "secondary-sidebar-bg-color": m.bg.sidebar,
    "secondary-sidebar-fg-color": fg,
    "secondary-sidebar-backdrop-color": m.bg.sidebar,
    "secondary-sidebar-border-color": m.separator,
    "secondary-sidebar-shade-color": m.separator,
    "card-bg-color": mode === "light" ? m.bg.content : m.fill.tertiary,
    "card-fg-color": fg,
    "card-shade-color": m.separator,
    "overview-bg-color": m.bg.window,
    "overview-fg-color": fg,
    "thumbnail-bg-color": m.bg.content,
    "thumbnail-fg-color": fg,
    "active-toggle-bg-color": mode === "light" ? m.bg.control : m.fill.primary,
    "active-toggle-fg-color": fg,
    "dialog-bg-color": m.bg.elevated,
    "dialog-fg-color": fg,
    "popover-bg-color": m.bg.elevated,
    "popover-fg-color": fg,
    "popover-shade-color": m.separator,
    "shade-color": { ...m.shadow, a: mode === "light" ? 0.07 : 0.36 },
    "scrollbar-outline-color": mode === "light" ? WHITE : { r: 0, g: 0, b: 0, a: 0.5 },
  };
}

/** GNOME's accent picker choices, filled from our accents where names match. */
function accentPicker(m: ResolvedMode): Record<string, RGBA> {
  const pick = (accent: string) => m.accents[accent]!.bg;
  return {
    "accent-blue": pick("blue"),
    "accent-teal": m.palette.teal!,
    "accent-green": pick("green"),
    "accent-yellow": pick("honey"),
    "accent-orange": pick("orange"),
    "accent-red": pick("red"),
    "accent-pink": pick("pink"),
    "accent-purple": pick("purple"),
    "accent-slate": pick("graphite"),
  };
}

// Window controls ---------------------------------------------------------------

/** The glyph images titlebuttons show on hover, one file each (GTK calls zoom "maximize"). */
export const titlebuttonGlyphs = (): Record<string, string> => {
  const glyphs = windowGlyphPolygons();
  const d = t.size.windowControls.diameter;
  return Object.fromEntries(
    (["close", "minimize", "maximize"] as const).map((name) => [
      `assets/${name}.svg`,
      `<svg xmlns="http://www.w3.org/2000/svg" width="${d}" height="${d}" viewBox="0 0 ${d} ${d}">` +
        `<path d="${svgPath(glyphs[name === "maximize" ? "zoom" : name])}" fill="#000" fill-opacity="${t.windowGlyphs.opacity}"/></svg>\n`,
    ]),
  );
};

/**
 * Close, minimize and zoom on GTK's own titlebars: 14px circles 9 apart, gray
 * on backdrop, each glyph on hover (GTK 4: all three while the pointer is over
 * any, as on a Mac; GTK 3 hovers buttons one at a time). `group` is GTK 4's
 * node holding the three.
 */
function titlebuttons(m: ResolvedMode, mode: Mode, buttons: string, group: string | null): string {
  const c = m.windowControls;
  const d = t.size.windowControls.diameter;
  const rim = mode === "light" ? 0.12 : 0.25;
  const glyphOn = group ? [`${group}:hover ${buttons}`, `${buttons}:hover`] : [`${buttons}:hover`];
  const each = (sel: string[], suffix: string) => sel.map((s) => s + suffix).join(",\n");
  return `
/* Window controls: traffic lights. */
${buttons} {
  min-width: ${d}px; min-height: ${d}px; padding: 0;
  margin: 0 ${t.size.windowControls.gap / 2}px;
  border: none; border-radius: 50%; outline: none;
  background-image: none; box-shadow: inset 0 0 0 0.5px rgba(0, 0, 0, ${rim});
  -gtk-icon-shadow: none;
}
${buttons} image { opacity: 0;${group ? ` -gtk-icon-size: ${d}px;` : ""} min-width: ${d}px; min-height: ${d}px; }
${buttons}.close { background-color: ${toCss(c.close)}; }
${buttons}.minimize { background-color: ${toCss(c.minimize)}; }
${buttons}.maximize { background-color: ${toCss(c.zoom)}; }
${buttons}:backdrop, ${buttons}:disabled { background-color: ${toCss(c.inactive)}; }
${each(glyphOn, ".close image")} { opacity: 1; -gtk-icon-source: url("assets/close.svg"); }
${each(glyphOn, ".minimize image")} { opacity: 1; -gtk-icon-source: url("assets/minimize.svg"); }
${each(glyphOn, ".maximize image")} { opacity: 1; -gtk-icon-source: url("assets/maximize.svg"); }
${buttons}:backdrop:hover.close { background-color: ${toCss(c.close)}; }
${buttons}:backdrop:hover.minimize { background-color: ${toCss(c.minimize)}; }
${buttons}:backdrop:hover.maximize { background-color: ${toCss(c.zoom)}; }
${buttons}:active { box-shadow: inset 0 0 0 0.5px rgba(0, 0, 0, ${rim}), inset 0 0 0 ${d}px rgba(0, 0, 0, 0.18); }
`;
}

const vars = (entries: Record<string, RGBA>, indent: string) =>
  Object.entries(entries).map(([k, c]) => `${indent}--${k}: ${toCss(c)};`).join("\n");

export function gtk4(r: Resolved): string {
  const fonts = [
    `  --document-font-family: ${fontStack(t.font.ui, t.font.fallback.ui)};`,
    `  --document-font-size: ${pt(t.type.body.size)}pt;`,
    `  --monospace-font-family: ${fontStack(t.font.mono, t.font.fallback.mono)};`,
    `  --monospace-font-size: ${pt(t.type.body.size)}pt;`,
    `  --window-radius: ${t.radius.window}px;`,
  ].join("\n");
  const light = r.modes.light;
  const dark = r.modes.dark;
  return `/* ${HEADER} */

:root {
${vars({ ...roles(light, "light"), ...accentPicker(light) }, "  ")}
${fonts}
}

@media (prefers-color-scheme: dark) {
  :root {
${vars({ ...roles(dark, "dark"), ...accentPicker(dark) }, "    ")}
  }
}
${titlebuttons(light, "light", GTK4_BUTTONS, "windowcontrols")}
@media (prefers-color-scheme: dark) {
${titlebuttons(dark, "dark", GTK4_BUTTONS, "windowcontrols")}
}
`;
}

const GTK4_BUTTONS = "windowcontrols > button";
const GTK3_BUTTONS = "button.titlebutton";

export function gtk3(r: Resolved, mode: Mode): string {
  const m = r.modes[mode];
  const named = roles(m, mode);
  const legacy: Record<string, RGBA> = {
    theme_bg_color: m.bg.window,
    theme_fg_color: m.label.primary,
    theme_base_color: m.bg.content,
    theme_text_color: m.label.primary,
    theme_selected_bg_color: m.accents[t.accent.default]!.bg,
    theme_selected_fg_color: m.accents[t.accent.default]!.fg,
    theme_unfocused_bg_color: m.bg.window,
    theme_unfocused_fg_color: m.label.secondary,
    borders: m.border,
    unfocused_borders: m.separator,
  };
  const lines = [
    ...Object.entries(named).map(([k, c]) => `@define-color ${k.replaceAll("-", "_")} ${toCss(c)};`),
    "",
    ...Object.entries(legacy).map(([k, c]) => `@define-color ${k} ${toCss(c)};`),
  ];
  return `/* ${HEADER} */\n/* ${mode} */\n\n${lines.join("\n")}\n${titlebuttons(m, mode, GTK3_BUTTONS, null)}`;
}
