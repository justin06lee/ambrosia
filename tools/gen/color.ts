// OKLCH → sRGB with gamut mapping, plus the compositing and contrast math the
// generator needs to derive accents and flatten translucent colors.

/** 8-bit sRGB channels with a 0–1 alpha. */
export interface RGBA {
  r: number;
  g: number;
  b: number;
  a: number;
}

export interface OKLCH {
  l: number;
  c: number;
  h: number;
  a: number;
}

export function parseOklch(input: string): OKLCH {
  const m = input.trim().match(/^oklch\(\s*([\d.]+)\s+([\d.]+)\s+(-?[\d.]+)\s*(?:\/\s*([\d.]+))?\s*\)$/);
  if (!m) throw new Error(`not an oklch() color: ${input}`);
  return { l: +m[1]!, c: +m[2]!, h: +m[3]!, a: m[4] === undefined ? 1 : +m[4] };
}

/** OKLCH → linear-light sRGB, unclamped (Björn Ottosson's OKLab matrices). */
function toLinear({ l, c, h }: OKLCH): [number, number, number] {
  const rad = (h * Math.PI) / 180;
  const A = c * Math.cos(rad);
  const B = c * Math.sin(rad);
  const l_ = (l + 0.3963377774 * A + 0.2158037573 * B) ** 3;
  const m_ = (l - 0.1055613458 * A - 0.0638541728 * B) ** 3;
  const s_ = (l - 0.0894841775 * A - 1.291485548 * B) ** 3;
  return [
    4.0767416621 * l_ - 3.3077115913 * m_ + 0.2309699292 * s_,
    -1.2684380046 * l_ + 2.6097574011 * m_ - 0.3413193965 * s_,
    -0.0041960863 * l_ - 0.7034186147 * m_ + 1.707614701 * s_,
  ];
}

const inGamut = (rgb: number[]) => rgb.every((v) => v >= -1e-4 && v <= 1 + 1e-4);

const encode = (v: number) => {
  const x = Math.min(1, Math.max(0, v));
  return x <= 0.0031308 ? 12.92 * x : 1.055 * x ** (1 / 2.4) - 0.055;
};

const decode = (v: number) => (v <= 0.04045 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4);

/** Converts to sRGB, reducing chroma (keeping lightness and hue) until in gamut. */
export function oklchToRgba(color: OKLCH): RGBA {
  let lin = toLinear(color);
  if (!inGamut(lin)) {
    let lo = 0;
    let hi = color.c;
    for (let i = 0; i < 24; i++) {
      const mid = (lo + hi) / 2;
      if (inGamut(toLinear({ ...color, c: mid }))) lo = mid;
      else hi = mid;
    }
    lin = toLinear({ ...color, c: lo });
  }
  const [r, g, b] = lin.map((v) => Math.round(encode(v) * 255)) as [number, number, number];
  return { r, g, b, a: color.a };
}

export const rgba = (input: string): RGBA => oklchToRgba(parseOklch(input));

/** Source-over compositing in sRGB space, the way toolkits blend. */
export function over(fg: RGBA, bg: RGBA): RGBA {
  const a = fg.a + bg.a * (1 - fg.a);
  if (a === 0) return { r: 0, g: 0, b: 0, a: 0 };
  const mix = (f: number, b: number) => Math.round((f * fg.a + b * bg.a * (1 - fg.a)) / a);
  return { r: mix(fg.r, bg.r), g: mix(fg.g, bg.g), b: mix(fg.b, bg.b), a };
}

export const withAlpha = (c: RGBA, a: number): RGBA => ({ ...c, a });

export function luminance({ r, g, b }: RGBA): number {
  return 0.2126 * decode(r / 255) + 0.7152 * decode(g / 255) + 0.0722 * decode(b / 255);
}

/** WCAG 2 contrast ratio between two opaque colors. */
export function contrast(a: RGBA, b: RGBA): number {
  const [hi, lo] = [luminance(a), luminance(b)].sort((x, y) => y - x) as [number, number];
  return (hi + 0.05) / (lo + 0.05);
}

/** Shifts lightness toward `direction` until the color reaches `min` contrast on `bg`. */
export function ensureContrast(color: OKLCH, bg: RGBA, min: number, direction: -1 | 1): OKLCH {
  let c = { ...color };
  while (contrast(oklchToRgba(c), bg) < min && c.l > 0 && c.l < 1) {
    c = { ...c, l: +(c.l + direction * 0.005).toFixed(4) };
  }
  return c;
}

const hex2 = (n: number) => n.toString(16).padStart(2, "0");

export const toHex = ({ r, g, b }: RGBA) => `#${hex2(r)}${hex2(g)}${hex2(b)}`;

/** Qt's 8-digit form is #AARRGGBB. */
export const toQtHex = (c: RGBA) =>
  c.a >= 1 ? toHex(c) : `#${hex2(Math.round(c.a * 255))}${toHex(c).slice(1)}`;

const alphaText = (a: number) => +a.toFixed(3);

export const toCss = (c: RGBA) =>
  c.a >= 1 ? toHex(c) : `rgba(${c.r}, ${c.g}, ${c.b}, ${alphaText(c.a)})`;

export const toKde = ({ r, g, b }: RGBA) => `${r},${g},${b}`;
