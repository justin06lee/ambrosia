// GTK apps' controls, drawn as the Qt widget style draws them (style/), from
// the same tokens: `controls`, `controlColor`, the switch, the focus ring and
// the scroll bar. CSS over the stock themes (GTK 3's Adwaita, GTK 4's Default
// and libadwaita's), in the user's stylesheet, which outranks a theme's rule
// whatever its selector: so a rule here on `button` reaches every kind of
// button, and each kind a theme tells apart (flat, linked, round, in a
// titlebar) is told apart again below.
//
// GTK 4 takes its colors as variables (light and dark in one file); GTK 3 has
// neither variables nor a dark query, so its colors are written out per mode.

import * as t from "../../../design/tokens";
import type { Mode } from "../../../design/tokens";
import { rgba, toCss, withAlpha, type RGBA } from "../color";
import type { ResolvedMode } from "../resolve";
import { svgPath, type Point } from "./shared";

export type Gtk = 3 | 4;

const C = t.controls;

/** A switch that is off (Settings' Look.switchOff). */
const SWITCH_OFF: Record<Mode, RGBA> = {
  light: { r: 0xdd, g: 0xdd, b: 0xdd, a: 1 },
  dark: { r: 0x41, g: 0x41, b: 0x40, a: 1 },
};

/** The colors the rules below name, for one mode. */
export function controlColors(m: ResolvedMode, mode: Mode): Record<string, RGBA> {
  const accent = m.accents[t.accent.default]!;
  const own = Object.fromEntries(Object.entries(t.controlColor).map(([key, pair]) => [key, rgba(pair[mode])]));
  return {
    ...own,
    accent: accent.bg,
    accentFg: accent.fg,
    accentText: accent.text,
    accentPressed: accent.pressed,
    ring: withAlpha(accent.bg, 0.6),
    fg: m.label.primary,
    fg2: m.label.secondary,
    fg3: m.label.tertiary,
    window: m.bg.window,
    content: m.bg.content,
    sidebar: m.bg.sidebar,
    separator: m.separator,
    destructive: m.status.destructive,
    switchOff: SWITCH_OFF[mode],
    knobShadow: { ...m.shadow, a: mode === "light" ? 0.22 : 0.5 },
    knobEdge: { r: 0, g: 0, b: 0, a: mode === "light" ? 0.1 : 0.3 },
    menuShadow: { ...m.shadow, a: mode === "light" ? 0.22 : 0.5 },
  };
}

const kebab = (s: string) => s.replace(/([a-z0-9])([A-Z])/g, "$1-$2").toLowerCase();

/** GTK 4's variables for one mode's control colors. */
export const controlVars = (m: ResolvedMode, mode: Mode, indent: string) =>
  Object.entries(controlColors(m, mode))
    .map(([key, c]) => `${indent}--amb-${kebab(key)}: ${toCss(c)};`)
    .join("\n");

// The marks in a checkbox and a radio button ------------------------------------

/** A line with round ends and corners as filled polygons, all wound the same
 *  way: GTK recolors a symbolic image by filling its paths, so a stroke
 *  wouldn't show. */
function stroked(points: Point[], width: number): Point[][] {
  const r = width / 2;
  const dot = ([cx, cy]: Point): Point[] =>
    Array.from({ length: 16 }, (_, i): Point => {
      const a = (2 * Math.PI * i) / 16;
      return [cx + r * Math.cos(a), cy + r * Math.sin(a)];
    });
  const bar = ([ax, ay]: Point, [bx, by]: Point): Point[] => {
    const len = Math.hypot(bx - ax, by - ay);
    const nx = (-(by - ay) / len) * r;
    const ny = ((bx - ax) / len) * r;
    return [[ax - nx, ay - ny], [bx - nx, by - ny], [bx + nx, by + ny], [ax + nx, ay + ny]];
  };
  const polys = [...points.map(dot), ...points.slice(1).map((p, i) => bar(points[i]!, p))];
  return polys.map((p) => p.map(([x, y]): Point => [+x.toFixed(3), +y.toFixed(3)]));
}

/** The check, the dash of a mixed box and a radio button's dot, on the box's
 *  16 units, as style.cpp draws them. */
