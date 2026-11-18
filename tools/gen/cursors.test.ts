// The pointer theme: the Xcursor writer, and what every shape must have.
import { expect, test } from "bun:test";
import * as c from "../../design/cursors";
import { resolve } from "./resolve";
import { cursorTheme, pointerColors } from "./targets/cursors";
import { ICON_THEME_ROOT } from "./targets/shared";
import { readXcursor, xcursor, type CursorImage } from "./xcursor";

const r = resolve();
const pointers = c.pointers(pointerColors(r));
const theme = cursorTheme(r);
const root = ICON_THEME_ROOT;

test("an Xcursor file reads back as it was written", () => {
  const image = (size: number, delay: number): CursorImage => ({
    size, width: size + 1, height: size, xhot: 3, yhot: 5, delay,
    pixels: Uint8Array.from({ length: (size + 1) * size * 4 }, (_, i) => (i * 7 + size) % 256),
  });
  const images = [image(2, 30), image(2, 30), image(3, 0)];
  expect(readXcursor(xcursor(images))).toEqual(images);
  expect(new TextDecoder().decode(xcursor(images).slice(0, 4))).toBe("Xcur");
});

test("every pointer comes at every size, with its hotspot on the image", () => {
  for (const [name, cursor] of Object.entries(pointers)) {
    const images = readXcursor(theme.files[`${root}/cursors/${name}`] as Uint8Array);
    expect(images.length).toBe(c.sizes.length * cursor.frames.length);
    for (const size of c.sizes) {
      const frames = images.filter((i) => i.size === size);
      expect(frames.length).toBe(cursor.frames.length);
      for (const frame of frames) {
        expect(frame.width).toBe((c.canvas * size) / c.nominal);
        expect(frame.height).toBe(frame.width);
        expect(frame.xhot).toBeLessThan(frame.width);
        expect(frame.yhot).toBeLessThan(frame.height);
        // A moving pointer needs a delay to move by; a still one must have none.
        expect(frame.delay > 0).toBe(cursor.frames.length > 1);
        expect(frame.pixels.some((v, i) => i % 4 === 3 && v === 255)).toBe(true);
      }
    }
  }
});

test("the hotspot lands on ink", () => {
  // Where the pointer points must be part of the pointer: the arrow's tip,
  // the fingertip, the middle of a cross. (The open lens of the magnifier is
  // paper, which counts.)
  for (const [name, cursor] of Object.entries(pointers)) {
    const image = readXcursor(theme.files[`${root}/cursors/${name}`] as Uint8Array).find((i) => i.size === 96)!;
    const alpha = image.pixels[(image.yhot * image.width + image.xhot) * 4 + 3]!;
    expect({ name, opaque: alpha > 200 }).toEqual({ name, opaque: true });
  }
});

test("no name is claimed twice, and the names apps ask for are all there", () => {
  const names = Object.entries(pointers).flatMap(([name, cursor]) => [name, ...cursor.aliases]);
  expect(new Set(names).size).toBe(names.length);
  for (const [alias, target] of Object.entries(theme.links)) expect(pointers[target]).toBeDefined();

  const asked = [
    // CSS's names, which Wayland's cursor-shape protocol, GTK 4 and Qt 6 use.
    "default", "context-menu", "help", "pointer", "progress", "wait", "cell", "crosshair", "text", "vertical-text",
    "alias", "copy", "move", "no-drop", "not-allowed", "grab", "grabbing", "all-scroll", "col-resize", "row-resize",
    "n-resize", "e-resize", "s-resize", "w-resize", "ne-resize", "nw-resize", "se-resize", "sw-resize",
    "ew-resize", "ns-resize", "nesw-resize", "nwse-resize", "zoom-in", "zoom-out",
    // X11's, which Xwayland apps and older toolkits still use.
    "left_ptr", "hand1", "hand2", "xterm", "watch", "left_ptr_watch", "cross", "fleur", "question_arrow",
    "sb_h_double_arrow", "sb_v_double_arrow", "top_left_corner", "top_right_corner", "bottom_left_corner",
    "bottom_right_corner", "top_side", "bottom_side", "left_side", "right_side",
    // Qt's and KDE's own.
    "size_all", "size_hor", "size_ver", "size_fdiag", "size_bdiag", "split_h", "split_v", "openhand", "closedhand",
    "pointing_hand", "forbidden", "whats_this", "dnd-move", "dnd-copy", "dnd-link", "dnd-none", "dnd-no-drop",
  ];
  for (const name of asked) expect(names).toContain(name);
});

test("KWin's SVGs use only what Qt's SVG reader draws", () => {
  for (const [path, content] of Object.entries(theme.files)) {
    if (!path.startsWith(`${root}/cursors_scalable/`) || !path.endsWith(".svg")) continue;
    const svg = content as string;
    expect(svg).not.toContain("<filter");
    expect(svg).not.toContain("oklch(");
    expect(svg).toContain(`width="${c.canvas}" height="${c.canvas}"`);
  }
  for (const [name, cursor] of Object.entries(pointers)) {
    const meta = JSON.parse(theme.files[`${root}/cursors_scalable/${name}/metadata.json`] as string);
    expect(meta.length).toBe(cursor.frames.length);
    for (const frame of meta) {
      expect(theme.files[`${root}/cursors_scalable/${name}/${frame.filename}`]).toBeDefined();
      expect(frame.nominal_size).toBe(c.nominal);
    }
  }
});
