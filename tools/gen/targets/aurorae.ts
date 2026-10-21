// KWin window decoration (an Aurorae SVG theme, one per mode): the titlebar,
// the window shadow and the traffic-light buttons. Aurorae draws the frame as
// a nine-slice of decoration.svg over the window plus its padding, and makes
// KWin's window shadow from what that slice paints in the padding. The frame
// is painted here pixel for pixel, with the same box-shadows the preview's
// windows use; the buttons stay vector.

import { deflateSync } from "node:zlib";
import * as t from "../../../design/tokens";
import type { Mode, ShadowLayer } from "../../../design/tokens";
import { toKde, toCss, type RGBA } from "../color";
import { flat, type Resolved } from "../resolve";
import { HEADER } from "./shared";

export const auroraeName = (mode: Mode) => (mode === "dark" ? "AmbrosiaDark" : "AmbrosiaLight");

const radius = t.radius.window;
const titlebar = t.size.titlebar.height;
const controls = t.size.windowControls;
// Shadow room around the window: the larger layer's blur past its offset.
const pad = { left: 64, right: 64, top: 40, bottom: 88 };
// How far the frame's corner pieces reach into the window, so the shadow
// fades around the corners instead of meeting the edges in a seam.
const reach = 56;
// The frame's edge pieces: tiled along their length, so any width will do.
const span = 4;
// Window borders Aurorae may add at other border sizes, painted as window.
const border = 6;

// Raster ---------------------------------------------------------------------

type Shape = { x0: number; y0: number; x1: number; y1: number; r: number };

const inside = (s: Shape, x: number, y: number) => {
  const dx = x - Math.min(Math.max(x, s.x0 + s.r), s.x1 - s.r);
  const dy = y - Math.min(Math.max(y, s.y0 + s.r), s.y1 - s.r);
  return x >= s.x0 && x <= s.x1 && y >= s.y0 && y <= s.y1 && dx * dx + dy * dy <= s.r * s.r;
};

/** Per-pixel coverage of a rounded rect, 4×4 samples a pixel. */
function cover(w: number, h: number, s: Shape): Float32Array {
  const out = new Float32Array(w * h);
  for (let y = 0; y < h; y++)
    for (let x = 0; x < w; x++) {
      let n = 0;
      for (let j = 0; j < 4; j++) for (let i = 0; i < 4; i++) if (inside(s, x + (i + 0.5) / 4, y + (j + 0.5) / 4)) n++;
      out[y * w + x] = n / 16;
    }
  return out;
}

/** Gaussian blur, σ = half the CSS blur radius, as box-shadow does. */
function blur(src: Float32Array, w: number, h: number, radiusPx: number): Float32Array {
  const sigma = radiusPx / 2;
  if (sigma <= 0) return src;
  const k = Math.ceil(sigma * 3);
  const kernel = Array.from({ length: 2 * k + 1 }, (_, i) => Math.exp(-((i - k) ** 2) / (2 * sigma * sigma)));
  const sum = kernel.reduce((a, b) => a + b);
  const weights = kernel.map((v) => v / sum);
  const pass = (from: Float32Array, horizontal: boolean) => {
    const to = new Float32Array(w * h);
    for (let y = 0; y < h; y++)
      for (let x = 0; x < w; x++) {
        let v = 0;
        for (let i = -k; i <= k; i++) {
          const xx = horizontal ? x + i : x;
          const yy = horizontal ? y : y + i;
          if (xx >= 0 && xx < w && yy >= 0 && yy < h) v += from[yy * w + xx]! * weights[i + k]!;
        }
        to[y * w + x] = v;
      }
    return to;
  };
  return pass(pass(src, true), false);
}

const crcTable = Array.from({ length: 256 }, (_, n) => {
  let c = n;
  for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
  return c >>> 0;
});
const crc32 = (bytes: Uint8Array) => {
  let c = 0xffffffff;
  for (const b of bytes) c = crcTable[(c ^ b) & 0xff]! ^ (c >>> 8);
  return (c ^ 0xffffffff) >>> 0;
};
function chunk(type: string, data: Uint8Array): Uint8Array {
  const out = new Uint8Array(12 + data.length);
  const view = new DataView(out.buffer);
  view.setUint32(0, data.length);
  out.set(new TextEncoder().encode(type), 4);
  out.set(data, 8);
  view.setUint32(8 + data.length, crc32(out.subarray(4, 8 + data.length)));
  return out;
}

