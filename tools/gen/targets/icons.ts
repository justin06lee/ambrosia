// The "Ambrosia" icon theme, from design/icons.ts: our app icons, folders and
// kinds of file under the names apps ask for, over Breeze for everything not
// drawn yet.
// The pointer (targets/cursors.ts) lives in the same theme folder, so this
// file writes the index both go by.

import * as d from "../../../design/icons";
import { HEADER, ICON_THEME, ICON_THEME_ROOT, squircle } from "./shared";

const TILE = squircle(d.tile.at, d.tile.at, d.tile.side);
const [top, bottom] = [d.tile.at, d.tile.at + d.tile.side];

/** One app icon: the tile, what's drawn on it, then the tile's edge: a hair
 *  of shade so a white tile holds on a white ground, and the rim of light
 *  that's brightest along the top. */
export const iconSvg = (icon: d.AppIcon) => `<svg xmlns="http://www.w3.org/2000/svg" width="${d.grid}" height="${d.grid}" viewBox="0 0 ${d.grid} ${d.grid}">
<!-- ${HEADER.replace("tokens.ts", "icons.ts")} -->
<defs>
<linearGradient id="tile" x1="0" y1="${top}" x2="0" y2="${bottom}" gradientUnits="userSpaceOnUse"><stop offset="0" stop-color="${icon.tile[0]}"/><stop offset="1" stop-color="${icon.tile[1]}"/></linearGradient>
<linearGradient id="rim" x1="0" y1="${top}" x2="0" y2="${bottom}" gradientUnits="userSpaceOnUse"><stop offset="0" stop-color="#fff" stop-opacity="0.5"/><stop offset="0.5" stop-color="#fff" stop-opacity="0.12"/><stop offset="1" stop-color="#fff" stop-opacity="0.25"/></linearGradient>
</defs>
<path d="${TILE}" fill="url(#tile)"/>
${icon.art}
<path d="${TILE}" fill="none" stroke="#000" stroke-opacity="0.12" stroke-width="1"/>
<path d="${squircle(d.tile.at + 1, d.tile.at + 1, d.tile.side - 2)}" fill="none" stroke="url(#rim)" stroke-width="2"/>
</svg>
`;

/** Every name in the theme that is drawn on a whole tile: the Dock shows
 *  these larger, so the tile and not its margin fills the icon's place. */
export const tileIconNames = () => [
  ...Object.values(d.appIcons).flatMap((icon) => icon.names),
  ...Object.entries(d.adopted).flatMap(([name, others]) => [name, ...others]),
];

const APPS = "apps/scalable";

/** The theme's folders. Folders and files have a drawing for 32 px and up and
 *  another under it, where a special folder is its line glyph and a page gets
 *  a darker edge; `scaled` gives the small ones the @2x and @3x folders a
 *  doubled screen asks for by the small size's name. `lines` are one-color
 *  glyphs, good at any size. */
const DIRS = [
  { path: APPS, context: "Applications", size: 128, min: 16, max: 1024 },
  { path: "places/scalable", context: "Places", size: 64, min: 32, max: 1024 },
  { path: "places/small", context: "Places", size: 16, min: 16, max: 31, scaled: true },
  { path: "places/symbolic", context: "Places", size: 16, min: 8, max: 512 },
  { path: "actions/symbolic", context: "Actions", size: 16, min: 8, max: 512 },
  { path: "mimetypes/scalable", context: "MimeTypes", size: 64, min: 32, max: 1024 },
  { path: "mimetypes/small", context: "MimeTypes", size: 16, min: 16, max: 31, scaled: true },
] as const;
const SCALES = [2, 3];
const [PLACES, PLACES_SMALL, PLACES_SYMBOLIC, ACTIONS, MIMES, MIMES_SMALL] = DIRS.slice(1).map((dir) => dir.path) as [string, string, string, string, string, string];

const dirEntry = (dir: (typeof DIRS)[number], scale = 1) => `[${dir.path}${scale > 1 ? `@${scale}x` : ""}]
Size=${dir.size}${scale > 1 ? `\nScale=${scale}` : ""}
MinSize=${dir.min}
MaxSize=${dir.max}
Context=${dir.context}
Type=Scalable
`;
const scaledDirs = DIRS.filter((dir) => "scaled" in dir).flatMap((dir) => SCALES.map((scale) => [dir, scale] as const));

/** An icon's name as part of a CSS variable's: dots would end the name. */
export const cssName = (name: string) => name.replace(/\./g, "-");

