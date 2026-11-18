// The pointer, from design/cursors.ts, as part of the "Ambrosia" icon theme
// (targets/icons.ts writes the theme's index): Xcursor files for the clients
// that load their own pointer, the same shapes as SVGs for KWin
// (cursors_scalable, which it draws at any size), CSS cursors for the preview,
// and a sheet to look them all over on.

import { Resvg } from "@resvg/resvg-js";
import * as c from "../../../design/cursors";
import { toHex } from "../color";
import type { Resolved } from "../resolve";
import { xcursor, type CursorImage } from "../xcursor";
import { HEADER, ICON_THEME_ROOT } from "./shared";

const SVG_OPEN = `<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="${c.canvas}" height="${c.canvas}" viewBox="0 0 ${c.canvas} ${c.canvas}">`;
const render = (svg: string, width: number) =>
  new Resvg(svg, { fitTo: { mode: "width", value: width }, font: { loadSystemFonts: false } }).render();

/** A group's whole outline in one color: what its rim paints, and what casts
 *  the shadow. */
const outline = (g: c.Group, color: string) =>
  (g.fills ?? [])
    .map((d) =>
      g.rimWidth > 0
        ? `<path d="${d}" fill="${color}" stroke="${color}" stroke-width="${g.rimWidth * 2}" stroke-linejoin="round"/>`
        : `<path d="${d}" fill="${color}"/>`,
    )
    .concat(
      (g.lines ?? []).map(
        ({ d, width }) =>
          `<path d="${d}" fill="none" stroke="${color}" stroke-width="${width + g.rimWidth * 2}" stroke-linecap="round" stroke-linejoin="round"/>`,
      ),
    )
    .join("");

const inked = (g: c.Group) =>
  (g.fills ?? []).map((d) => `<path d="${d}" fill="${g.ink}"/>`).join("") +
  (g.lines ?? [])
    .map(({ d, width }) => `<path d="${d}" fill="none" stroke="${g.ink}" stroke-width="${width}" stroke-linecap="round" stroke-linejoin="round"/>`)
    .join("") +
  (g.over ?? "");

const blurred = (groups: c.Group[]) =>
  `<g filter="url(#shadow)" opacity="${c.shadow.opacity}" transform="translate(0 ${c.shadow.dy})">${groups.map((g) => outline(g, "#000")).join("")}</g>`;
const FILTER = `<defs><filter id="shadow" filterUnits="userSpaceOnUse" x="0" y="0" width="${c.canvas}" height="${c.canvas}"><feGaussianBlur stdDeviation="${c.shadow.blur}"/></filter></defs>`;

/** The shadow as a picture inside the SVG: Qt's SVG reader, which KWin draws
 *  pointers with, has no blur. Three times the canvas, so it stays soft at
 *  the largest pointer sizes. */
const shadowImages = new Map<string, string>();
function shadowImage(groups: c.Group[]): string {
  const key = blurred(groups);
  let image = shadowImages.get(key);
  if (!image) {
    const png = render(`${SVG_OPEN}${FILTER}${key}</svg>`, c.canvas * 3).asPng();
    image = `<image width="${c.canvas}" height="${c.canvas}" xlink:href="data:image/png;base64,${Buffer.from(png).toString("base64")}"/>`;
    shadowImages.set(key, image);
  }
  return image;
}

/** One frame as an SVG. Browsers blur the shadow themselves; everything else
 *  gets it as a picture. */
export function frameSvg(groups: c.Group[], shadow: "image" | "filter" = "image"): string {
  const under = shadow === "image" ? shadowImage(groups) : FILTER + blurred(groups);
  return `${SVG_OPEN}${under}${groups.map((g) => (g.rimWidth > 0 ? outline(g, g.rim) : "") + inked(g)).join("")}</svg>\n`;
}

export function pointerColors(r: Resolved): c.Colors {
  const light = r.modes.light;
  return { copy: toHex(light.palette[c.borrowed.copy]!), wheel: c.borrowed.wheel.map((name) => toHex(light.accents[name]!.bg)) };
}

export interface CursorTheme {
  /** Paths under dist/, text or bytes. */
  files: Record<string, string | Uint8Array>;
  /** Symlinks under dist/: the other names a shape goes by. */
  links: Record<string, string>;
}