/** A straight-alpha RGBA crop of `img` as a base64 PNG. */
function png(img: Uint8Array, stride: number, x: number, y: number, w: number, h: number): string {
  const raw = new Uint8Array((w * 4 + 1) * h);
  for (let row = 0; row < h; row++) {
    const from = ((y + row) * stride + x) * 4;
    raw.set(img.subarray(from, from + w * 4), row * (w * 4 + 1) + 1);
  }
  const header = new Uint8Array(13);
  const view = new DataView(header.buffer);
  view.setUint32(0, w);
  view.setUint32(4, h);
  header[8] = 8;
  header[9] = 6;
  const parts = [
    new Uint8Array([137, 80, 78, 71, 13, 10, 26, 10]),
    chunk("IHDR", header),
    chunk("IDAT", deflateSync(raw)),
    chunk("IEND", new Uint8Array()),
  ];
  return Buffer.concat(parts).toString("base64");
}

// Frame ----------------------------------------------------------------------

// A reference window just big enough for every piece; the slices are cut
// from it at their final size.
const pieceW = { left: pad.left + reach, right: pad.right + reach };
const pieceH = { top: pad.top + reach, bottom: reach + pad.bottom };
const W = pieceW.left + span + pieceW.right;
const H = pieceH.top + span + pieceH.bottom;
const win: Shape = { x0: pad.left, y0: pad.top, x1: W - pad.right, y1: H - pad.bottom, r: radius };

const blurred = new Map<string, Float32Array>();
function shadowMask([x, y, b, spread]: ShadowLayer): Float32Array {
  const key = `${x},${y},${b},${spread}`;
  if (!blurred.has(key)) {
    const s = { x0: win.x0 + x - spread, y0: win.y0 + y - spread, x1: win.x1 + x + spread, y1: win.y1 + y + spread, r: radius + spread };
    blurred.set(key, blur(cover(W, H, s), W, H, b));
  }
  return blurred.get(key)!;
}

/** The whole reference frame: window color, the top rim, the hairline edge
 *  and the window shadow outside it, as the preview's `.window` paints them. */
function paintFrame(r: Resolved, mode: Mode, active: boolean): Uint8Array {
  const m = r.modes[mode];
  const shadow = m.shadows[active ? "window" : "windowInactive"]!;
  const body = cover(W, H, win);
  const edge = cover(W, H, { x0: win.x0 - 0.5, y0: win.y0 - 0.5, x1: win.x1 + 0.5, y1: win.y1 + 0.5, r: radius + 0.5 });
  const below = cover(W, H, { ...win, y0: win.y0 + 1, y1: win.y1 + 1 });
  const masks = shadow.layers.map(shadowMask);
  // The window color covers the titlebar and a band along the other edges;
  // the rest of the window is the app's.
  const plain = { x0: win.x0 + border, y0: win.y0 + titlebar, x1: win.x1 - border, y1: win.y1 - border };
  const img = new Uint8Array(W * H * 4);
  for (let y = 0; y < H; y++)
    for (let x = 0; x < W; x++) {
      const i = y * W + x;
      const isPlain = x >= plain.x0 && x < plain.x1 && y >= plain.y0 && y < plain.y1;
      // Layers bottom to top, straight alpha: shadow, edge, window, rim.
      let a = 0;
      let c = [0, 0, 0];
      const paint = (color: RGBA, alpha: number) => {
        const out = alpha + a * (1 - alpha);
        if (out <= 0) return;
        c = [color.r, color.g, color.b].map((v, k) => (v * alpha + c[k]! * a * (1 - alpha)) / out);
        a = out;
      };
      const outside = 1 - body[i]!;
      // Each box-shadow layer, the last listed at the bottom.
      for (let l = masks.length - 1; l >= 0; l--) paint(shadow.color, shadow.color.a * shadow.layers[l]![4] * masks[l]![i]! * outside);
      paint(m.glass.edge, m.glass.edge.a * Math.max(0, edge[i]! - body[i]!));
      if (!isPlain) {
        paint(m.bg.window, body[i]!);
        paint(m.glass.rim, m.glass.rim.a * Math.max(0, body[i]! - below[i]!));
      }
      img.set([...c.map(Math.round), Math.round(a * 255)], i * 4);
    }
  return img;
}

