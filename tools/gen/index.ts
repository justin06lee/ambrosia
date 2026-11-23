// Generates every theme target from design/tokens.ts into dist/.

import { cp, mkdir, rm, symlink } from "node:fs/promises";
import { dirname, join } from "node:path";
import * as t from "../../design/tokens";
import { toCss } from "./color";
import { resolve } from "./resolve";
import { adopted } from "../../design/icons";
import { cursorTheme } from "./targets/cursors";
import { ART, iconTheme, type Art } from "./targets/icons";
import { fontEnvironment, fontconfig } from "./targets/fontconfig";
import { gtk3, gtk4, titlebuttonGlyphs } from "./targets/gtk";
import { kdecoration } from "./targets/kdecoration";
import { kde, kdeglobals } from "./targets/kde";
import { plymouth } from "./targets/plymouth";
import { qml, qmldir } from "./targets/qml";
import { qstyle } from "./targets/qstyle";
import { web } from "./targets/web";

const root = join(import.meta.dir, "../..");
const dist = join(root, "dist");
const r = resolve();

const pointer = cursorTheme(r);
// The app icons drawn before the theme, which it carries under more names.
const drawn = Object.fromEntries(
  await Promise.all(Object.keys(adopted).map(async (name) => [name, await Bun.file(join(root, `assets/icons/${name}.svg`)).text()])),
);
const art = Object.fromEntries(
  await Promise.all(Object.entries(ART).map(async ([name, path]) => [name, await Bun.file(join(root, path)).text()])),
) as Art;
const icons = iconTheme(drawn, art);

const files: Record<string, string | Uint8Array> = {
  "web/tokens.css": web(r),
  "gtk-4.0/gtk.css": gtk4(r),
  "gtk-3.0/gtk-light.css": gtk3(r, "light"),
  "gtk-3.0/gtk-dark.css": gtk3(r, "dark"),
  ...Object.fromEntries(
    (["gtk-3.0", "gtk-4.0"] as const).flatMap((dir) =>
      Object.entries(titlebuttonGlyphs(dir)).map(([f, svg]) => [`${dir}/${f}`, svg]),
    ),
  ),
  "kde/AmbrosiaLight.colors": kde(r, "light"),
  "kde/AmbrosiaDark.colors": kde(r, "dark"),
  "kde/kdeglobals": kdeglobals(r),
  "qml/Ambrosia/Theme.qml": qml(r),
  "qml/Ambrosia/qmldir": qmldir,
  "kdecoration/tokens.h": kdecoration(r),
  "qstyle/tokens.h": qstyle(r),
  "fontconfig/50-ambrosia.conf": fontconfig(),
  "environment.d/50-ambrosia-fonts.conf": fontEnvironment(),
  // Everything resolved, for consumers without a dedicated target (the
  // compositor effects, scripts). Colors are CSS strings.
  "tokens.json": JSON.stringify(
    { ...t, tracking: undefined, resolved: r },
    (_, v) => (v && typeof v === "object" && "r" in v && "a" in v && !Array.isArray(v) ? toCss(v) : v),
    2,
  ),
  // The icon theme (dist/icons/Ambrosia): app icons and the pointer, a sheet
  // of each to look them over on, and the preview's CSS cursors.
  ...icons.files,
  ...pointer.files,
  // The picture while the computer starts: a Plymouth theme.
  ...plymouth(),
};

await rm(dist, { recursive: true, force: true });
for (const [path, content] of Object.entries(files)) {
  const out = join(dist, path);
  await mkdir(dirname(out), { recursive: true });
  await Bun.write(out, content);
}
// The other names an icon or a pointer goes by, as links beside it.
const links = { ...icons.links, ...pointer.links };
for (const [path, target] of Object.entries(links)) await symlink(target, join(dist, path));

const fonts = join(root, "node_modules/@fontsource-variable");
await mkdir(join(dist, "web/fonts"), { recursive: true });
for (const file of ["inter/files/inter-latin-opsz-normal.woff2", "jetbrains-mono/files/jetbrains-mono-latin-wght-normal.woff2"]) {
  await cp(join(fonts, file), join(dist, "web/fonts", file.split("/").pop()!));
}

console.log(`ambrosia: generated ${Object.keys(files).length} files into dist/`);
// The icon theme's files by the hundred would bury the rest.
const theme = Object.keys(files).filter((p) => p.startsWith("icons/Ambrosia/"));
for (const path of Object.keys(files).filter((p) => !theme.includes(p))) console.log(`  ${path}`);
console.log(`  icons/Ambrosia/ (${theme.length} files, ${Object.keys(links).length} links)`);
