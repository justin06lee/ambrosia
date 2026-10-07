// The QML singleton the shell (Quickshell) imports as `import Ambrosia`.
// Colors switch with `Theme.dark`; the accent with `Theme.accentName`.

import * as t from "../../../design/tokens";
import { toQtHex, type RGBA } from "../color";
import type { Resolved, ResolvedMode } from "../resolve";
import { HEADER, slug } from "./shared";

type Tree = { [key: string]: Tree | RGBA | number | string | unknown[] };

const isColor = (v: unknown): v is RGBA =>
  typeof v === "object" && v !== null && !Array.isArray(v) && "r" in v && "a" in v;

function value(v: unknown): [string, string] {
  if (isColor(v)) return ["color", `"${toQtHex(v)}"`];
  if (typeof v === "number") return [Number.isInteger(v) ? "int" : "real", `${v}`];
  if (typeof v === "string") return ["string", JSON.stringify(v)];
  return ["var", JSON.stringify(v)];
}

function object(tree: Tree, depth: number): string {
  const pad = "    ".repeat(depth + 1);
  const lines = Object.entries(tree).map(([key, v]) => {
    const name = slug(key).replace(/^(\d)/, "s$1");
    if (typeof v === "object" && v !== null && !Array.isArray(v) && !isColor(v)) {
      return `${pad}readonly property QtObject ${name}: ${object(v as Tree, depth + 1)}`;
    }
    const [kind, literal] = value(v);
    return `${pad}readonly property ${kind} ${name}: ${literal}`;
  });
  return `QtObject {\n${lines.join("\n")}\n${"    ".repeat(depth)}}`;
}

function modeTree(m: ResolvedMode): Tree {
  return {
    bg: m.bg,
    label: m.label,
    fill: m.fill,
    separator: m.separator,
    border: m.border,
    palette: m.palette,
    status: m.status,
    accents: m.accents as unknown as Tree,
    material: Object.fromEntries(Object.entries(m.material).map(([k, v]) => [k, { tint: v.tint }])),
    glass: m.glass,
    shadow: Object.fromEntries(
      Object.entries(m.shadows).map(([k, s]) => [
        k,
        {
          color: s.color,
          layers: s.layers.map(([x, y, blur, spread, opacity]) => ({ x, y, blur, spread, opacity })),
        },
      ]),
    ),
  } as Tree;
}

export function qml(r: Resolved): string {
  const statics: Tree = {
    text: Object.fromEntries(
      Object.entries(t.type).map(([k, s]) => [k, { ...s, tracking: +(t.tracking(s.size) * s.size).toFixed(3) }]),
    ),
    space: t.space as unknown as Tree,
    radius: { ...t.radius, minimum: t.minRadius, iconCorner: t.iconCorner },
    size: t.size as unknown as Tree,
    material: Object.fromEntries(Object.entries(t.material).map(([k, m]) => [k, { blur: m.blur, saturate: m.saturate }])),
    refraction: t.glass.refraction,
    spring: Object.fromEntries(
      Object.entries(r.springs).map(([k, s]) => [
        k,
        { mass: s.mass, stiffness: s.stiffness, damping: s.damping, duration: s.duration },
      ]),
    ),
    exit: Object.fromEntries(
      Object.entries(r.exits).map(([k, s]) => [
        k,
        { mass: s.mass, stiffness: s.stiffness, damping: s.damping, duration: s.duration },
      ]),
    ),
    fade: { ...t.fade, curve: [...t.fadeCurve] },
    input: t.input as unknown as Tree,
    windowControls: r.windowControls,
  };

  const staticProps = object(statics, 0)
    .split("\n")
    .slice(1, -1)
    .join("\n");

  return `// ${HEADER}
pragma Singleton
import QtQuick

QtObject {
    property bool dark: false
    property string accentName: ${JSON.stringify(t.accent.default)}

    readonly property string uiFont: ${JSON.stringify(t.font.ui[0])}
    readonly property string monoFont: ${JSON.stringify(t.font.mono[0])}

    readonly property QtObject color: dark ? darkColors : lightColors
    readonly property QtObject accent: color.accents[accentName] ?? color.accents[${JSON.stringify(t.accent.default)}]

${staticProps}

    readonly property QtObject lightColors: ${object(modeTree(r.modes.light), 1)}

    readonly property QtObject darkColors: ${object(modeTree(r.modes.dark), 1)}
}
`;
}

export const qmldir = `module Ambrosia\nsingleton Theme 1.0 Theme.qml\n`;
