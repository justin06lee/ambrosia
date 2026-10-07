// CSS custom properties for the web preview (and any web surface of the shell).

import * as t from "../../../design/tokens";
import type { Mode } from "../../../design/tokens";
import { toCss, type RGBA } from "../color";
import type { Resolved, ResolvedAccent, ResolvedMode } from "../resolve";
import { toCssLinear } from "../spring";
import { HEADER, cssShadow, fontStack, kebab, slug } from "./shared";

/** Size tokens that are counts, not lengths. */
const COUNTS = new Set(["columns"]);

const block = (selector: string, vars: [string, string][], indent = "") =>
  `${indent}${selector} {\n${vars.map(([k, v]) => `${indent}  --amb-${k}: ${v};`).join("\n")}\n${indent}}`;

function staticVars(r: Resolved): [string, string][] {
  const v: [string, string][] = [
    ["font-ui", fontStack(t.font.ui, t.font.fallback.ui)],
    ["font-mono", fontStack(t.font.mono, t.font.fallback.mono)],
  ];
  for (const [name, s] of Object.entries(t.type)) {
    const n = kebab(name);
    v.push(
      [`${n}-size`, `${s.size}px`],
      [`${n}-line`, `${s.line}px`],
      [`${n}-weight`, `${s.weight}`],
      [`${n}-tracking`, `${+t.tracking(s.size).toFixed(4)}em`],
      [`${n}`, `${s.weight} ${s.size}px/${s.line}px var(--amb-font-ui)`],
    );
  }
  for (const [k, px] of Object.entries(t.space)) v.push([`space-${slug(k)}`, `${px}px`]);
  for (const [k, px] of Object.entries(t.radius)) v.push([`radius-${kebab(k)}`, `${px}px`]);
  for (const [group, metrics] of Object.entries(t.size)) {
    if (typeof metrics === "number") v.push([`size-${kebab(group)}`, `${metrics}px`]);
    else for (const [k, px] of Object.entries(metrics)) v.push([`size-${kebab(group)}-${kebab(k)}`, COUNTS.has(k) ? `${px}` : `${px}px`]);
  }
  for (const [name, m] of Object.entries(t.material)) {
    v.push([`material-${name}-filter`, `blur(${m.blur}px) saturate(${m.saturate})`], [`material-${name}-blur`, `${m.blur}px`]);
  }
  v.push(["glass-noise", `${t.glass.noise}`]);
  for (const [name, s] of Object.entries(r.springs)) {
    v.push([`spring-${name}`, `${s.duration}ms ${toCssLinear(s)}`]);
    const exit = r.exits[name as keyof Resolved["exits"]];
    v.push([`spring-${name}-exit`, `${exit.duration}ms ${toCssLinear(exit)}`]);
  }
  const curve = `cubic-bezier(${t.fadeCurve.join(", ")})`;
  for (const [name, ms] of Object.entries(t.fade)) v.push([`fade-${name}`, `${ms}ms ${curve}`]);
  for (const [name, c] of Object.entries(r.windowControls)) v.push([`control-${name}`, toCss(c)]);
  return v;
}

const accentVars = (a: ResolvedAccent): [string, string][] =>
  Object.entries(a).map(([k, c]) => [`accent-${k}`, toCss(c as RGBA)]);

function modeVars(m: ResolvedMode): [string, string][] {
  const v: [string, string][] = [];
  for (const group of ["bg", "label", "fill"] as const) {
    for (const [k, c] of Object.entries(m[group])) v.push([`${group}-${kebab(k)}`, toCss(c)]);
  }
  v.push(["separator", toCss(m.separator)], ["border", toCss(m.border)], ["shadow-ink", toCss(m.shadow)]);
  for (const [k, c] of Object.entries(m.palette)) v.push([k, toCss(c)]);
  for (const [k, c] of Object.entries(m.status)) v.push([`status-${k}`, toCss(c)]);
  for (const [k, mat] of Object.entries(m.material)) v.push([`material-${k}-tint`, toCss(mat.tint)]);
  v.push(["glass-rim", toCss(m.glass.rim)], ["glass-edge", toCss(m.glass.edge)]);
  for (const [k, s] of Object.entries(m.shadows)) v.push([`shadow-${kebab(k)}`, cssShadow(s.layers, s.color)]);
  // Every accent's swatch stays available for pickers, whatever is active.
  for (const [k, a] of Object.entries(m.accents)) v.push([`accent-option-${k}`, toCss(a.bg)]);
  v.push(...accentVars(m.accents[t.accent.default]!));
  return v;
}

export function web(r: Resolved): string {
  const out = [`/* ${HEADER} */`, ""];
  out.push(
    `@font-face {\n  font-family: "Inter";\n  src: url("fonts/inter-latin-opsz-normal.woff2") format("woff2");\n  font-weight: 100 900;\n  font-display: swap;\n}`,
    `@font-face {\n  font-family: "JetBrains Mono";\n  src: url("fonts/jetbrains-mono-latin-wght-normal.woff2") format("woff2");\n  font-weight: 100 800;\n  font-display: swap;\n}`,
    "",
    block(":root", staticVars(r)),
    "",
  );

  // Light is the base; dark applies by attribute or by system preference
  // unless the page pins light. Accents follow the same pattern.
  const selectors: Record<Mode, { base: string; media?: string }[]> = {
    light: [{ base: ":root" }],
    dark: [{ base: '[data-theme="dark"]' }, { base: ':root:not([data-theme="light"])', media: "(prefers-color-scheme: dark)" }],
  };
  for (const mode of t.modes) {
    for (const { base, media } of selectors[mode]) {
      const indent = media ? "  " : "";
      const rules = [block(base, modeVars(r.modes[mode]), indent)];
      for (const [name, a] of Object.entries(r.modes[mode].accents)) {
        if (name !== t.accent.default) rules.push(block(`${base}[data-accent="${name}"]`, accentVars(a), indent));
      }
      out.push(media ? `@media ${media} {\n${rules.join("\n\n")}\n}` : rules.join("\n\n"), "");
    }
  }
  return out.join("\n");
}
