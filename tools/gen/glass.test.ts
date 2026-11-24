import { expect, test } from "bun:test";
import { join } from "node:path";
import * as t from "../../design/tokens";
import { KAWASE_LEVELS, kawaseFor, kawaseSigma } from "./kawase";
import { GLASS_MATERIALS, glassTokens } from "./targets/glass";

// The effect can't be run here: what can be held is that each material's
// blur settings give the softness the design asks for, and that the numbers
// a pane names its material by are the same on both sides of the protocol.

test("a wider offset or one more halving blurs more", () => {
  expect(kawaseSigma(3, 4)).toBeGreaterThan(kawaseSigma(3, 3));
  expect(kawaseSigma(4, 3)).toBeGreaterThan(kawaseSigma(3, 3));
});

test("each material's settings blur as its Gaussian does, within 3%", () => {
  for (const name of GLASS_MATERIALS) {
    const want = t.material[name].blur;
    const k = kawaseFor(want);
    expect(Math.abs(kawaseSigma(k.iterations, k.offset) - want) / want).toBeLessThan(0.03);
    const level = KAWASE_LEVELS.find((l) => l.iterations === k.iterations)!;
    expect(k.offset).toBeLessThanOrEqual(level.max * 1.15);
    expect(k.expand).toBe(level.expand);
  }
});

test("heavier materials never take fewer halvings", () => {
  const by = (name: (typeof GLASS_MATERIALS)[number]) => kawaseFor(t.material[name].blur).iterations;
  expect(by("thin")).toBeLessThanOrEqual(by("regular"));
  expect(by("regular")).toBeLessThanOrEqual(by("thick"));
  expect(by("clear")).toBeLessThanOrEqual(by("backdrop"));
});

test("the header lists every material in the protocol's order", async () => {
  const xml = await Bun.file(join(import.meta.dir, "../../glass/protocol/ambrosia-glass-v1.xml")).text();
  const entries = [...xml.matchAll(/<entry name="(\w+)" value="(\d+)"/g)].map((m) => [m[1], Number(m[2])]);
  expect(entries).toEqual(GLASS_MATERIALS.map((name, i) => [name, i]));
  expect(Object.keys(t.material).sort()).toEqual([...GLASS_MATERIALS].sort());
  const header = glassTokens();
  const listed = [...header.matchAll(/^\s+\{"(\w+)", /gm)].map((m) => m[1]);
  expect(listed).toEqual([...GLASS_MATERIALS]);
});
