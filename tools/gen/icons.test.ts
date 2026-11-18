// The icon theme: what every app icon must be, and that its names hold up.
import { expect, test } from "bun:test";
import * as d from "../../design/icons";
import { iconTheme, tileIconNames } from "./targets/icons";
import { ICON_THEME_ROOT } from "./targets/shared";

const drawn = Object.fromEntries(Object.keys(d.adopted).map((name) => [name, `<svg id="${name}"/>`]));
const theme = iconTheme(drawn);
const apps = `${ICON_THEME_ROOT}/apps/scalable`;

test("no name is claimed twice, and every link points at an icon", () => {
  const names = tileIconNames();
  expect(new Set(names).size).toBe(names.length);
  for (const name of names) {
    const path = `${apps}/${name}.svg`;
    const target = theme.links[path];
    expect(theme.files[target ? `${apps}/${target}` : path]).toBeDefined();
  }
});

test("app icons use only what Qt's SVG reader draws, inside the tile", () => {
  for (const icon of Object.values(d.appIcons)) {
    const svg = theme.files[`${apps}/${icon.names[0]}.svg`]!;
    for (const unsupported of ["<filter", "clip-path", "<mask", "oklch("]) expect(svg).not.toContain(unsupported);
    // Every coordinate in the art stays on the grid's tile (a turned group's are its own).
    const plain = icon.art.replace(/<g transform[\s\S]*?<\/g>/g, "");
    for (const [, x, y] of plain.matchAll(/\b(?:x|cx)="([\d.]+)"[^>]*?\b(?:y|cy)="([\d.]+)"/g)) {
      for (const v of [+x!, +y!]) {
        expect(v).toBeGreaterThanOrEqual(d.tile.at);
        expect(v).toBeLessThanOrEqual(d.tile.at + d.tile.side);
      }
    }
  }
});

test("the theme's index lists its folder and falls back to Breeze", () => {
  const index = theme.files[`${ICON_THEME_ROOT}/index.theme`]!;
  expect(index).toContain("Directories=apps/scalable");
  expect(index).toContain("[apps/scalable]");
  expect(index).toMatch(/^Inherits=breeze,breeze_cursors,hicolor$/m);
  // Without this KDE stops recoloring Breeze's one-color icons in dark mode.
  expect(index).toContain("FollowsColorScheme=true");
});

test("icons drawn before the theme keep their art", () => {
  for (const name of Object.keys(d.adopted)) expect(theme.files[`${apps}/${name}.svg`]).toBe(drawn[name]!);
});
