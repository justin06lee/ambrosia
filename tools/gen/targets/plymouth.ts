// The picture while the computer starts and shuts down: a Plymouth theme
// ("ambrosia", the script plugin). A black screen, the mark in white in its
// middle and, while starting, a thin bar under it that fills, as a Mac shows
// its own. Pictures are drawn here at 1x to 4x; the script takes the one at
// or above the screen's scale and sizes it down, since Plymouth's script
// plugin knows nothing of a display's scale.

import { Resvg } from "@resvg/resvg-js";
import { size } from "../../../design/tokens";
import { HEADER } from "./shared";

const b = size.boot;
export const PLYMOUTH_THEME = "ambrosia";
/** The screen height the sizes are for; taller screens draw larger. */
const REFERENCE_HEIGHT = 1080;
const SCALES = [1, 2, 3, 4];
/** The bar's track and what fills it, and the password field's edge: white
 *  at these strengths over the black. */
const TRACK = 0.24;
const FILL = 0.92;
const FIELD = 0.3;

const circle = (cx: number, cy: number, r: number) => `M${cx - r} ${cy}a${r} ${r} 0 1 0 ${2 * r} 0a${r} ${r} 0 1 0 ${-2 * r} 0z`;
/** The Ambrosia mark on its 24-unit grid, as the menu bar draws it
 *  (shell/icons.js, "bowl"): the bowl, three scoops, the spoon. */
const MARK =
  "M18.6 12.4H2.4A8.1 7.2 0 0 0 18.6 12.4Z" +
  circle(6.1, 11.4, 2.9) +
  circle(10.5, 9.5, 3.7) +
  circle(14.9, 11.3, 2.9) +
  "M17.25 10.21L22.05 3.51A1.05 1.05 0 0 0 20.35 2.29L15.55 8.99A1.05 1.05 0 0 0 17.25 10.21Z";
/** What of the grid the mark covers: it is centered by its own box, not the
 *  grid's, so it sits in the screen's middle. */
const MARK_BOX = { x: 2.4, y: 1.85, w: 20.1, h: 17.75 };
const markWidth = Math.round((b.mark * MARK_BOX.w) / MARK_BOX.h);

const svg = (w: number, h: number, body: string, viewBox = `0 0 ${w} ${h}`) =>
  `<svg xmlns="http://www.w3.org/2000/svg" width="${w}" height="${h}" viewBox="${viewBox}">${body}</svg>`;
const png = (source: string, width: number) =>
  new Resvg(source, { fitTo: { mode: "width", value: width }, font: { loadSystemFonts: false } }).render().asPng();

const pill = (w: number, h: number, opacity: number) => svg(w, h, `<rect width="${w}" height="${h}" rx="${h / 2}" fill="#fff" fill-opacity="${opacity}"/>`);

/** Each picture's name and its drawing at 1x. */
const pictures: Record<string, { svg: string; width: number }> = {
  mark: {
    svg: svg(markWidth, b.mark, `<path d="${MARK}" fill="#fff"/>`, `${MARK_BOX.x} ${MARK_BOX.y} ${MARK_BOX.w} ${MARK_BOX.h}`),
    width: markWidth,
  },
  track: { svg: pill(b.bar, b.track, TRACK), width: b.bar },
  fill: { svg: pill(b.bar, b.track, FILL), width: b.bar },
  field: {
    svg: svg(
      b.bar,
      b.field,
      `<rect x="0.5" y="0.5" width="${b.bar - 1}" height="${b.field - 1}" rx="${(b.field - 1) / 2}" fill="#fff" fill-opacity="0.08" stroke="#fff" stroke-opacity="${FIELD}"/>`,
    ),
    width: b.bar,
  },
  dot: { svg: svg(b.dot, b.dot, `<circle cx="${b.dot / 2}" cy="${b.dot / 2}" r="${b.dot / 2}" fill="#fff"/>`), width: b.dot },
};

const descriptor = `# ${HEADER}
[Plymouth Theme]
Name=Ambrosia
Description=The mark on black, and a bar that fills while the computer starts
ModuleName=script

[script]
ImageDir=/usr/share/plymouth/themes/${PLYMOUTH_THEME}
ScriptFile=/usr/share/plymouth/themes/${PLYMOUTH_THEME}/${PLYMOUTH_THEME}.script
`;

