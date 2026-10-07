import { expect, test } from "bun:test";
import { contrast, oklchToRgba, over, parseOklch, rgba, toHex } from "./color";

test("converts reference colors", () => {
  expect(toHex(rgba("oklch(1 0 0)"))).toBe("#ffffff");
  expect(toHex(rgba("oklch(0 0 0)"))).toBe("#000000");
  const red = rgba("oklch(0.62796 0.25768 29.234)");
  expect(Math.abs(red.r - 255) + red.g + red.b).toBeLessThanOrEqual(2);
});

test("maps out-of-gamut colors back into sRGB, keeping hue roughly", () => {
  const c = oklchToRgba({ l: 0.7, c: 0.5, h: 150, a: 1 });
  for (const v of [c.r, c.g, c.b]) expect(v >= 0 && v <= 255).toBe(true);
  expect(c.g).toBeGreaterThan(c.r);
});

test("parses alpha", () => {
  expect(parseOklch("oklch(0.5 0.1 200 / 0.25)").a).toBe(0.25);
  expect(() => parseOklch("#fff")).toThrow();
});

test("composites and measures contrast", () => {
  const white = { r: 255, g: 255, b: 255, a: 1 };
  const black = { r: 0, g: 0, b: 0, a: 1 };
  expect(contrast(white, black)).toBeCloseTo(21, 5);
  expect(over({ ...black, a: 0.5 }, white).r).toBe(128);
});
