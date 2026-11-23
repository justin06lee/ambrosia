import { expect, test } from "bun:test";
import { plymouth, PLYMOUTH_THEME } from "./targets/plymouth";

const files = plymouth();
const dir = `plymouth/${PLYMOUTH_THEME}`;
const script = files[`${dir}/${PLYMOUTH_THEME}.script`] as string;
const descriptor = files[`${dir}/${PLYMOUTH_THEME}.plymouth`] as string;

test("the descriptor names the script plugin and files the theme has", () => {
  expect(descriptor).toContain("ModuleName=script");
  const scriptFile = descriptor.match(/^ScriptFile=(.+)$/m)![1]!;
  const imageDir = descriptor.match(/^ImageDir=(.+)$/m)![1]!;
  expect(imageDir).toBe(`/usr/share/plymouth/themes/${PLYMOUTH_THEME}`);
  expect(files[`${dir}/${scriptFile.slice(imageDir.length + 1)}`]).toBe(script);
});

test("every picture the script asks for is there at every scale it may pick", () => {
  const names = [...script.matchAll(/picture\("([a-z]+)"/g)].map((m) => m[1]!);
  expect(names.sort()).toEqual(["dot", "field", "fill", "mark", "track"]);
  const top = Number(script.match(/if \(drawn > (\d+)\)/)![1]);
  for (const name of names) {
    for (let scale = 1; scale <= top; scale++) {
      const png = files[`${dir}/${name}-${scale}.png`] as Uint8Array;
      expect(png, `${name}-${scale}.png`).toBeDefined();
      // A PNG's width is the four bytes at 16: each scale is that many times the first.
      const width = (p: Uint8Array) => new DataView(p.buffer, p.byteOffset).getUint32(16);
      expect(width(png)).toBe(width(files[`${dir}/${name}-1.png`] as Uint8Array) * scale);
    }
  }
});

test("the script's braces and brackets pair up", () => {
  for (const [open, close] of ["{}", "()", "[]"]) {
    expect(script.split(open!).length, open).toBe(script.split(close!).length);
  }
});