function decorationSvg(r: Resolved, mode: Mode): string {
  const cols = [0, pieceW.left, pieceW.left + span, W];
  const rows = [0, pieceH.top, pieceH.top + span, H];
  const names = [
    ["topleft", "top", "topright"],
    ["left", "center", "right"],
    ["bottomleft", "bottom", "bottomright"],
  ];
  const pieces: string[] = [];
  for (const active of [true, false]) {
    const img = paintFrame(r, mode, active);
    const prefix = active ? "decoration" : "decoration-inactive";
    names.forEach((row, ry) =>
      row.forEach((name, rx) => {
        const [x, y, w, h] = [cols[rx]!, rows[ry]!, cols[rx + 1]! - cols[rx]!, rows[ry + 1]! - rows[ry]!];
        // The middle is the app's; leave it clear.
        const image = name === "center" ? "" : `<image x="${x}" y="${y}" width="${w}" height="${h}" xlink:href="data:image/png;base64,${png(img, W, x, y, w, h)}"/>`;
        pieces.push(`<g id="${prefix}-${name}"><rect x="${x}" y="${y}" width="${w}" height="${h}" fill="#000" fill-opacity="0"/>${image}</g>`);
      }),
    );
  }
  // Maximized, only the titlebar shows: plain window color, no corners.
  const bar = toCss(r.modes[mode].bg.window);
  for (const prefix of ["decoration-maximized", "decoration-maximized-inactive"])
    pieces.push(`<rect id="${prefix}-center" x="0" y="${H + 10}" width="${span}" height="${titlebar}" fill="${bar}"/>`);
  return svg(W, H + 10 + titlebar, pieces);
}

// Buttons --------------------------------------------------------------------

const d = controls.diameter;
const glyphs = {
  close: `<path d="M3.6 3.6l4.8 4.8M8.4 3.6l-4.8 4.8" fill="none" stroke-width="1.2" stroke-linecap="round"/>`,
  minimize: `<path d="M3 6h6" fill="none" stroke-width="1.3" stroke-linecap="round"/>`,
  // Full screen: two corners pulled apart; restore: pushed together.
  maximize: `<path d="M3.4 3.4h3.8l-3.8 3.8zM8.6 8.6h-3.8l3.8-3.8z" stroke="none"/>`,
  restore: `<path d="M5.6 5.6h-3l3-3zM6.4 6.4h3l-3 3z" stroke="none"/>`,
};
const buttons = { close: "close", minimize: "minimize", maximize: "zoom", restore: "zoom" } as const;

function buttonSvg(r: Resolved, mode: Mode, button: keyof typeof buttons): string {
  const m = r.modes[mode];
  const color = toCss(r.windowControls[buttons[button]]);
  const idle = toCss(flat(m.fill.primary, m.bg.window));
  const disc = (fill: string, glyph: boolean, pressed: boolean) =>
    `<circle cx="${d / 2}" cy="${d / 2}" r="${d / 2}" fill="${fill}"/>` +
    (pressed ? `<circle cx="${d / 2}" cy="${d / 2}" r="${d / 2}" fill="#000" fill-opacity="0.18"/>` : "") +
    `<circle cx="${d / 2}" cy="${d / 2}" r="${d / 2 - 0.25}" fill="none" stroke="#000" stroke-opacity="0.12" stroke-width="0.5"/>` +
    (glyph ? `<g fill="#000" fill-opacity="0.5" stroke="#000" stroke-opacity="0.5">${glyphs[button]}</g>` : "");
  // Every state for the focused window, and with -inactive for the others,
  // whose buttons are gray until hovered.
  const states: Record<string, string> = {
    active: disc(color, false, false),
    hover: disc(color, true, false),
    pressed: disc(color, true, true),
    deactivated: disc(idle, false, false),
    inactive: disc(idle, false, false),
    "hover-inactive": disc(color, true, false),
    "pressed-inactive": disc(color, true, true),
    "deactivated-inactive": disc(idle, false, false),
  };
  // KSvg only takes a prefix whose -center element exists; older Aurorae
  // reads the bare name. Both, a piece apiece, stacked down the sheet.
  const pieces = Object.entries(states).flatMap(([id, art], n) =>
    [id, `${id}-center`].map((name, k) => {
      const y = (n * 2 + k) * (d + 4);
      return `<g id="${name}" transform="translate(0 ${y})"><rect width="${d}" height="${d}" fill="#000" fill-opacity="0"/>${art}</g>`;
    }),
  );
  return svg(d, Object.keys(states).length * 2 * (d + 4), pieces);
}

