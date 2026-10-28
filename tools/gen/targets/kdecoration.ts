// The window frame's tokens as a C++ header for our KWin decoration plugin
// (decoration/): the titlebar, the traffic lights, the window's corner,
// rim, edge and shadow, light and dark.

import * as t from "../../../design/tokens";
import type { Mode } from "../../../design/tokens";
import type { RGBA } from "../color";
import type { Resolved } from "../resolve";
import { HEADER, windowGlyphPolygons, type Point } from "./shared";

/** 0xAARRGGBB, straight alpha, as QColor::fromRgba takes it. */
const argb = (c: RGBA) =>
  `0x${[Math.round(c.a * 255), c.r, c.g, c.b].map((v) => v.toString(16).padStart(2, "0")).join("")}u`;

function mode(r: Resolved, name: Mode): string {
  const m = r.modes[name];
  const shadow = (key: "window" | "windowInactive") => {
    const s = m.shadows[key]!;
    const layers = s.layers.map(([x, y, blur, spread, opacity]) => `{${x}, ${y}, ${blur}, ${spread}, ${opacity}}`);
    return `{${argb(s.color)}, ${s.layers.length}, {${layers.join(", ")}}}`;
  };
  const c = m.windowControls;
  return `inline constexpr Mode ${name} = {
    .window = ${argb(m.bg.window)},
    .title = ${argb(m.label.primary)},
    .titleInactive = ${argb(m.label.tertiary)},
    .close = ${argb(c.close)},
    .minimize = ${argb(c.minimize)},
    .zoom = ${argb(c.zoom)},
    .inactive = ${argb(c.inactive)},
    .rim = ${argb(m.glass.rim)},
    .edge = ${argb(m.glass.edge)},
    .shadow = ${shadow("window")},
    .shadowInactive = ${shadow("windowInactive")},
};`;
}

/** Polygons as a flat run: each one's point count, then its x, y pairs; 0 ends the run. */
const run = (polys: Point[][]) => [...polys.flatMap((p) => [p.length, ...p.flat()]), 0].join(", ");

export function kdecoration(r: Resolved): string {
  const glyphs = windowGlyphPolygons();
  return `// ${HEADER}
#pragma once

namespace Ambrosia::Tokens {

struct ShadowLayer {
    double x, y, blur, spread, opacity;
};

struct Shadow {
    unsigned ink;
    int count;
    ShadowLayer layers[4];
};

struct Mode {
    unsigned window, title, titleInactive;
    unsigned close, minimize, zoom, inactive;
    unsigned rim, edge;
    Shadow shadow, shadowInactive;
};

inline constexpr double titlebar = ${t.size.titlebar.height};
inline constexpr double diameter = ${t.size.windowControls.diameter};
inline constexpr double gap = ${t.size.windowControls.gap};
inline constexpr double radius = ${t.radius.window};

// The glyphs all three lights show on hover: filled polygons on the light's
// ${t.size.windowControls.diameter}-unit box, black at glyphOpacity. Each polygon is its point count,
// then its x, y pairs; 0 ends the list.
inline constexpr double glyphOpacity = ${t.windowGlyphs.opacity};
inline constexpr double closeGlyph[] = {${run(glyphs.close)}};
inline constexpr double minimizeGlyph[] = {${run(glyphs.minimize)}};
inline constexpr double zoomGlyph[] = {${run(glyphs.zoom)}};

${mode(r, "light")}

${mode(r, "dark")}

} // namespace Ambrosia::Tokens
`;
}
