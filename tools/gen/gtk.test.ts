import { expect, test } from "bun:test";
import * as t from "../../design/tokens";
import { resolve } from "./resolve";
import { gtk3, gtk4, titlebuttonGlyphs } from "./targets/gtk";
import { checkGlyphs, controls } from "./targets/gtkcontrols";

const r = resolve();
const four = gtk4(r);
const three = { light: gtk3(r, "light"), dark: gtk3(r, "dark") };

const balanced = (css: string) => {
  let depth = 0;
  for (const ch of css.replace(/\/\*[\s\S]*?\*\//g, "")) {
    if (ch === "{") depth++;
    if (ch === "}") depth--;
    if (depth < 0) return false;
  }
  return depth === 0;
};

test("every rule is closed", () => {
  for (const css of [four, three.light, three.dark]) expect(balanced(css)).toBe(true);
});

test("GTK 3's CSS has nothing GTK 3 can't read", () => {
  for (const css of Object.values(three)) {
    for (const not of ["var(", "color-mix(", ":focus-visible", "transform:", "@media", "border-spacing", "undefined"]) {
      expect(css, not).not.toContain(not);
    }
  }
});

test("GTK 4's CSS names its control colors by variables, defined for light and for dark", () => {
  expect(four).not.toContain("undefined");
  const used = new Set([...controls(4).matchAll(/var\((--amb-[a-z0-9-]+)\)/g)].map((m) => m[1]!));
  expect(used.size).toBeGreaterThan(15);
  const light = four.slice(0, four.indexOf("@media (prefers-color-scheme: dark)"));
  const dark = four.slice(light.length, four.indexOf("/* Controls"));
  for (const name of used) {
    expect(light, name).toContain(`${name}:`);
    expect(dark, name).toContain(`${name}:`);
  }
  // The rules themselves hold no color of a mode: they would be the light one's in dark.
  expect(controls(4)).not.toMatch(/rgba?\((?!0, 0, 0)/);
});

test("the two modes of GTK 3 differ in colors only", () => {
  const shape = (css: string) => css.replace(/rgba?\([^)]*\)|#[0-9a-f]{3,8}\b/g, "C").replace("/* light */", "").replace("/* dark */", "");
  expect(shape(three.light)).toBe(shape(three.dark));
});

test("every picture a stylesheet names is beside it", () => {
  for (const [dir, css] of [["gtk-4.0", four], ["gtk-3.0", three.light], ["gtk-3.0", three.dark]] as const) {
    const files = titlebuttonGlyphs(dir);
    const named = [...css.matchAll(/url\("(assets\/[^"]+)"\)/g)].map((m) => m[1]!);
    expect(named.length).toBeGreaterThan(5);
    for (const name of named) expect(files[name], `${dir}/${name}`).toBeDefined();
  }
});

test("the controls take their sizes from the tokens", () => {
  const c = t.controls;
  for (const css of [four, three.light]) {
    expect(css).toContain(`min-height: ${c.push.height}px; min-width: 16px; padding: 0 ${c.push.padding}px`);
    expect(css).toContain(`border-radius: ${c.push.radius}px`);
    expect(css).toContain(`min-width: ${c.check.size}px; min-height: ${c.check.size}px`);
    expect(css).toContain(`min-width: ${c.slider.knobWidth}px; min-height: ${c.slider.knobHeight}px`);
    expect(css).toContain(`min-width: ${t.size.switch.knob}px; min-height: ${t.size.switch.knob}px`);
  }
  // A switch comes to the token's size: two knobs wide inside its padding.
  const pad = (t.size.switch.height - t.size.switch.knob) / 2;
  expect(2 * t.size.switch.knob + 2 * pad).toBe(t.size.switch.width);
});

test("a mark's pieces are all wound the same way, so they fill as one shape", () => {
  for (const [name, svg] of Object.entries(checkGlyphs())) {
    const d = svg.match(/ d="([^"]+)"/)?.[1];
    if (!d) continue; // the dot is a circle
    const signs = d.split("Z").filter(Boolean).map((sub) => {
      const p = sub.slice(1).split("L").map((xy) => xy.split(" ").map(Number) as [number, number]);
      return Math.sign(p.reduce((sum, [x, y], i) => sum + x * p[(i + 1) % p.length]![1] - p[(i + 1) % p.length]![0] * y, 0));
    });
    expect(new Set(signs).size, name).toBe(1);
  }
});

test("GTK 4's traffic lights outrank the controls' rules for a button", () => {
  // `button.image-button` would pad them out: each light is named by its class.
  expect(four).toContain("windowcontrols > button.close, windowcontrols > button.close:hover");
  expect(four).toContain(`windowcontrols { border-spacing: ${t.size.windowControls.gap}px; }`);
});