const svg = (w: number, h: number, body: string[]) =>
  `<?xml version="1.0" encoding="UTF-8"?>\n<!-- ${HEADER} -->\n` +
  `<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="${w}" height="${h}" viewBox="0 0 ${w} ${h}">\n` +
  `${body.join("\n")}\n</svg>\n`;

// Theme ----------------------------------------------------------------------

function themerc(r: Resolved, mode: Mode): string {
  const m = r.modes[mode];
  const group = controls.diameter * 3 + controls.gap * 2;
  return `# ${HEADER}

[General]
ActiveTextColor=${toKde(flat(m.label.primary, m.bg.window))}
InactiveTextColor=${toKde(flat(m.label.tertiary, m.bg.window))}
TitleAlignment=Center
TitleVerticalAlignment=Center
Animation=0
Shadow=true

[Layout]
BorderLeft=0
BorderRight=0
BorderBottom=0
TitleEdgeTop=0
TitleEdgeBottom=0
TitleEdgeLeft=${controls.inset}
TitleEdgeRight=${controls.inset}
TitleEdgeTopMaximized=0
TitleEdgeBottomMaximized=0
TitleEdgeLeftMaximized=${controls.inset}
TitleEdgeRightMaximized=${controls.inset}
# The title centers between the buttons and the right edge; the extra right
# margin balances the buttons so it centers on the window instead.
TitleBorderLeft=${controls.gap}
TitleBorderRight=${group + controls.gap}
TitleHeight=${titlebar}
ButtonWidth=${d}
ButtonWidthClose=${d}
ButtonWidthMinimize=${d}
ButtonWidthMaximizeRestore=${d}
ButtonHeight=${d}
ButtonSpacing=${controls.gap}
ButtonMarginTop=${(titlebar - d) / 2}
ExplicitButtonSpacer=${controls.gap}
PaddingLeft=${pad.left}
PaddingRight=${pad.right}
PaddingTop=${pad.top}
PaddingBottom=${pad.bottom}
`;
}

export function aurorae(r: Resolved, mode: Mode): Record<string, string> {
  const name = auroraeName(mode);
  const title = mode === "dark" ? "Ambrosia Dark" : "Ambrosia Light";
  const comment = "Ambrosia's window frame: traffic-light buttons, centered title";
  return {
    "metadata.desktop": `# ${HEADER}\n[Desktop Entry]\nName=${title}\nComment=${comment}\nX-KDE-PluginInfo-Name=${name}\nX-KDE-PluginInfo-Author=Ambrosia\nX-KDE-PluginInfo-Version=1\nX-KDE-PluginInfo-License=LicenseRef-TBD\n`,
    "metadata.json": `${JSON.stringify({ KPlugin: { Id: name, Name: title, Description: comment, Authors: [{ Name: "Ambrosia" }], License: "LicenseRef-TBD", Version: "1" }, KPackageStructure: "KWin/Aurorae" }, null, 2)}\n`,
    [`${name}rc`]: themerc(r, mode),
    "decoration.svg": decorationSvg(r, mode),
    "close.svg": buttonSvg(r, mode, "close"),
    "minimize.svg": buttonSvg(r, mode, "minimize"),
    "maximize.svg": buttonSvg(r, mode, "maximize"),
    "restore.svg": buttonSvg(r, mode, "restore"),
  };
}
