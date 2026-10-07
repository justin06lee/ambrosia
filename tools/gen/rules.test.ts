// The design spec's rules, checked against the tokens.
import { expect, test } from "bun:test";
import * as t from "../../design/tokens";
import { contrast } from "./color";
import { flat, resolve } from "./resolve";

const r = resolve();

test("radii are concentric", () => {
  const radius: Record<string, number> = t.radius;
  expect(radius.sidebar).toBe(t.radius.window - t.size.sidebar.inset);
  expect(radius.row).toBe(t.radius.popover - 6);
  expect(radius.card).toBe(t.radius.panel - 10);
  expect(radius.dock).toBe(Math.round(t.size.dock.icon * t.iconCorner) + t.size.dock.padding);
});

test("every size and gap sits on the 2px grid", () => {
  // Hairline-scale detail (focus ring, scrollbar thumbs) and capsules are exempt.
  const { focusRing, scrollbar, ...layout } = t.size;
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
