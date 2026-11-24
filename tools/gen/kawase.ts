// How strong KWin's blur is, in the design's terms. The design gives a
// material's blur as CSS does (blur(28px): a Gaussian of that standard
// deviation); KWin's blur, and our glass effect forked from it, is a dual
// Kawase blur set by a count of halvings and a sampling offset. This runs
// the same passes (the effect's downsample, upsample and on-screen shaders)
// over a hard edge and finds the settings whose edge is as soft as the
// Gaussian's.

type Tex = { w: number; h: number; d: Float64Array };

const tex = (w: number, h: number): Tex => ({ w, h, d: new Float64Array(w * h) });

/** A bilinear read at normalised coordinates, clamped to the edge, as GL does. */
function sample(t: Tex, u: number, v: number): number {
  const x = Math.max(0, Math.min(t.w - 1, u * t.w - 0.5));
  const y = Math.max(0, Math.min(t.h - 1, v * t.h - 0.5));
  const x0 = Math.floor(x);
  const y0 = Math.floor(y);
  const x1 = Math.min(t.w - 1, x0 + 1);
  const y1 = Math.min(t.h - 1, y0 + 1);
  const fx = x - x0;
  const fy = y - y0;
  const top = t.d[y0 * t.w + x0]! * (1 - fx) + t.d[y0 * t.w + x1]! * fx;
  const bottom = t.d[y1 * t.w + x0]! * (1 - fx) + t.d[y1 * t.w + x1]! * fx;
  return top * (1 - fy) + bottom * fy;
}

/** downsample.frag: the middle four times, and the four corners. */
function down(src: Tex, offset: number): Tex {
  const dst = tex(Math.max(1, Math.floor(src.w / 2)), Math.max(1, Math.floor(src.h / 2)));
  const hx = (0.5 / src.w) * offset;
  const hy = (0.5 / src.h) * offset;
  for (let y = 0; y < dst.h; y++) {
    for (let x = 0; x < dst.w; x++) {
      const u = (x + 0.5) / dst.w;
      const v = (y + 0.5) / dst.h;
      dst.d[y * dst.w + x] =
        (sample(src, u, v) * 4 + sample(src, u - hx, v - hy) + sample(src, u + hx, v + hy) + sample(src, u + hx, v - hy) + sample(src, u - hx, v + hy)) / 8;
    }
  }
  return dst;
}

/** upsample.frag (and the on-screen pass): eight taps round the middle. */
function up(src: Tex, w: number, h: number, offset: number): Tex {
  const dst = tex(w, h);
  const hx = (0.5 / src.w) * offset;
  const hy = (0.5 / src.h) * offset;
  for (let y = 0; y < h; y++) {
    for (let x = 0; x < w; x++) {
      const u = (x + 0.5) / w;
      const v = (y + 0.5) / h;
      const axes = sample(src, u - hx * 2, v) + sample(src, u + hx * 2, v) + sample(src, u, v + hy * 2) + sample(src, u, v - hy * 2);
      const corners = sample(src, u - hx, v + hy) + sample(src, u + hx, v + hy) + sample(src, u + hx, v - hy) + sample(src, u - hx, v - hy);
      dst.d[y * w + x] = (axes + 2 * corners) / 12;
    }
  }
  return dst;
}

/**
 * The standard deviation of the Gaussian that softens a hard edge as much as
 * the blur does at these settings (by the edge's 10% to 90% rise), in the
 * pixels the blur works in. The halvings make the blur depend a little on
 * where the edge falls, so it is the mean over a few places.
 */
export function kawaseSigma(iterations: number, offset: number): number {
  const W = 1024;
  const H = 8;
  const shifts = [0, 3, 7, 11];
  let total = 0;
  for (const shift of shifts) {
    const first = tex(W, H);
    for (let y = 0; y < H; y++) for (let x = W / 2 + shift; x < W; x++) first.d[y * W + x] = 1;
    const chain = [first];
    for (let i = 1; i <= iterations; i++) chain.push(down(chain[i - 1]!, offset));
    let now = chain[iterations]!;
    for (let i = iterations - 1; i >= 0; i--) now = up(now, chain[i]!.w, chain[i]!.h, offset);
    const row = (H / 2) * W;
    const reach = (level: number) => {
      for (let x = 1; x < W; x++) {
        const a = now.d[row + x - 1]!;
        const b = now.d[row + x]!;
        if (a < level && b >= level) return x - 1 + (level - a) / (b - a);
      }
      return NaN;
    };
    // A Gaussian's edge rises from 10% to 90% over 2.5631 standard deviations.
    total += (reach(0.9) - reach(0.1)) / 2.5631;
  }
  return total / shifts.length;
}

/**
 * KWin's own limits for the offset at each count of halvings (blur.cpp):
 * under the least the halving shows as blocks, over the most the taps show
 * as diagonal lines. `expand` is how far outside a blurred place the blur
 * reads from, which is how far a repaint under it has to reach.
 */
export const KAWASE_LEVELS = [
  { iterations: 1, min: 1, max: 2, expand: 10 },
  { iterations: 2, min: 2, max: 3, expand: 20 },
  { iterations: 3, min: 2, max: 5, expand: 50 },
  { iterations: 4, min: 3, max: 8, expand: 150 },
  { iterations: 5, min: 5, max: 10, expand: 400 },
] as const;

export interface Kawase {
  iterations: number;
  offset: number;
  expand: number;
}

/**
 * The settings that blur as a Gaussian of `sigma` does: the fewest halvings
 * that reach it (a level's offset may run 15% over its most, where the lines
 * don't show yet, and under its least), and the offset found by halving the
 * range.
 */
export function kawaseFor(sigma: number): Kawase {
  const last = KAWASE_LEVELS[KAWASE_LEVELS.length - 1]!;
  const level = KAWASE_LEVELS.find((l) => kawaseSigma(l.iterations, l.max * 1.15) >= sigma) ?? last;
  let low = 0.5;
  let high = level.max * 1.15;
  for (let i = 0; i < 16; i++) {
    const middle = (low + high) / 2;
    if (kawaseSigma(level.iterations, middle) < sigma) low = middle;
    else high = middle;
  }
  return { iterations: level.iterations, offset: Math.round(((low + high) / 2) * 1000) / 1000, expand: level.expand };
}
