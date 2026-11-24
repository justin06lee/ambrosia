// The materials as a C++ header for our KWin effect (glass/effect): how each
// one blurs and saturates what is behind it, and how the rim bends it. The
// order is the protocol's (glass/protocol/ambrosia-glass-v1.xml, enum
// material): a pane names its material by that number.

import * as t from "../../../design/tokens";
import { kawaseFor } from "../kawase";
import { HEADER } from "./shared";

/** The materials in the protocol's order. */
export const GLASS_MATERIALS = ["thin", "regular", "thick", "clear", "backdrop"] as const satisfies readonly (keyof typeof t.material)[];

const f = (n: number) => (Number.isInteger(n) ? `${n}.0f` : `${n}f`);

export function glassTokens(): string {
  const rows = GLASS_MATERIALS.map((name) => {
    const m = t.material[name];
    const k = kawaseFor(m.blur);
    return `    {"${name}", ${k.iterations}, ${f(k.offset)}, ${k.expand}, ${f(m.saturate)}}, // blur(${m.blur}px)`;
  });
  const r = t.glass.refraction;
  return `// ${HEADER}
#pragma once

namespace Ambrosia::Tokens {

// A material's blur as the effect's dual Kawase passes: how many times the
// background is halved, the sampling offset, and how far outside a pane the
// blur reads (tools/gen/kawase.ts finds them from the design's blur radius).
struct Material {
    const char *name;
    int iterations;
    float offset;
    int expand;
    float saturation;
};

inline constexpr Material materials[] = {
${rows.join("\n")}
};
inline constexpr int materialCount = ${GLASS_MATERIALS.length};

// What a surface that only asks for a blur gets (other apps, by KDE's or
// the ext protocol), and a menu of such an app.
inline constexpr int fallbackMaterial = ${GLASS_MATERIALS.indexOf("regular")};
inline constexpr int menuMaterial = ${GLASS_MATERIALS.indexOf("thick")};

// The rim: within \`edge\` pixels of a pane's edge the background is bent
// outward by \`strength\`, its colors a little apart (\`dispersion\`).
struct Refraction {
    float edge;
    float strength;
    float dispersion;
};
inline constexpr Refraction refraction = {${f(r.edge)}, ${f(r.strength)}, ${f(r.dispersion)}};

// Grain over the blur, against banding: a share of full white.
inline constexpr float noise = ${f(t.glass.noise)};

} // namespace Ambrosia::Tokens
`;
}
