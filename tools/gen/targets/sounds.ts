// The sound theme (dist/sounds/ambrosia, a freedesktop sound theme): each
// recipe in design/sounds.ts synthesized into a WAV, the other names it
// answers to as links beside it. KDE (notifications, KWin's bell, the volume
// keys) and GTK look sounds up in it by name; the shell and Files play the
// ones nothing else does through /usr/lib/ambrosia/sound (session/sound).
//
// The same recipe always gives the same bytes: the noise is seeded by the
// sound's name.

import { sounds, type Grains, type Layer, type Noise, type Sound, type Tone } from "../../../design/sounds";

export const SOUND_THEME = "ambrosia";
export const RATE = 48000;
const CHANNELS = 2;
/** The last moments of every sound fall to nothing, so none ends in a click. */
const TAIL = 0.008;

/** A small seeded generator (mulberry32): the same noise at every build. */
function random(seed: number): () => number {
  let a = seed >>> 0;
  return () => {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

/** A number from a name (FNV-1a), to seed with. */
function hash(text: string): number {
  let h = 0x811c9dc5;
  for (let i = 0; i < text.length; i++) h = Math.imul(h ^ text.charCodeAt(i), 0x01000193);
  return h >>> 0;
}

/** Struck and left to ring: up over `attack`, then down by `decay`. */
const envelope = (t: number, attack: number, decay: number) => Math.min(1, t / attack) * Math.exp(-t / decay);

function tone(out: Float64Array, layer: Tone) {
  const start = Math.round(layer.at * RATE);
  const parts: [number, number, number][] = [[1, 1, 1], ...(layer.partials ?? [])];
  // The pitch slides (evenly by ear) over the time the note takes to die away.
  const slide = layer.decay * 4;
  const phases = parts.map(() => 0);
  for (let n = start; n < out.length; n++) {
    const t = (n - start) / RATE;
    const freq = layer.to ? layer.freq * Math.pow(layer.to / layer.freq, Math.min(1, t / slide)) : layer.freq;
    let sample = 0;
    parts.forEach(([multiple, level, decay], i) => {
      sample += Math.sin(phases[i]!) * level * envelope(t, layer.attack, layer.decay * decay);
      phases[i]! += (2 * Math.PI * freq * multiple) / RATE;
    });
    out[n]! += sample * layer.level;
  }
}

/** Keeps `band` of `signal`: two gentle filters at each end, run twice. */
function bandpass(signal: Float64Array, [low, high]: [number, number]) {
  const up = 1 - Math.exp((-2 * Math.PI * high) / RATE);
  const down = 1 - Math.exp((-2 * Math.PI * low) / RATE);
  for (let pass = 0; pass < 2; pass++) {
    let top = 0;
    let bottom = 0;
    for (let n = 0; n < signal.length; n++) {
      top += up * (signal[n]! - top);
      bottom += down * (top - bottom);
      signal[n] = top - bottom;
    }
  }
}

/** One burst of noise in its band, shaped, its loudest sample at `level`. */
function burst(out: Float64Array, next: () => number, at: number, attack: number, decay: number, band: [number, number], level: number) {
  const start = Math.round(at * RATE);
  const length = Math.min(out.length - start, Math.ceil((attack + decay * 8) * RATE));
  if (length <= 0) return;
  const noise = new Float64Array(length);
  for (let n = 0; n < length; n++) noise[n] = next() * 2 - 1;
  bandpass(noise, band);
  let peak = 0;
  for (let n = 0; n < length; n++) {
    noise[n]! *= envelope(n / RATE, attack, decay);
    peak = Math.max(peak, Math.abs(noise[n]!));
  }
  for (let n = 0; n < length; n++) out[start + n]! += (noise[n]! / (peak || 1)) * level;
}

function noise(out: Float64Array, layer: Noise, next: () => number) {
  burst(out, next, layer.at, layer.attack, layer.decay, layer.band, layer.level);
}

function grains(out: Float64Array, layer: Grains, next: () => number) {
  const [low, high] = layer.band;
  for (let i = 0; i < layer.count; i++) {
    // Most of them early; each in a part of the band of its own, so no two
    // crackles are the same.
    const when = Math.pow(next(), 1.6);
    const decay = layer.decay[0] + next() * (layer.decay[1] - layer.decay[0]);
    const from = low * Math.pow(high / low, next() * 0.6);
    const loud = Math.pow(1 - when, layer.fall) * (0.4 + next() * 0.6);
    burst(out, next, layer.at + when * layer.span, 0.0008, decay, [from, Math.min(high, from * 3)], loud * layer.level);
  }
}

/** One recipe as samples, one channel, between -1 and 1. */
export function synthesize(name: string, sound: Sound): Float64Array {
  const out = new Float64Array(Math.round(sound.length * RATE));
  sound.layers.forEach((layer: Layer, i) => {
    const next = random(hash(`${name}/${i}`));
    if (layer.kind === "tone") tone(out, layer);
    else if (layer.kind === "noise") noise(out, layer, next);
    else grains(out, layer, next);
  });
  const tail = Math.round(TAIL * RATE);
  for (let n = 0; n < tail; n++) out[out.length - 1 - n]! *= n / tail;
  let peak = 0;
  for (const sample of out) peak = Math.max(peak, Math.abs(sample));
  const gain = Math.pow(10, sound.peak / 20) / (peak || 1);
  for (let n = 0; n < out.length; n++) out[n]! *= gain;
  return out;
}

/** Samples as a WAV file: 16 bits, the same in both channels. */
export function wav(samples: Float64Array): Uint8Array {
  const bytes = samples.length * CHANNELS * 2;
  const file = new Uint8Array(44 + bytes);
  const view = new DataView(file.buffer);
  const text = (at: number, word: string) => [...word].forEach((c, i) => view.setUint8(at + i, c.charCodeAt(0)));
  text(0, "RIFF");
  view.setUint32(4, 36 + bytes, true);
  text(8, "WAVE");
  text(12, "fmt ");
  view.setUint32(16, 16, true);
  view.setUint16(20, 1, true);
  view.setUint16(22, CHANNELS, true);
  view.setUint32(24, RATE, true);
  view.setUint32(28, RATE * CHANNELS * 2, true);
  view.setUint16(32, CHANNELS * 2, true);
  view.setUint16(34, 16, true);
  text(36, "data");
  view.setUint32(40, bytes, true);
  samples.forEach((sample, n) => {
    const value = Math.round(Math.max(-1, Math.min(1, sample)) * 32767);
    for (let channel = 0; channel < CHANNELS; channel++) view.setInt16(44 + (n * CHANNELS + channel) * 2, value, true);
  });
  return file;
}

const index = `[Sound Theme]
Name=Ambrosia
Comment=Ambrosia's own sounds: the alert, the Trash, a screenshot, the volume
Inherits=ocean
Directories=stereo
Example=bell

[stereo]
OutputProfile=stereo
`;

/** The theme's files under dist/, and the links for each sound's other names. */
export function soundTheme(): { files: Record<string, string | Uint8Array>; links: Record<string, string> } {
  const dir = `sounds/${SOUND_THEME}`;
  const files: Record<string, string | Uint8Array> = { [`${dir}/index.theme`]: index };
  const links: Record<string, string> = {};
  for (const [name, sound] of Object.entries(sounds)) {
    files[`${dir}/stereo/${name}.wav`] = wav(synthesize(name, sound));
    for (const other of sound.also ?? []) links[`${dir}/stereo/${other}.wav`] = `${name}.wav`;
  }
  return { files, links };
}
