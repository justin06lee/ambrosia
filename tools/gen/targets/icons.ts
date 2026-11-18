// The "Ambrosia" icon theme, from design/icons.ts: our app icons under the
// names the installed apps ask for, over Breeze for everything not drawn yet.
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

/** An icon's name as part of a CSS variable's: dots would end the name. */
export const cssName = (name: string) => name.replace(/\./g, "-");

/** KDE reads its default icon sizes from the theme in use; these are
 *  Breeze's, so nothing changes size when the theme does. FollowsColorScheme
 *  keeps Breeze's one-color icons following light and dark. */
const index = `# ${HEADER.replace("tokens.ts", "icons.ts and cursors.ts")}
[Icon Theme]
Name=${ICON_THEME}
Comment=Ambrosia's app icons and pointer, over Breeze
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
Directories=${APPS}

[${APPS}]
Size=128
MinSize=16
MaxSize=1024
Context=Applications
Type=Scalable
`;

export interface IconTheme {
  files: Record<string, string>;
  links: Record<string, string>;
}

/** `drawn` is the art that exists already (assets/icons/), by name. */
export function iconTheme(drawn: Record<string, string>): IconTheme {
  const files: IconTheme["files"] = { [`${ICON_THEME_ROOT}/index.theme`]: index };
  const links: IconTheme["links"] = {};
  const shown: [string, string][] = [];
  const add = (names: string[], svg: string) => {
    const [name, ...others] = names;
    files[`${ICON_THEME_ROOT}/${APPS}/${name}.svg`] = svg;
    for (const other of others) links[`${ICON_THEME_ROOT}/${APPS}/${other}.svg`] = `${name}.svg`;
    shown.push([name!, svg]);
  };

  for (const [name, others] of Object.entries(d.adopted)) add([name, ...others], drawn[name]!);
  for (const icon of Object.values(d.appIcons)) add(icon.names, iconSvg(icon));

  files["icons/sheet.html"] = sheetHtml(shown);
  files["web/icons.css"] =
    `/* ${HEADER} */\n/* The app icons (design/icons.ts, assets/icons/) as pictures:\n   \`background-image: var(--amb-icon-terminal)\`. */\n:root {\n` +
    shown.map(([name, svg]) => `  --amb-icon-${cssName(name)}: url("data:image/svg+xml;base64,${Buffer.from(svg).toString("base64")}");`).join("\n") +
    `\n}\n`;
  return { files, links };
}

/** Every app icon on one page: large, at the Dock's size on a strip of light
 *  and of dark glass, and small as a list shows them. */
function sheetHtml(icons: [string, string][]): string {
  const src = (svg: string) => `data:image/svg+xml;base64,${Buffer.from(svg).toString("base64")}`;
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
`;
}