/** KDE reads its default icon sizes from the theme in use; these are
 *  Breeze's own (its commonthemeinfo.theme.in), so nothing changes size when
 *  the theme does. FollowsColorScheme keeps Breeze's one-color icons
 *  following light and dark. Our one folder serves every size, so the app
 *  icons are in color even where Breeze's small ones are one-color. */
const index = `# ${HEADER.replace("tokens.ts", "icons.ts and cursors.ts")}
[Icon Theme]
Name=${ICON_THEME}
Comment=Ambrosia's app icons, folders, files and pointer, over Breeze
Inherits=breeze,breeze_cursors,hicolor
Example=${Object.values(d.appIcons)[0]!.names[0]}
FollowsColorScheme=true
DisplayDepth=32
DesktopDefault=48
DesktopSizes=16,22,32,48,64,128,256
ToolbarDefault=22
ToolbarSizes=16,22,32,48
MainToolbarDefault=22
MainToolbarSizes=16,22,32,48
SmallDefault=16
SmallSizes=16,22,32,48
PanelDefault=48
PanelSizes=16,22,32,48,64,128,256
DialogDefault=32
DialogSizes=16,22,32,48,64,128,256
KDE-Extensions=.svg
Directories=${DIRS.map((dir) => dir.path).join(",")}
ScaledDirectories=${scaledDirs.map(([dir, scale]) => `${dir.path}@${scale}x`).join(",")}

${DIRS.map((dir) => dirEntry(dir)).join("\n")}
${scaledDirs.map(([dir, scale]) => dirEntry(dir, scale)).join("\n")}`;

/** Art drawn outside design/ that the theme builds on: Files' folder, page,
 *  small page and song tile (files/art/), the Dock's Trash (shell/). */
export const ART = {
  folder: "files/art/folder.svg",
  document: "files/art/document.svg",
  "document-small": "files/art/document-small.svg",
  audio: "files/art/audio.svg",
  "trash-empty": "shell/trash-empty.svg",
  "trash-full": "shell/trash-full.svg",
} as const;
export type Art = Record<keyof typeof ART, string>;

const NOTE = `<!-- ${HEADER.replace("tokens.ts", "icons.ts and the art it names")} -->`;
/** A drawing with more put on top of it (and, for `without`, a part taken
 *  out first: it has to be there). */
function onto(svg: string, more: string, without?: RegExp): string {
  if (without) {
    if (!without.test(svg)) throw new Error(`icons: the art no longer has ${without}`);
    svg = svg.replace(without, "");
  }
  return svg.replace(/(<svg[^>]*>)/, `$1\n${NOTE}`).replace("</svg>", `${more}\n</svg>`);
}

const ROUND = `stroke-linecap="round" stroke-linejoin="round"`;
/** A line glyph as an icon of one color. KDE swaps the style block for the
 *  color scheme's (FollowsColorScheme), so it is the text's color there; the
 *  gray written here is what a toolkit that doesn't sees, on light or dark. */
export const glyphSvg = (d: string, filled = false) => `<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24">
${NOTE}
<defs><style type="text/css" id="current-color-scheme">.ColorScheme-Text { color:#8a8a8e; }</style></defs>
<path class="ColorScheme-Text" d="${d}" ${filled ? `fill="currentColor" fill-rule="evenodd"` : `fill="none" stroke="currentColor" stroke-width="1.5" ${ROUND}`}/>
</svg>
`;

/** A folder with its glyph pressed into the front: a shade darker than the
 *  front, with a line of light under it. The front is 117 by 77 around
 *  64, 70 on the folder's 128 grid; the glyph is 2.1 times its 24. */
const pressed = (folder: string, glyph: d.Glyph) =>
  onto(
    folder,
    [["45.9", "#ffffff", "0.3"], ["44.8", "#1671ab", "0.55"]]
      .map(([y, color, opacity]) => `<path transform="translate(38.8 ${y}) scale(2.1)" d="${d.glyphs[glyph]}" fill="none" stroke="${color}" stroke-opacity="${opacity}" stroke-width="1.6" ${ROUND}/>`)
      .join("\n"),
  );