export function cursorTheme(r: Resolved): CursorTheme {
  const pointers = c.pointers(pointerColors(r));
  // A shape not drawn here yet comes from Breeze (the theme's Inherits)
  // rather than X's own.
  const root = ICON_THEME_ROOT;
  const files: CursorTheme["files"] = {};
  const links: CursorTheme["links"] = {};
  const sheet: SheetEntry[] = [];
  const css: string[] = [];

  for (const [name, cursor] of Object.entries(pointers)) {
    const svgs = cursor.frames.map((groups) => frameSvg(groups));
    const moving = svgs.length > 1;
    const delay = moving ? (cursor.delay ?? 0) : 0;

    const images: CursorImage[] = [];
    for (const size of c.sizes) {
      const scale = size / c.nominal;
      for (const svg of svgs) {
        const { width, height, pixels } = render(svg, Math.round(c.canvas * scale));
        images.push({
          size, width, height, delay, pixels,
          xhot: Math.round(cursor.hot[0] * scale),
          yhot: Math.round(cursor.hot[1] * scale),
        });
      }
    }
    files[`${root}/cursors/${name}`] = xcursor(images);

    const frameName = (i: number) => (moving ? `${name}-${String(i + 1).padStart(2, "0")}.svg` : `${name}.svg`);
    svgs.forEach((svg, i) => (files[`${root}/cursors_scalable/${name}/${frameName(i)}`] = svg));
    files[`${root}/cursors_scalable/${name}/metadata.json`] =
      JSON.stringify(
        svgs.map((_, i) => ({
          filename: frameName(i),
          hotspot_x: cursor.hot[0],
          hotspot_y: cursor.hot[1],
          nominal_size: c.nominal,
          ...(moving ? { delay } : {}),
        })),
        null,
        4,
      ) + "\n";

    for (const alias of cursor.aliases) {
      links[`${root}/cursors/${alias}`] = name;
      links[`${root}/cursors_scalable/${alias}`] = name;
    }

    const web = `data:image/svg+xml;base64,${Buffer.from(frameSvg(cursor.frames[0]!, "filter")).toString("base64")}`;
    css.push(
      `  --amb-pointer-${name}: url("${web}");`,
      `  --amb-cursor-${name}: var(--amb-pointer-${name}) ${Math.round(cursor.hot[0])} ${Math.round(cursor.hot[1])}, ${name};`,
    );
    sheet.push({ name, cursor, svgs, aliases: cursor.aliases.length });
  }

  files["web/cursors.css"] =
    `/* ${HEADER} */\n/* The pointer's shapes (design/cursors.ts). --amb-cursor-* is the shape with\n   its hotspot and the browser's own as a fallback, for \`cursor:\`;\n   --amb-pointer-* is its picture alone. */\n:root {\n${css.join("\n")}\n}\n`;
  files["cursors/sheet.html"] = sheetHtml(sheet);
  return { files, links };
}

// The sheet -------------------------------------------------------------------------------

type SheetEntry = { name: string; cursor: c.Cursor; svgs: string[]; aliases: number };

/** Every pointer on one page: the pixels that go into the Xcursor file at the
 *  size of a plain screen, on light, dark and mid grounds, then enlarged with
 *  the hotspot marked. A moving one shows a different frame on each ground. */
function sheetHtml(entries: SheetEntry[]): string {
  const png = (svg: string, width: number) => `data:image/png;base64,${Buffer.from(render(svg, width).asPng()).toString("base64")}`;
  const cell = ({ name, cursor, svgs, aliases }: SheetEntry) => {
    const shown = svgs.length > 1 ? [0, Math.floor(svgs.length / 3), Math.floor((svgs.length * 2) / 3)] : [0];
    const big = 4;
    const [hx, hy] = cursor.hot;
    return `<figure>
  <div class="grounds">${["light", "mid", "dark"].map((g, at) => `<span class="${g}"><img src="${png(svgs[shown[at] ?? 0]!, c.canvas)}" width="${c.canvas}" height="${c.canvas}"></span>`).join("")}</div>
  <div class="big" style="width:${c.canvas * big}px;height:${c.canvas * big}px">
    <img src="${png(svgs[0]!, c.canvas * big)}" width="${c.canvas * big}" height="${c.canvas * big}">
    <i style="left:${hx * big}px;top:${hy * big}px"></i>
  </div>
  <figcaption>${name}<small>${cursor.frames.length > 1 ? `${cursor.frames.length} frames · ` : ""}${aliases} other names</small></figcaption>
</figure>`;
  };
  return `<!doctype html>
<!-- ${HEADER} -->
<meta charset="utf-8">
<title>Ambrosia: the pointer</title>
<style>
  body { margin: 20px; font: 12px/1.3 Inter, system-ui, sans-serif; background: #f2f1ef; color: #222; }
  main { display: grid; grid-template-columns: repeat(auto-fill, 128px); gap: 18px 20px; }
  figure { margin: 0; }
  .grounds { display: flex; height: 40px; border-radius: 8px 8px 0 0; overflow: hidden; }
  .grounds span { flex: 1; display: flex; align-items: center; justify-content: center; }
    .light { background: #fff; } .mid { background: linear-gradient(135deg, #e0a95b, #7a4a8c); } .dark { background: #1c1b1a; }
  .big { position: relative; background: repeating-conic-gradient(#fff 0 25%, #e9e8e6 0 50%) 0 0 / 16px 16px; border-radius: 0 0 8px 8px; }
  .big i { position: absolute; width: 9px; height: 9px; margin: -5px 0 0 -5px; border: 1px solid #f0f; border-radius: 50%; box-shadow: 0 0 0 1px #fff8; }
  figcaption { margin-top: 6px; font-weight: 600; }
  small { display: block; font-weight: 400; color: #777; }
</style>
<main>
${entries.map(cell).join("\n")}
</main>
`;
}
