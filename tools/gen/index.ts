// Generates every theme target from design/tokens.ts into dist/.

import { cp, mkdir, rm } from "node:fs/promises";
import { dirname, join } from "node:path";
import * as t from "../../design/tokens";
import { toCss } from "./color";
import { resolve } from "./resolve";
import { fontEnvironment, fontconfig } from "./targets/fontconfig";
import { gtk3, gtk4, titlebuttonGlyphs } from "./targets/gtk";
import { kdecoration } from "./targets/kdecoration";
import { kde, kdeglobals } from "./targets/kde";
import { qml, qmldir } from "./targets/qml";
import { web } from "./targets/web";

const root = join(import.meta.dir, "../..");
const dist = join(root, "dist");
const r = resolve();

const files: Record<string, string> = {
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
  "fontconfig/50-ambrosia.conf": fontconfig(),
  "environment.d/50-ambrosia-fonts.conf": fontEnvironment(),
  // Everything resolved, for consumers without a dedicated target (the
  // compositor effects, scripts). Colors are CSS strings.
  "tokens.json": JSON.stringify(
    { ...t, tracking: undefined, resolved: r },
    (_, v) => (v && typeof v === "object" && "r" in v && "a" in v && !Array.isArray(v) ? toCss(v) : v),
    2,
  ),
};

await rm(dist, { recursive: true, force: true });
for (const [path, content] of Object.entries(files)) {
  const out = join(dist, path);
  await mkdir(dirname(out), { recursive: true });
  await Bun.write(out, content);
}

const fonts = join(root, "node_modules/@fontsource-variable");
await mkdir(join(dist, "web/fonts"), { recursive: true });
for (const file of ["inter/files/inter-latin-opsz-normal.woff2", "jetbrains-mono/files/jetbrains-mono-latin-wght-normal.woff2"]) {
  await cp(join(fonts, file), join(dist, "web/fonts", file.split("/").pop()!));
}

console.log(`ambrosia: generated ${Object.keys(files).length} files into dist/`);
for (const path of Object.keys(files)) console.log(`  ${path}`);