type HSL = [number, number, number];
function hsl(hex: string): HSL {
  const [r, g, b] = [1, 3, 5].map((at) => parseInt(hex.slice(at, at + 2), 16) / 255) as [number, number, number];
  const [max, min] = [Math.max(r, g, b), Math.min(r, g, b)];
  const [l, c] = [(max + min) / 2, max - min];
  if (c === 0) return [0, 0, l];
  const h = max === r ? ((g - b) / c + 6) % 6 : max === g ? (b - r) / c + 2 : (r - g) / c + 4;
  return [h / 6, c / (1 - Math.abs(2 * l - 1)), l];
}
function hex([h, s, l]: HSL): string {
  const c = (1 - Math.abs(2 * l - 1)) * s;
  const channel = (n: number) => {
    const k = (n + h * 12) % 12;
    return Math.round(255 * (l - (c / 2) * Math.max(-1, Math.min(k - 3, 9 - k, 1))));
  };
  return `#${[0, 8, 4].map((n) => channel(n).toString(16).padStart(2, "0")).join("")}`;
}
const clamp = (v: number) => Math.max(0, Math.min(1, v));

/** The folder in another color, as Files tints a tagged one (FolderProvider
 *  in files/src/main.cpp): its blues move to the color's hue, the front's
 *  middle blue becoming the color and the rest keeping their steps of light
 *  around it; the paper stays white. */
export function tinted(folder: string, color: string): string {
  const [middle, tint] = [hsl("#63c4f0"), hsl(color)];
  return folder.replace(/#[0-9a-fA-F]{6}/g, (found) => {
    const c = hsl(found);
    return c[1] > 0.3 ? hex([tint[0], clamp((tint[1] * c[1]) / middle[1]), clamp(tint[2] + 0.8 * (c[2] - middle[2]))]) : found;
  });
}

/** The lines Files' small page is drawn with, and the notes on its song tile:
 *  taken out where a kind brings its own mark. */
const SMALL_LINES = /\s*<path d="M5 6\.6h6[^>]*\/>/;
const NOTES = /\s*<g fill="#cdcdcd">[\s\S]*?<\/g>/;

const fileSvg = (kind: d.FileKind, art: Art) =>
  kind.on === "song" ? onto(art.audio, "") : kind.on === "tile" ? onto(art.audio, kind.art, NOTES) : onto(art.document, kind.art);

export interface IconTheme {
  files: Record<string, string>;
  links: Record<string, string>;
}

/** `drawn` is the app art that exists already (assets/icons/), by name; `art`
 *  is what folders and files are built on. */
export function iconTheme(drawn: Record<string, string>, art: Art): IconTheme {
  const files: IconTheme["files"] = { [`${ICON_THEME_ROOT}/index.theme`]: index };
  const links: IconTheme["links"] = {};
  const put = (dir: string, names: string[], svg: string) => {
    const [name, ...others] = names;
    files[`${ICON_THEME_ROOT}/${dir}/${name}.svg`] = svg;
    for (const other of others) links[`${ICON_THEME_ROOT}/${dir}/${other}.svg`] = `${name}.svg`;
  };
  const shown: [string, string][] = [];
  const add = (names: string[], svg: string) => {
    put(APPS, names, svg);
    shown.push([names[0]!, svg]);
  };

  for (const [name, others] of Object.entries(d.adopted)) add([name, ...others], drawn[name]!);
  for (const icon of Object.values(d.appIcons)) add(icon.names, iconSvg(icon));

  // Folders: the plain one at every size; a special one with its glyph
  // pressed in, and under 32 px the glyph alone.
  const others: Shown[] = [];
  for (const place of d.places) {
    const large = place.glyph ? pressed(art.folder, place.glyph) : onto(art.folder, "");
    const small = place.glyph ? glyphSvg(d.glyphs[place.glyph]) : undefined;
    put(PLACES, place.names, large);
    if (small) put(PLACES_SMALL, place.names, small);
    others.push({ name: place.names[0]!, large, small });
  }
  for (const [name, color] of Object.entries(d.folderTints)) {
    const large = tinted(onto(art.folder, ""), color);
    put(PLACES, [`folder-${name}`], large);
    others.push({ name: `folder-${name}`, large });
  }
  for (const [name, which] of Object.entries(d.trash)) {
    const [large, small] = [onto(art[which], ""), glyphSvg(d.glyphs.trash)];
    put(PLACES, [name], large);
    put(PLACES_SMALL, [name], small);
    others.push({ name, large, small });
  }
  const symbol = glyphSvg(d.folderSymbol, true);
  put(PLACES_SYMBOLIC, ["folder-symbolic", "inode-directory-symbolic"], symbol);
  others.push({ name: "folder-symbolic", small: symbol });
  for (const action of d.folderActions) {
    const small = glyphSvg(d.glyphs[action.glyph]);
    put(ACTIONS, action.names, small);
    others.push({ name: action.names[0]!, small });
  }

  // Kinds of file: the page with its mark, and the small page under 32 px.
  for (const [name, kind] of Object.entries(d.fileKinds)) {
    const large = fileSvg(kind, art);
    const small =
      kind.small === undefined
        ? undefined
        : kind.on === "page"
          ? onto(art["document-small"], kind.small, SMALL_LINES)
          : `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 16 16">\n${NOTE}\n${d.smallTile}${kind.small}\n</svg>\n`;
    put(MIMES, kind.names, large);
    if (small) put(MIMES_SMALL, kind.names, small);
    others.push({ name: `${name}: ${kind.names[0]}`, large, small });
  }

  // A doubled screen asks for the small size's own @2x folder: the same files.
  for (const [dir, scale] of scaledDirs) links[`${ICON_THEME_ROOT}/${dir.path}@${scale}x`] = dir.path.split("/").pop()!;

  files["icons/sheet.html"] = sheetHtml(shown, others);
  files["web/icons.css"] =
    `/* ${HEADER} */\n/* The app icons (design/icons.ts, assets/icons/) as pictures:\n   \`background-image: var(--amb-icon-terminal)\`. */\n:root {\n` +
    shown.map(([name, svg]) => `  --amb-icon-${cssName(name)}: url("data:image/svg+xml;base64,${Buffer.from(svg).toString("base64")}");`).join("\n") +
    `\n}\n`;
  return { files, links };
}