export function checkGlyphs(): Record<string, string> {
  const s = C.check.size;
  const svg = (body: string) =>
    `<svg xmlns="http://www.w3.org/2000/svg" width="${s}" height="${s}" viewBox="0 0 ${s} ${s}">${body}</svg>\n`;
  const path = (points: Point[]) => `<path d="${svgPath(stroked(points, 1.8))}" fill="#000"/>`;
  return {
    "assets/check-symbolic.svg": svg(path([[4.2, 8.4], [7, 11.1], [11.8, 5.1]])),
    "assets/dash-symbolic.svg": svg(path([[4.5, s / 2], [s - 4.5, s / 2]])),
    "assets/bullet-symbolic.svg": svg(`<circle cx="${s / 2}" cy="${s / 2}" r="3" fill="#000"/>`),
  };
}

// The rules -----------------------------------------------------------------------

/**
 * The controls' CSS for one toolkit. `mode` is given for GTK 3, whose colors
 * are written out; GTK 4 names the variables `controlVars` defines.
 */
export function controls(gtk: Gtk, m?: ResolvedMode, mode?: Mode): string {
  const literal = m && mode ? controlColors(m, mode) : null;
  const k = new Proxy({} as Record<string, string>, {
    get: (_, key: string) => (literal ? toCss(literal[key]!) : `var(--amb-${kebab(key)})`),
  });
  const g4 = gtk === 4;
  const sw = t.size.switch;
  const bar = t.size.scrollbar;
  const ring = t.size.focusRing;
  const icon = (name: string) => `-gtk-icon-source: -gtk-recolor(url("assets/${name}-symbolic.svg"));`;
  // A hairline round a field: GTK 3 clips a shadow to the widget, so it is a border there.
  const push = C.push;
  const field = C.field;
  const menu = C.menu;
  const track = C.slider.track;
  const knobAcross = (C.slider.knobHeight - track) / 2;

  // Each kind of button a theme draws without a face.
  const bars = g4
    ? ["headerbar", ".toolbar", "actionbar", "searchbar", "tabbar"]
    : ["headerbar", ".titlebar", "toolbar", ".inline-toolbar", "actionbar", "searchbar"];
  const inBars = (suffix: string) => bars.map((b) => `${b} button${suffix}`).join(", ");
  const quiet = g4
    ? "button.flat, button.link, menubutton.flat > button, spinbutton > button, calendar > header > button, notebook > header > tabs > arrow, tab button, .linked > entry + button.flat"
    : "button.flat, button.link, spinbutton button, calendar.button, notebook > header > tabs > arrow, tab button, button.sidebar-button, .path-bar button.slider-button";

  const focus = g4
    ? `
/* Focus by the keyboard: a ring in the accent color. */
*:focus:focus-visible { outline-color: ${k.ring}; outline-width: ${ring.width}px; }
button:focus:focus-visible, check:focus:focus-visible, radio:focus:focus-visible, switch:focus:focus-visible, checkbutton:focus:focus-visible > check, checkbutton:focus:focus-visible > radio {
  outline: ${ring.width}px solid ${k.ring}; outline-offset: ${ring.offset}px;
}
checkbutton:focus:focus-visible { outline-color: transparent; }
`
    : `
/* Focus by the keyboard: a ring in the accent color, inside the control (GTK 3
   clips a widget's drawing to it). */
* { outline-color: ${k.ring}; outline-style: solid; outline-width: ${ring.width}px; outline-offset: -${ring.width}px; -gtk-outline-radius: ${push.radius}px; }
`;

  const surfaces = g4
    ? `
/* libadwaita takes its surfaces from the variables above; GTK 4's own theme
   has its colors written in and keeps them (a rule on .view or a window
   here would outrank libadwaita's own exceptions). */
:root { --disabled-opacity: ${Math.round(C.disabled * 100)}%; }
link, button.link, button.link > label { color: ${k.accentText}; }
`
    : `
/* GTK 3's Adwaita has its colors written in: the surfaces again, in ours. */
.background { color: ${k.fg}; background-color: ${k.window}; }
.background:backdrop { color: ${k.fg}; background-color: ${k.window}; }
.view, iconview, .view text, iconview text, textview text { color: ${k.fg}; background-color: ${k.content}; }
.view:backdrop, iconview:backdrop, .view text:backdrop, textview text:backdrop { color: ${k.fg}; background-color: ${k.content}; }
textview border { background-color: ${k.window}; color: ${k.fg2}; }
label { color: inherit; }
label:disabled, .dim-label, label.separator { color: ${k.fg3}; }
headerbar, .titlebar:not(headerbar), headerbar:backdrop { color: ${k.fg}; background-color: ${k.window}; background-image: none; border-color: ${k.separator}; box-shadow: none; text-shadow: none; }
headerbar .title { font-weight: bold; }
headerbar .subtitle { color: ${k.fg2}; }
.sidebar, stacksidebar, placessidebar { background-color: ${k.sidebar}; border-color: ${k.separator}; }
.sidebar .view, .sidebar list, placessidebar list, stacksidebar list { background-color: transparent; }
list { color: ${k.fg}; background-color: ${k.content}; border-color: ${k.separator}; }
separator, paned > separator { background-color: ${k.separator}; background-image: none; }
frame > border, .frame, scrolledwindow.frame, actionbar > revealer > box, searchbar > revealer > box, notebook, stack.frame { border-color: ${k.separator}; }
actionbar > revealer > box, searchbar > revealer > box, toolbar, .inline-toolbar { background-color: ${k.window}; }
statusbar, .statusbar { color: ${k.fg2}; }
selection, .view:selected, .view text selection, textview text selection, entry selection, label selection, iconview:selected, flowboxchild:selected, row:selected, treeview.view:selected, calendar:selected {
  background-color: ${k.accent}; color: ${k.accentFg};
}
row:selected label, treeview.view:selected label { color: ${k.accentFg}; }
row:selected:backdrop, treeview.view:selected:backdrop, .view:selected:backdrop, iconview:selected:backdrop { background-color: ${k.rowUnfocused}; color: ${k.fg}; }
row:selected:backdrop label { color: ${k.fg}; }
*:link, button.link, button.link > label { color: ${k.accentText}; }
`;

  return `
/* Controls: as the Qt widget style draws them. */
${surfaces}${focus}
/* Push buttons. */
button {
  min-height: ${push.height}px; min-width: 16px; padding: 0 ${push.padding}px; margin: 0;
  border: none; border-radius: ${push.radius}px; background-clip: border-box;
  background-color: ${k.face}; background-image: none; box-shadow: none; text-shadow: none; -gtk-icon-shadow: none;
  color: ${g4 ? "inherit" : k.fg}; font-weight: normal;${g4 ? "" : ` -gtk-outline-radius: ${push.radius}px;`}
}
button:active, button.keyboard-activating, button:checked { background-color: ${k.facePressed}; }
${g4 ? "" : `button:backdrop, button:disabled, button:hover { color: ${k.fg}; }
button label { color: inherit; }
button:disabled { background-color: ${k.box}; color: ${k.fg3}; }
button:disabled label { color: ${k.fg3}; }
`}button.image-button { min-width: 16px; padding: 0 4px; }
button.text-button.image-button, button.image-text-button { padding: 0 ${push.padding - 4}px; }
button.circular, button.pill, menubutton.circular > button { border-radius: 9999px; }
button.circular, menubutton.circular > button { min-width: ${push.height}px; padding: 0; }
button.pill { padding: 6px 24px; }

/* The one Return presses, and the one that destroys. */
button.suggested-action, button.suggested-action:hover, button.suggested-action:backdrop, button.default:not(.flat) { background-color: ${k.accent}; color: ${k.accentFg}; }
button.suggested-action label, button.default:not(.flat) label { color: ${k.accentFg}; }
button.suggested-action:active, button.suggested-action:checked, button.default:not(.flat):active { background-color: ${k.accentPressed}; }
button.destructive-action, button.destructive-action:hover, button.destructive-action:backdrop { background-color: ${k.face}; color: ${k.destructive}; }
button.destructive-action label { color: ${k.destructive}; }
button.destructive-action:active { background-color: ${k.facePressed}; }

/* Buttons with no face until the pointer is on them: a toolbar's, a flat one. */
${quiet}, ${inBars("")} {
  background-color: transparent; border-radius: ${C.tool.radius}px;
}
${inBars("")} { padding: 0 6px; min-width: 16px; }
${inBars(".text-button")} { padding: 0 9px; }
${quiet.split(", ").map((s) => `${s}:hover`).join(", ")}, ${inBars(":hover")} { background-color: ${k.face}; }
${quiet.split(", ").map((s) => `${s}:active`).join(", ")}, ${quiet.split(", ").map((s) => `${s}:checked`).join(", ")}, ${inBars(":active")}, ${inBars(":checked")} { background-color: ${k.facePressed}; }
${inBars(".suggested-action")}, ${inBars(".suggested-action:hover")} { background-color: ${k.accent}; color: ${k.accentFg}; border-radius: ${push.radius}px; padding: 0 ${push.padding}px; }
${inBars(".suggested-action:active")} { background-color: ${k.accentPressed}; }
button.link { padding: 0 4px; }
button.link:hover, button.link:active { background-color: transparent; }
button.osd, button.osd:hover { background-color: rgba(0, 0, 0, 0.6); color: #fff; }
${g4 ? `button.card, button.card:hover { background-color: var(--card-bg-color); border-radius: 12px; padding: 0; }
button.opaque { background-color: color-mix(in srgb, var(--window-bg-color) 85%, var(--window-fg-color)); }
` : ""}
/* Buttons side by side: one control, square where they meet. A switcher of
   pages is a segmented control, the chosen one in the accent color. */
.linked:not(.vertical) > button:not(:first-child), .linked:not(.vertical) > entry:not(:first-child), .linked:not(.vertical) > menubutton:not(:first-child) > button, .linked:not(.vertical) > combobox:not(:first-child) button, .linked:not(.vertical) > spinbutton:not(:first-child) { border-top-left-radius: 0; border-bottom-left-radius: 0; }
.linked:not(.vertical) > button:not(:last-child), .linked:not(.vertical) > entry:not(:last-child), .linked:not(.vertical) > menubutton:not(:last-child) > button, .linked:not(.vertical) > combobox:not(:last-child) button, .linked:not(.vertical) > spinbutton:not(:last-child) { border-top-right-radius: 0; border-bottom-right-radius: 0; }
.linked.vertical > button:not(:first-child), .linked.vertical > entry:not(:first-child) { border-top-left-radius: 0; border-top-right-radius: 0; }
.linked.vertical > button:not(:last-child), .linked.vertical > entry:not(:last-child) { border-bottom-left-radius: 0; border-bottom-right-radius: 0; }
.linked:not(.vertical) > button:not(:first-child):not(:checked):not(.suggested-action) { box-shadow: inset 1px 0 ${k.fieldBorder}; }
stackswitcher > button, ${bars.map((b) => `${b} stackswitcher > button`).join(", ")} { background-color: ${k.face}; border-radius: ${C.tab.radius}px; padding: 0 ${C.tab.padding}px; min-height: ${C.tab.height}px; }
stackswitcher > button:hover, ${bars.map((b) => `${b} stackswitcher > button:hover`).join(", ")} { background-color: ${k.face}; }
stackswitcher > button:checked, stackswitcher > button:checked:hover, ${bars.map((b) => `${b} stackswitcher > button:checked`).join(", ")} { background-color: ${k.accent}; color: ${k.accentFg}; box-shadow: none; }
stackswitcher > button:checked label { color: ${k.accentFg}; }
stackswitcher > button.text-button { min-width: 64px; }

/* Text fields. */
${g4 ? "entry, spinbutton, editablelabel > stack > text" : "entry, spinbutton:not(.vertical)"} {
  min-height: ${g4 ? field.height : field.height - 2}px; padding: 0 ${field.padding}px;
  border-radius: ${field.radius}px; background-color: ${k.field}; background-image: none; color: ${k.fg};
  ${g4 ? `border: none; box-shadow: inset 0 0 0 1px ${k.fieldBorder}; outline: 0 solid transparent; outline-offset: -1px;` : `border: 1px solid ${k.fieldBorder}; box-shadow: none; -gtk-outline-radius: ${field.radius}px;`}
}
${g4
    ? `entry:focus-within, spinbutton:focus-within { outline: ${ring.width}px solid ${k.ring}; outline-offset: -1px; }
entry > text > placeholder, spinbutton > text > placeholder { color: ${k.fg3}; }
entry.flat, entry.flat:focus-within { background-color: transparent; box-shadow: none; }`
    : `entry:focus, spinbutton:focus:not(.vertical) { border-color: ${k.ring}; box-shadow: inset 0 0 0 ${ring.width - 1}px ${k.ring}; }
entry:backdrop, spinbutton:backdrop:not(.vertical) { background-color: ${k.field}; border-color: ${k.fieldBorder}; color: ${k.fg}; box-shadow: none; }
entry:disabled, spinbutton:disabled:not(.vertical) { background-color: ${k.box}; border-color: ${k.fieldBorder}; color: ${k.fg3}; }
entry image, entry image:hover { color: ${k.fg2}; }
entry.flat, entry.flat:focus { background-color: transparent; border-color: transparent; box-shadow: none; }`}
entry.search { border-radius: ${field.radius + 1}px; }

/* A stepper: the field with its two buttons inside. */
${g4 ? "spinbutton" : "spinbutton:not(.vertical)"} { padding: 0; }
${g4 ? "spinbutton > text" : "spinbutton:not(.vertical) entry"} { min-height: ${g4 ? field.height : field.height - 2}px; padding: 0 ${field.padding}px; background: none; border: none; box-shadow: none; }
${g4 ? "spinbutton > button, spinbutton > button.image-button" : "spinbutton:not(.vertical) button"} { min-height: 0; min-width: ${C.arrows.width}px; padding: 0; margin: 0; border-radius: 0; background-color: transparent; border: none; box-shadow: inset 1px 0 ${k.fieldBorder}; color: ${k.fg}; }
${g4 ? "spinbutton > button:hover" : "spinbutton:not(.vertical) button:hover"} { background-color: ${k.face}; }
${g4 ? "spinbutton > button:active" : "spinbutton:not(.vertical) button:active"} { background-color: ${k.facePressed}; }
${g4 ? "spinbutton > button:last-child" : "spinbutton:not(.vertical) button:last-child"} { border-top-right-radius: ${field.radius}px; border-bottom-right-radius: ${field.radius}px; }
${g4 ? `row.spin spinbutton, row.spin spinbutton:focus-within { background-color: transparent; box-shadow: none; outline: none; }
row.spin spinbutton > button, row.spin spinbutton > button:last-child { box-shadow: none; border-radius: ${C.tool.radius}px; min-width: ${C.push.height}px; min-height: ${C.push.height}px; }
row.entry, row.entry:focus-within { outline-color: ${k.ring}; }
` : ""}
/* Pop-up buttons. */
${g4 ? "dropdown > button, combobox > box > button.combo" : "combobox button.combo"} { padding: 0 6px 0 9px; }
${g4 ? "dropdown > button > box, combobox > box > button > box { border-spacing: 6px; }" : ""}

/* Checkboxes and radio buttons. */
check, radio {
  min-width: ${C.check.size}px; min-height: ${C.check.size}px; padding: 0; margin: 0 ${g4 ? 0 : C.check.gap}px 0 0;
  border: none; background-color: ${k.track}; background-image: none; box-shadow: none;
  color: ${k.accentFg}; -gtk-icon-source: none; -gtk-icon-shadow: none;${g4 ? ` -gtk-icon-size: ${C.check.size}px;` : ` -gtk-outline-radius: ${C.check.radius}px;`}
}
check { border-radius: ${C.check.radius}px; }
radio { border-radius: 50%; }
check:hover, radio:hover, check:backdrop, radio:backdrop { background-color: ${k.track}; box-shadow: none; }
check:checked, check:indeterminate, radio:checked, radio:indeterminate,
check:checked:hover, check:indeterminate:hover, radio:checked:hover, radio:indeterminate:hover,
check:checked:backdrop, check:indeterminate:backdrop, radio:checked:backdrop, radio:indeterminate:backdrop { background-color: ${k.accent}; color: ${k.accentFg}; }
check:checked:active, check:indeterminate:active, radio:checked:active { background-color: ${k.accentPressed}; }
check:checked { ${icon("check")} }
check:indeterminate, radio:indeterminate { ${icon("dash")} }
radio:checked { ${icon("bullet")} }
check:disabled, radio:disabled { opacity: ${C.disabled}; }
${g4 ? `checkbutton { border-spacing: ${C.check.gap}px; padding: 2px 0; }
checkbutton.selection-mode check, checkbutton.selection-mode radio { padding: 0; border-radius: 50%; }` : `checkbutton, radiobutton { padding: 2px 0; }
menu menuitem check, menu menuitem radio { background-color: transparent; color: inherit; }
menu menuitem check:checked, menu menuitem radio:checked, menu menuitem check:indeterminate { background-color: transparent; color: inherit; ${icon("check")} }
treeview.view check, treeview.view radio { margin: 0; }
treeview.view check:selected, treeview.view radio:selected { background-color: ${k.accentFg}; color: ${k.accent}; }
treeview.view check:not(:checked):not(:indeterminate):selected, treeview.view radio:not(:checked):selected { background-color: ${k.track}; }`}

/* Switches. */
switch {
  min-width: 0; min-height: 0; padding: ${(sw.height - sw.knob) / 2}px; margin: 0; border: none; border-radius: 9999px;
  background-color: ${k.switchOff}; background-image: none; box-shadow: none; font-size: 0; color: transparent;
}
switch:hover, switch:backdrop { background-color: ${k.switchOff}; }
switch:checked, switch:checked:hover, switch:checked:backdrop { background-color: ${k.accent}; }
switch:disabled { opacity: ${C.disabled}; }
switch ${g4 ? "> " : ""}slider, switch:hover ${g4 ? "> " : ""}slider, switch:checked ${g4 ? "> " : ""}slider, switch:backdrop ${g4 ? "> " : ""}slider {
  min-width: ${sw.knob}px; min-height: ${sw.knob}px; margin: 0; border: none; border-radius: 9999px;
  background-color: ${k.knob}; background-image: none; box-shadow: 0 0.5px 1.5px ${k.knobShadow};
}
${g4 ? "switch > image { min-width: 0; min-height: 0; color: transparent; }" : "switch image { color: transparent; -gtk-icon-source: none; min-width: 0; min-height: 0; }"}

/* Sliders. */
scale { min-height: ${C.slider.knobHeight}px; min-width: ${C.slider.knobHeight}px; padding: ${knobAcross + 1}px; }
scale trough, scale fill, progressbar trough {
  min-height: ${track}px; min-width: ${track}px; border: none; border-radius: ${track / 2}px;
  background-color: ${k.track}; background-image: none; box-shadow: none; outline: none;
}
scale trough:backdrop, scale trough:disabled, progressbar trough:backdrop, progressbar trough:disabled { background-color: ${k.track}; }
scale highlight, scale highlight:backdrop, progressbar progress, progressbar progress:backdrop {
  min-height: ${track}px; min-width: ${track}px; margin: 0; border: none; border-radius: ${track / 2}px;
  background-color: ${k.accent}; background-image: none; box-shadow: none;
}
scale slider, scale slider:hover, scale slider:active, scale slider:backdrop, scale slider:disabled, scale.fine-tune slider,
scale.marks-before slider, scale.marks-after slider, scale.marks-before:not(.marks-after) slider, scale.marks-after:not(.marks-before) slider {
  min-width: ${C.slider.knobWidth}px; min-height: ${C.slider.knobHeight}px; margin: -${knobAcross}px 0; padding: 0;
  border: none; border-radius: 9999px; background-color: ${k.knob}; background-image: none; background-size: auto;
  box-shadow: 0 0.5px 2px ${k.knobShadow}, 0 0 0 0.5px ${k.knobEdge};${g4 ? " transform: none;" : ` -gtk-outline-radius: ${C.slider.knobHeight / 2}px;`}
}
scale.vertical slider, scale.vertical slider:hover, scale.vertical slider:active, scale.vertical slider:backdrop,
scale.vertical.marks-before slider, scale.vertical.marks-after slider, scale.vertical.marks-before:not(.marks-after) slider, scale.vertical.marks-after:not(.marks-before) slider {
  min-width: ${C.slider.knobHeight}px; min-height: ${C.slider.knobWidth}px; margin: 0 -${knobAcross}px;
}
scale:disabled, progressbar:disabled { opacity: ${C.disabled}; }
levelbar trough { padding: 0; border: none; border-radius: ${track / 2}px; background-color: transparent; box-shadow: none; }
levelbar block { min-height: ${track}px; min-width: ${track}px; border: none; border-radius: ${track / 2}px; box-shadow: none; }
levelbar block.empty { background-color: ${k.track}; }
levelbar block.filled, levelbar block.filled.high, levelbar block.filled.full { background-color: ${k.accent}; }
progressbar.osd trough { background-color: transparent; }

/* Menus. */
${g4
    ? `popover > contents, popover > arrow {
  background-color: ${k.menu}; color: ${k.fg}; border: none;
  box-shadow: 0 0 0 0.5px ${k.menuRim}, 0 8px 24px ${k.menuShadow};
}
popover > contents { border-radius: ${menu.radius + 2}px; }
popover.menu > contents { border-radius: ${menu.radius}px; padding: ${menu.margin}px; }
popover.menu box.inline-buttons, popover.menu box.circular-buttons { padding: 0 ${menu.rowPadding}px; }
popover.menu modelbutton, popover.menu > contents row, popover listview > row {
  min-height: ${menu.row}px; padding: 0 ${menu.rowPadding}px; margin: 0; border-radius: ${menu.rowRadius}px; font-weight: normal;
}
popover.menu modelbutton:hover, popover.menu modelbutton:selected, popover.menu modelbutton:focus-visible, popover listview > row:hover, popover listview > row:selected {
  background-color: ${k.accent}; color: ${k.accentFg}; outline: none;
}
popover.menu modelbutton:active { background-color: ${k.accentPressed}; color: ${k.accentFg}; }
popover.menu separator { margin: ${(menu.rule - 1) / 2}px ${menu.rowPadding}px; min-height: 1px; background-color: ${k.menuRule}; }
popover.menu label.title { font-size: ${C.caption}em; font-weight: 600; color: ${k.fg2}; padding: 4px ${menu.rowPadding}px; }
popover.menu accelerator, popover.menu modelbutton > label.accelerator { color: ${k.fg2}; }
popover.menu modelbutton:hover accelerator, popover.menu modelbutton:selected accelerator { color: ${k.accentFg}; }`
    : `menu, .menu, .context-menu, .csd menu, .csd .menu {
  margin: 4px; padding: ${menu.margin}px; border: 1px solid ${k.menuRim}; border-radius: ${menu.radius}px;
  background-color: ${k.menu}; color: ${k.fg}; box-shadow: none;
}
menu menuitem, .menu menuitem, .context-menu menuitem {
  min-height: ${menu.row}px; padding: 0 ${menu.rowPadding}px; border-radius: ${menu.rowRadius}px; color: ${k.fg}; text-shadow: none;
}
menu menuitem:hover, .menu menuitem:hover, .context-menu menuitem:hover { background-color: ${k.accent}; color: ${k.accentFg}; }
menu menuitem:hover label, menu menuitem:hover accelerator, menu menuitem:hover arrow { color: ${k.accentFg}; }
menu menuitem:disabled, menu menuitem:disabled label { color: ${k.fg3}; }
menu menuitem accelerator { color: ${k.fg2}; }
menu separator, .menu separator, .context-menu separator { margin: ${(menu.rule - 1) / 2}px ${menu.rowPadding}px; min-height: 1px; background-color: ${k.menuRule}; }
menubar, .menubar { background-color: transparent; color: ${k.fg}; box-shadow: none; padding: 0; }
menubar > menuitem, .menubar > menuitem { min-height: ${menu.row}px; padding: 0 ${menu.rowPadding}px; border-radius: ${menu.rowRadius}px; color: ${k.fg}; }
menubar > menuitem:hover, .menubar > menuitem:hover { background-color: ${k.accent}; color: ${k.accentFg}; box-shadow: none; }
popover.background { padding: ${menu.margin}px; border: 1px solid ${k.menuRim}; border-radius: ${menu.radius}px; background-color: ${k.menu}; color: ${k.fg}; box-shadow: 0 4px 14px ${k.menuShadow}; }
popover.background:backdrop { background-color: ${k.menu}; }
popover.background separator { margin: ${(menu.rule - 1) / 2}px ${menu.rowPadding}px; background-color: ${k.menuRule}; }
modelbutton.flat, .menuitem.button.flat { min-height: ${menu.row}px; padding: 0 ${menu.rowPadding}px; border-radius: ${menu.rowRadius}px; background-color: transparent; color: ${k.fg}; }
modelbutton.flat:hover, .menuitem.button.flat:hover { background-color: ${k.accent}; color: ${k.accentFg}; }
modelbutton.flat:hover label { color: ${k.accentFg}; }
modelbutton check, modelbutton radio, modelbutton check:hover, modelbutton radio:hover { background-color: transparent; color: inherit; margin: 0; }
modelbutton check:checked, modelbutton radio:checked, modelbutton check:checked:hover, modelbutton radio:checked:hover { background-color: transparent; color: inherit; ${icon("check")} }`}

/* Tooltips. */
${g4
    ? `tooltip, tooltip.background { background-color: transparent; padding: 0; box-shadow: none; }
tooltip > box { background-color: ${k.menu}; color: ${k.fg}; border-radius: ${C.tooltip.radius}px; padding: 3px ${C.tooltip.padding}px; box-shadow: inset 0 0 0 0.5px ${k.menuRim}; }
tooltip > box > label { color: ${k.fg}; }`
    : `tooltip, tooltip.background { background-color: ${k.menu}; border: 1px solid ${k.menuRim}; border-radius: ${C.tooltip.radius}px; padding: 0; box-shadow: none; text-shadow: none; }
tooltip *, tooltip label { color: ${k.fg}; padding: 1px ${C.tooltip.padding / 2}px; text-shadow: none; }`}

/* Tabs: a row of names on a line, the chosen one filled. */
notebook > header, notebook > header:backdrop { padding: 3px; border-color: ${k.separator}; background-color: transparent; background-image: none; }
notebook > header > tabs { margin: 0; }
notebook > header > tabs > tab, notebook > header > tabs > tab:hover, notebook > header > tabs > tab:backdrop {
  min-height: ${C.tab.height}px; min-width: 24px; padding: 0 ${C.tab.padding}px; margin: 0 1px; border: none; border-radius: ${C.tab.radius}px;
  background-color: transparent; background-image: none; box-shadow: none; color: ${k.fg}; font-weight: normal; outline-offset: -${ring.width}px;
}
notebook > header > tabs > tab:hover { background-color: ${k.face}; }
notebook > header > tabs > tab:checked, notebook > header > tabs > tab:checked:hover, notebook > header > tabs > tab:checked:backdrop { background-color: ${k.facePressed}; box-shadow: none; color: ${k.fg}; }
notebook > header > tabs > tab label { color: inherit; font-weight: normal; }
notebook > header > tabs > tab button { min-height: ${C.tab.close}px; min-width: ${C.tab.close}px; padding: 0; border-radius: 50%; }
notebook > stack:not(:only-child), notebook > stack { background-color: transparent; }

/* A table's header. */
${g4 ? "columnview > header > button, treeview.view > header > button" : "treeview.view header button, treeview.view header button:hover, treeview.view header button:active, treeview.view header button:backdrop"} {
  min-height: ${C.row.header - 1}px; padding: 0 6px; border-radius: 0; border: none;
  background-color: ${g4 ? "transparent" : k.content}; background-image: none; box-shadow: inset 0 -1px ${k.separator};
  color: ${k.fg2}; font-size: ${C.caption}em; font-weight: normal; text-shadow: none;
}
${g4 ? "" : `treeview.view header button label { color: ${k.fg2}; }
treeview.view { border-color: ${k.separator}; }
treeview.view:hover { background-color: transparent; }
`}
/* Scroll bars: a thumb alone, thicker under the pointer. */
scrollbar, scrollbar:backdrop { background-color: transparent; border: none; box-shadow: none; }
scrollbar ${g4 ? "> range > trough" : "trough"} { background-color: transparent; border: none; margin: 0; }
scrollbar slider, scrollbar slider:backdrop, scrollbar.overlay-indicator slider, scrollbar.overlay-indicator:not(.dragging):not(.hovering) slider {
  min-width: ${bar.thin}px; min-height: ${bar.thin}px; margin: 0; border: ${bar.inset}px solid transparent; border-radius: 9999px;
  background-clip: padding-box; background-color: ${k.scroller}; box-shadow: none; outline: none; opacity: 1;
}
scrollbar.vertical slider { min-height: 28px; }
scrollbar.horizontal slider { min-width: 28px; }
scrollbar.hovering slider, scrollbar.dragging slider, scrollbar slider:hover, scrollbar slider:active, scrollbar.overlay-indicator.hovering slider, scrollbar.overlay-indicator.dragging slider {
  background-color: ${k.scrollerHover};
}
scrollbar.vertical.hovering slider, scrollbar.vertical.dragging slider, scrollbar.vertical:not(.overlay-indicator) slider:hover { min-width: ${bar.hover}px; }
scrollbar.horizontal.hovering slider, scrollbar.horizontal.dragging slider, scrollbar.horizontal:not(.overlay-indicator) slider:hover { min-height: ${bar.hover}px; }
scrollbar button { min-width: 0; min-height: 0; padding: 0; background-color: transparent; }
`;
}
