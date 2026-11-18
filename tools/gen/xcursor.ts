// Xcursor files: what X11 and Wayland clients load a pointer from. One file
// holds a shape at every size it comes in, and every frame of a moving one.
// The format is libXcursor's: a header, a table of contents, then one chunk
// an image, all in little-endian 32-bit words.

export interface CursorImage {
  /** The nominal size clients ask for by; the image itself may be larger. */
  size: number;
  width: number;
  height: number;
  xhot: number;
  yhot: number;
  /** Milliseconds before the next frame; 0 for a still pointer. */
  delay: number;
  /** Premultiplied RGBA, row by row. */
  pixels: Uint8Array;
}

const MAGIC = 0x72756358; // "Xcur"
const FILE_VERSION = 0x10000;
const IMAGE = 0xfffd0002;
const IMAGE_VERSION = 1;
const FILE_HEADER = 16;
const TOC_ENTRY = 12;
const IMAGE_HEADER = 36;

/** Images of one size must follow each other in frame order. */
export function xcursor(images: CursorImage[]): Uint8Array {
  const body = FILE_HEADER + images.length * TOC_ENTRY;
  const total = images.reduce((sum, i) => sum + IMAGE_HEADER + i.width * i.height * 4, body);
  const bytes = new Uint8Array(total);
  const view = new DataView(bytes.buffer);
  const words = (at: number, values: number[]) => values.forEach((v, i) => view.setUint32(at + i * 4, v, true));

  words(0, [MAGIC, FILE_HEADER, FILE_VERSION, images.length]);
  let at = body;
  images.forEach((image, index) => {
    words(FILE_HEADER + index * TOC_ENTRY, [IMAGE, image.size, at]);
    words(at, [IMAGE_HEADER, IMAGE, image.size, IMAGE_VERSION, image.width, image.height, image.xhot, image.yhot, image.delay]);
    at += IMAGE_HEADER;
    // Each pixel is one ARGB word, so its bytes run B, G, R, A.
    for (let p = 0; p < image.width * image.height * 4; p += 4, at += 4) {
      bytes[at] = image.pixels[p + 2]!;
      bytes[at + 1] = image.pixels[p + 1]!;
      bytes[at + 2] = image.pixels[p]!;
      bytes[at + 3] = image.pixels[p + 3]!;
    }
  });
  return bytes;
}

/** The images in a file, as libXcursor would find them. */
export function readXcursor(bytes: Uint8Array): CursorImage[] {
  const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
  const word = (at: number) => view.getUint32(at, true);
  if (word(0) !== MAGIC) throw new Error("not an Xcursor file");

  const images: CursorImage[] = [];
  for (let entry = 0; entry < word(12); entry++) {
    const toc = word(4) + entry * TOC_ENTRY;
    if (word(toc) !== IMAGE) continue;
    const at = word(toc + 8);
    const [width, height] = [word(at + 16), word(at + 20)];
    const pixels = new Uint8Array(width * height * 4);
    for (let p = 0, from = at + word(at); p < pixels.length; p += 4, from += 4) {
      pixels[p] = bytes[from + 2]!;
      pixels[p + 1] = bytes[from + 1]!;
      pixels[p + 2] = bytes[from]!;
      pixels[p + 3] = bytes[from + 3]!;
    }
    images.push({ size: word(toc + 4), width, height, xhot: word(at + 24), yhot: word(at + 28), delay: word(at + 32), pixels });
  }
  return images;
}
