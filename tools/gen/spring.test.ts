import { expect, test } from "bun:test";
import { solveSpring } from "./spring";

test("a critically damped spring never overshoots", () => {
  const s = solveSpring({ response: 0.38, damping: 1 });
  expect(Math.max(...s.samples)).toBeLessThanOrEqual(1.0001);
  expect(s.samples.at(-1)).toBe(1);
});

test("an underdamped spring overshoots, then settles", () => {
  const s = solveSpring({ response: 0.45, damping: 0.72 });
  expect(Math.max(...s.samples)).toBeGreaterThan(1.01);
  expect(s.duration).toBeGreaterThan(300);
  expect(s.duration).toBeLessThan(1500);
});

test("stiffness follows the response", () => {
  expect(solveSpring({ response: 1, damping: 1 }).stiffness).toBeCloseTo((2 * Math.PI) ** 2, 1);
});
