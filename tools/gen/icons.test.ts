// The icon theme: what every app icon must be, and that its names hold up.
import { expect, test } from "bun:test";
import * as d from "../../design/icons";
import { join } from "node:path";
import { kdeFinds, shadowed } from "./lookup";
import { ART, iconTheme, tileIconNames, tinted, type Art } from "./targets/icons";
import { ICON_THEME_ROOT } from "./targets/shared";

const root = join(import.meta.dir, "../..");
const drawn = Object.fromEntries(Object.keys(d.adopted).map((name) => [name, `<svg id="${name}"/>`]));
const art = Object.fromEntries(
  await Promise.all(Object.entries(ART).map(async ([name, path]) => [name, await Bun.file(join(root, path)).text()])),
) as Art;
const theme = iconTheme(drawn, art);
const apps = `${ICON_THEME_ROOT}/apps/scalable`;

/** Every icon in the theme (not the pointer), as folder and name. */
const all = [...Object.keys(theme.files), ...Object.keys(theme.links)]
  .filter((path) => path.startsWith(`${ICON_THEME_ROOT}/`) && path.endsWith(".svg"))
  .map((path) => path.slice(ICON_THEME_ROOT.length + 1, -".svg".length).split("/") as [string, string, string]);
const names = new Set(all.map(([, , name]) => name));

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

test("a name is drawn once in each folder, and every link has its icon", () => {
  const paths = all.map((parts) => parts.join("/"));
  expect(new Set(paths).size).toBe(paths.length);
  for (const [path, target] of Object.entries(theme.links)) {
    if (!path.endsWith(".svg")) continue;
    expect(theme.files[join(path, "..", target)]).toBeDefined();
  }
  // A folder or a kind of file isn't also an app's tile.
  for (const name of tileIconNames()) expect(all.filter(([, , n]) => n === name).length).toBe(1);
});

test("folders and files use only what Qt's SVG reader draws", () => {
  for (const [path, svg] of Object.entries(theme.files)) {
    if (!path.startsWith(`${ICON_THEME_ROOT}/`) || !path.endsWith(".svg") || path.includes("/cursors")) continue;
    for (const unsupported of ["<filter", "clip-path", "<mask", "oklch(", "<text"]) expect(svg).not.toContain(unsupported);
  }
});

test("what is drawn for 32 px and up is drawn smaller too, or is good at any size", () => {
  const index = theme.files[`${ICON_THEME_ROOT}/index.theme`]!;
  for (const context of ["places", "mimetypes"]) {
    expect(index).toContain(`[${context}/small@2x]\nSize=16\nScale=2\nMinSize=16\nMaxSize=31`);
    expect(theme.links[`${ICON_THEME_ROOT}/${context}/small@2x`]).toBe("small");
    // Nothing is only small: under KDE's rules it would be stretched to 256.
    for (const [, size, name] of all.filter(([c]) => c === context)) {
      if (size === "small") expect(names.has(name) && all.some(([c, s, n]) => c === context && s === "scalable" && n === name)).toBe(true);
    }
  }
});

test("KDE's lookup inside one theme: a missing name is cut down word by word", () => {
  const has = (...have: string[]) => (name: string) => have.includes(name);
  expect(kdeFinds("folder-new", has("folder"))).toBe("folder");
  expect(kdeFinds("folder-new", has("folder", "folder-new"))).toBe("folder-new");
  expect(kdeFinds("folder-git-symbolic", has("folder", "folder-symbolic"))).toBe("folder-symbolic");
  expect(kdeFinds("user-home-symbolic", has("user-home"))).toBe("user-home");
  expect(kdeFinds("text-x-python", has("text-x-generic"))).toBe("text-x-generic");
  expect(kdeFinds("audio-volume-high", has("audio-x-generic"))).toBe("audio-x-generic");
  expect(kdeFinds("audio-volume-high", has("audio-mpeg"))).toBeNull();
  expect(kdeFinds("package-install", has("package-x-generic"))).toBeNull();
});

test("the theme takes nothing from Breeze it doesn't mean to", async () => {
  // A whole kind of file's fallback would answer for every name that begins
  // with the kind: audio-volume-high, text-field, application-exit.
  for (const type of ["text", "application", "image", "audio", "video", "inode", "message", "model", "multipart"]) {
    expect(names.has(`${type}-x-generic`)).toBe(false);
    expect(names.has(type)).toBe(false);
  }
  // Breeze's names, with the folder each is in (breeze-icons 6.31; again with
  //   cd /usr/share/icons/breeze && find . -name '*.svg' | sed -E 's|^\./([^/]+)/.*/([^/]+)\.svg$|\1/\2|' | sort -u
  // ). One of ours may stand in for another folder, another kind of document
  // or another app's icon; for a one-color action, status or settings icon
  // only its own drawing may (folder-new-symbolic by folder-new).
  const breeze = (await Bun.file(join(import.meta.dir, "breeze-names.txt")).text()).split("\n").filter(Boolean).map((line) => line.split("/") as [string, string]);
  const context = new Map<string, Set<string>>();
  for (const [where, name] of breeze) context.set(name, (context.get(name) ?? new Set()).add(where));
  const loose = new Set(["places", "mimetypes", "apps"]);
  // An open folder and a saved search: the folder's glyph will do.
  const accepted = new Set(["folder-open-symbolic", "folder-saved-search-symbolic"]);
  const wrong = shadowed(names, context.keys()).filter(
    ([name, found]) => ![...context.get(name)!].every((where) => loose.has(where)) && found !== name.replace(/-symbolic$/, "") && !accepted.has(name),
  );
  expect(wrong).toEqual([]);
});

test("a folder's color moves its blues and leaves its paper", () => {
  // The front's middle blue becomes the color itself; white stays white.
  expect(tinted(`<stop stop-color="#63c4f0"/><stop stop-color="#ffffff"/>`, "#e6524c")).toBe(`<stop stop-color="#e6524c"/><stop stop-color="#ffffff"/>`);
  const red = theme.files[`${ICON_THEME_ROOT}/places/scalable/folder-red.svg`]!;
  expect(red).not.toContain("#63c4f0");
  expect(red).toContain("#ffffff");
});