const script = `# ${HEADER}
# Sizes are for a screen ${REFERENCE_HEIGHT} high (design/tokens.ts, size.boot).

Window.SetBackgroundTopColor(0, 0, 0);
Window.SetBackgroundBottomColor(0, 0, 0);

scale = Window.GetHeight() / ${REFERENCE_HEIGHT};
if (scale < 0.75) scale = 0.75;
# The drawing at or above the screen's scale, sized down to it.
drawn = Math.Int(scale);
if (drawn < scale) drawn = drawn + 1;
if (drawn > ${SCALES.at(-1)}) drawn = ${SCALES.at(-1)};

fun px(n) {
  return Math.Int(n * scale + 0.5);
}

fun picture(name, width, height) {
  image = Image(name + "-" + drawn + ".png");
  if (image.GetWidth() == width && image.GetHeight() == height) return image;
  return image.Scale(width, height);
}

center_x = Window.GetX() + Window.GetWidth() / 2;
center_y = Window.GetY() + Window.GetHeight() / 2;

mark.image = picture("mark", px(${markWidth}), px(${b.mark}));
mark.sprite = Sprite(mark.image);
mark.sprite.SetPosition(Math.Int(center_x - mark.image.GetWidth() / 2), Math.Int(center_y - mark.image.GetHeight() / 2), 10);

# The bar: a track, and over it as much of the filled pill as there is
# progress, its round right end kept by drawing that end apart.
bar.width = px(${b.bar});
bar.height = px(${b.track});
bar.x = Math.Int(center_x - bar.width / 2);
bar.y = Math.Int(center_y + mark.image.GetHeight() / 2 + px(${b.gap}));
bar.track = picture("track", bar.width, bar.height);
bar.fill = picture("fill", bar.width, bar.height);
bar.cap = bar.fill.Crop(bar.width - bar.height, 0, bar.height, bar.height);
bar.track_sprite = Sprite();
bar.body_sprite = Sprite();
bar.cap_sprite = Sprite();
bar.shown = 0;
bar.filled = -1;

fun show_bar(progress) {
  if (!bar.shown) {
    bar.track_sprite.SetImage(bar.track);
    bar.track_sprite.SetPosition(bar.x, bar.y, 10);
    bar.shown = 1;
  }
  if (progress > 1) progress = 1;
  width = Math.Int(bar.width * progress);
  if (width < bar.height) width = bar.height;
  if (width == bar.filled) return;
  bar.filled = width;
  body = width - bar.height;
  if (body > 0) {
    bar.body_sprite.SetImage(bar.fill.Crop(0, 0, body, bar.height));
    bar.body_sprite.SetPosition(bar.x, bar.y, 11);
  }
  bar.cap_sprite.SetImage(bar.cap);
  bar.cap_sprite.SetPosition(bar.x + body, bar.y, 11);
}

fun hide_bar() {
  bar.track_sprite.SetOpacity(0);
  bar.body_sprite.SetOpacity(0);
  bar.cap_sprite.SetOpacity(0);
}

fun unhide_bar() {
  bar.track_sprite.SetOpacity(1);
  bar.body_sprite.SetOpacity(1);
  bar.cap_sprite.SetOpacity(1);
}

# Starting up fills the bar by how long the last start took; shutting down
# and restarting show the mark alone.
fun boot_progress(duration, progress) {
  if (Plymouth.GetMode() == "boot") show_bar(progress);
}
Plymouth.SetBootProgressFunction(boot_progress);

# Updates installed while off (systemd's offline updates) say how far along.
fun update_progress(percent) {
  show_bar(percent / 100);
}
Plymouth.SetSystemUpdateFunction(update_progress);

# A disk's password: a field where the bar is, a dot for each character.
field.sprite = Sprite();
field.dots = [];
field.count = 0;

fun display_password(prompt, bullets) {
  hide_bar();
  if (!field.image) {
    field.image = picture("field", px(${b.bar}), px(${b.field}));
    field.dot = picture("dot", px(${b.dot}), px(${b.dot}));
  }
  field.x = Math.Int(center_x - field.image.GetWidth() / 2);
  field.y = bar.y - Math.Int((field.image.GetHeight() - bar.height) / 2);
  field.sprite.SetImage(field.image);
  field.sprite.SetPosition(field.x, field.y, 10);
  field.sprite.SetOpacity(1);
  step = Math.Int(field.dot.GetWidth() * 1.5);
  # As many as fit; a longer password stops adding dots.
  fit = Math.Int((field.image.GetWidth() - field.image.GetHeight()) / step);
  if (bullets > fit) bullets = fit;
  left = Math.Int(field.x + field.image.GetHeight() / 2);
  top = Math.Int(field.y + (field.image.GetHeight() - field.dot.GetHeight()) / 2);
  for (index = 0; index < bullets || index < field.count; index++) {
    if (!field.dots[index]) field.dots[index] = Sprite(field.dot);
    field.dots[index].SetPosition(left + index * step, top, 11);
    if (index < bullets) field.dots[index].SetOpacity(1);
    else field.dots[index].SetOpacity(0);
  }
  if (bullets > field.count) field.count = bullets;
}
Plymouth.SetDisplayPasswordFunction(display_password);

fun display_normal() {
  field.sprite.SetOpacity(0);
  for (index = 0; index < field.count; index++) field.dots[index].SetOpacity(0);
  unhide_bar();
}
Plymouth.SetDisplayNormalFunction(display_normal);
`;

/** How the screen looks part-way through starting, to look it over without
 *  a boot: the same pictures, placed as the script places them. */
function sheet(): Uint8Array {
  const w = 1920;
  const h = REFERENCE_HEIGHT;
  const progress = 0.6;
  const barX = (w - b.bar) / 2;
  const barY = h / 2 + b.mark / 2 + b.gap;
  const markScale = b.mark / MARK_BOX.h;
  return png(
    svg(
      w,
      h,
      `<rect width="${w}" height="${h}" fill="#000"/>` +
        `<g transform="translate(${(w - markWidth) / 2} ${(h - b.mark) / 2}) scale(${markScale}) translate(${-MARK_BOX.x} ${-MARK_BOX.y})"><path d="${MARK}" fill="#fff"/></g>` +
        `<rect x="${barX}" y="${barY}" width="${b.bar}" height="${b.track}" rx="${b.track / 2}" fill="#fff" fill-opacity="${TRACK}"/>` +
        `<rect x="${barX}" y="${barY}" width="${b.bar * progress}" height="${b.track}" rx="${b.track / 2}" fill="#fff" fill-opacity="${FILL}"/>`,
    ),
    w,
  );
}

export function plymouth(): Record<string, string | Uint8Array> {
  const dir = `plymouth/${PLYMOUTH_THEME}`;
  const files: Record<string, string | Uint8Array> = {
    [`${dir}/${PLYMOUTH_THEME}.plymouth`]: descriptor,
    [`${dir}/${PLYMOUTH_THEME}.script`]: script,
    "plymouth/sheet.png": sheet(),
  };
  for (const [name, p] of Object.entries(pictures)) {
    for (const s of SCALES) files[`${dir}/${name}-${s}.png`] = png(p.svg, p.width * s);
  }
  return files;
}