/** A folder, a kind of file or a glyph on the sheet: its drawing for 32 px and
 *  up, and the one under it. */
type Shown = { name: string; large?: string; small?: string };

/** Every icon on one page. App icons: large, at the Dock's size on a strip of
 *  light and of dark glass, and small as a list shows them. Folders and files:
 *  each drawing at the sizes it is used at, the small ones on light and dark. */
function sheetHtml(icons: [string, string][], others: Shown[]): string {
  const src = (svg: string) => `data:image/svg+xml;base64,${Buffer.from(svg).toString("base64")}`;
  const img = (svg: string, size: number) => `<img src="${src(svg)}" width="${size}" height="${size}">`;
  const other = ({ name, large, small }: Shown) => `<figure>${large ? img(large, 96) : `<div class="none"></div>`}
  <div class="small">${large ? img(large, 48) + img(large, 32) : ""}${[22, 16].map((size) => img(small ?? large!, size)).join("")}</div>
  <div class="small night">${[22, 16].map((size) => img(small ?? large!, size)).join("")}</div>
  <figcaption>${name}</figcaption></figure>`;
  // The Dock shows a tile icon so its tile, not its margin, is the icon's size.
  const grown = Math.round(56 * (d.grid / d.tile.side));
  const strip = (ground: string) =>
    `<div class="dock ${ground}">${icons.map(([, svg]) => `<span><img src="${src(svg)}" width="${grown}" height="${grown}"></span>`).join("")}</div>`;
  return `<!doctype html>
<!-- ${HEADER} -->
<meta charset="utf-8">
<title>Ambrosia: app icons</title>
<style>
  body { margin: 20px; font: 12px/1.3 Inter, system-ui, sans-serif; background: #f2f1ef; color: #222; }
  main { display: grid; grid-template-columns: repeat(auto-fill, 150px); gap: 14px 16px; }
  figure { margin: 0; text-align: center; }
  figure > img { display: block; margin: 0 auto; }
  .small { display: flex; justify-content: center; align-items: end; gap: 10px; margin: 2px 0 4px; }
  figcaption { font-weight: 600; }
  .dock { display: inline-flex; gap: 10px; padding: 10px 12px; margin: 22px 20px 0 0; border-radius: 26px; }
  .dock span { width: 56px; height: 56px; display: grid; place-items: center; }
  .dock.light { background: linear-gradient(135deg, #f1d3a2, #d9a9c9); box-shadow: inset 0 0 0 1px #fff8; }
  .dock.dark { background: linear-gradient(135deg, #3a2a4a, #20222e); box-shadow: inset 0 0 0 1px #fff2; }
  h2 { font-size: 13px; margin: 28px 0 12px; }
  .none { height: 96px; }
  .night { background: #1e1e1e; border-radius: 6px; padding: 5px 0; }
</style>
<main>
${icons
  .map(
    ([name, svg]) => `<figure><img src="${src(svg)}" width="128" height="128">
  <div class="small"><img src="${src(svg)}" width="48" height="48"><img src="${src(svg)}" width="32" height="32"><img src="${src(svg)}" width="20" height="20"></div>
  <figcaption>${name}</figcaption></figure>`,
  )
  .join("\n")}
</main>
${strip("light")}${strip("dark")}
<h2>Folders and files</h2>
<main>
${others.map(other).join("\n")}
</main>
`;
}
