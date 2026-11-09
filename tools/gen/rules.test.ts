// The design spec's rules, checked against the tokens.
import { expect, test } from "bun:test";
import * as t from "../../design/tokens";
import { contrast } from "./color";
import { flat, resolve } from "./resolve";
import { qml } from "./targets/qml";
import { windowGlyphPolygons } from "./targets/shared";

const r = resolve();

test("radii are concentric", () => {
  const radius: Record<string, number> = t.radius;
  expect(radius.row).toBe(t.radius.popover - 6);
  expect(radius.card).toBe(t.radius.panel - 10);
  expect(radius.dock).toBe(Math.round(t.size.dock.icon * t.iconCorner) + t.size.dock.padding);
  expect(radius.module).toBe(t.size.controlCenter.unit / 2);
  expect(radius.controlCenter).toBe(t.radius.module + t.size.controlCenter.padding);
});

test("every size and gap sits on the 2px grid", () => {
  // Hairline-scale detail (focus ring, scrollbar thumbs), capsules and the
  // window controls (macOS 26's own: 14 across, 23 apart) are exempt.
  const { focusRing, scrollbar, windowControls, ...layout } = t.size;
  const { capsule, ...radii } = t.radius;
  const numbers = [
    ...Object.values(t.space),
    ...Object.values(radii),
    ...Object.values(layout).flatMap((v) => (typeof v === "number" ? [v] : Object.values(v))),
  ];
  for (const n of numbers) expect(n % 2).toBe(0);
});

for (const mode of t.modes) {
  const m = r.modes[mode];

  test(`${mode}: labels are legible on content and window`, () => {
    for (const bg of [m.bg.content, m.bg.window]) {
      expect(contrast(flat(m.label.primary, bg), bg)).toBeGreaterThanOrEqual(7);
      expect(contrast(flat(m.label.secondary, bg), bg)).toBeGreaterThanOrEqual(3);
    }
  });

  test(`${mode}: every accent meets its contrast rules`, () => {
    for (const [name, a] of Object.entries(m.accents)) {
      expect({ name, ok: contrast(a.text, m.bg.content) >= t.accent.textContrast }).toEqual({ name, ok: true });
      expect({ name, ok: contrast(a.fg, a.bg) >= t.accent.fgContrast }).toEqual({ name, ok: true });
    }
  });
}

test("the QML theme loads: no ECMAScript keywords as property names", () => {
  const names = [...qml(r).matchAll(/readonly property \w+ (\w+):/g)].map((m) => m[1]);
  expect(names.filter((n) => ["switch", "default", "case", "in", "function", "delete"].includes(n!))).toEqual([]);
  expect(names).toContain("switch_");
});

test("the lights' glyphs sit centred inside the light", () => {
  const d = t.size.windowControls.diameter;
  for (const [name, polys] of Object.entries(windowGlyphPolygons())) {
    const points = polys.flat();
    const xs = points.map(([x]) => x);
    const ys = points.map(([, y]) => y);
    const centre = [(Math.min(...xs) + Math.max(...xs)) / 2, (Math.min(...ys) + Math.max(...ys)) / 2];
    expect({ name, centre: centre.map((v) => +v.toFixed(3)) }).toEqual({ name, centre: [d / 2, d / 2] });
    const reach = Math.max(...points.map(([x, y]) => Math.hypot(x - d / 2, y - d / 2)));
    expect({ name, inside: reach < d / 2 - 1 }).toEqual({ name, inside: true });
  }
});
