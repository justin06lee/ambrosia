// The Qt widget style's tokens as a C++ header (style/): the controls' sizes,
// the colors a palette has no role for, and each mode's palette for the
// gallery, which runs where no KDE color scheme is installed.

import * as t from "../../../design/tokens";
import type { Mode } from "../../../design/tokens";
import { rgba, type RGBA } from "../color";
import { flat, type Resolved } from "../resolve";
import { HEADER } from "./shared";

/** 0xAARRGGBB, straight alpha, as QColor::fromRgba takes it. */
const argb = (c: RGBA) =>
  `0x${[Math.round(c.a * 255), c.r, c.g, c.b].map((v) => v.toString(16).padStart(2, "0")).join("")}u`;

const snake = (group: string, key: string) => `${group}${key[0]!.toUpperCase()}${key.slice(1)}`;

function mode(r: Resolved, name: Mode): string {
  const m = r.modes[name];
  const accent = m.accents[t.accent.default]!;
  const own = Object.entries(t.controlColor).map(([key, pair]) => `    .${key} = ${argb(rgba(pair[name]))},`);
  // What a KDE color scheme gives a Qt app's palette (targets/kde.ts), for
  // the gallery to stand in for it.
  const palette = {
    window: m.bg.window,
    base: m.bg.content,
    text: flat(m.label.primary, m.bg.window),
    textSecondary: flat(m.label.secondary, m.bg.window),
    textTertiary: flat(m.label.tertiary, m.bg.window),
    separator: m.separator,
    accent: accent.bg,
    accentText: accent.fg,
  };
  return `inline constexpr Mode ${name} = {
${own.join("\n")}
${Object.entries(palette).map(([key, c]) => `    .${key} = ${argb(c)},`).join("\n")}
};`;
}

export function qstyle(r: Resolved): string {
  const sizes = Object.entries(t.controls).flatMap(([group, v]) =>
    typeof v === "number"
      ? [`inline constexpr double ${group} = ${v};`]
      : Object.entries(v).map(([key, n]) => `inline constexpr double ${snake(group, key)} = ${n};`),
  );
  return `// ${HEADER}
#pragma once

namespace Ambrosia::Tokens {

struct Mode {
    unsigned ${Object.keys(t.controlColor).join(", ")};
    unsigned window, base, text, textSecondary, textTertiary, separator, accent, accentText;
};

${sizes.join("\n")}
inline constexpr double focusRing = ${t.size.focusRing.width};
inline constexpr double focusRingOffset = ${t.size.focusRing.offset};
inline constexpr double scrollbarThin = ${t.size.scrollbar.thin};
inline constexpr double scrollbarHover = ${t.size.scrollbar.hover};
inline constexpr double scrollbarInset = ${t.size.scrollbar.inset};

${mode(r, "light")}

${mode(r, "dark")}

} // namespace Ambrosia::Tokens
`;
}
