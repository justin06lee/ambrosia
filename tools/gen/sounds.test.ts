import { expect, test } from "bun:test";
import { sounds } from "../../design/sounds";
import { RATE, SOUND_THEME, soundTheme, synthesize, wav } from "./targets/sounds";

// Nobody can listen to a build: the sounds are held to what can be
// measured. That a note is where its recipe says, that nothing clips,
// clicks or sits off the middle, and that the same recipe gives the same
// file every time.

const theme = soundTheme();
const dir = `sounds/${SOUND_THEME}`;
const db = (level: number) => 20 * Math.log10(level);
const peak = (samples: Float64Array) => samples.reduce((most, sample) => Math.max(most, Math.abs(sample)), 0);

/** How strongly `samples` holds `freq` (one bin of a Fourier transform). */
function strength(samples: Float64Array, freq: number): number {
  let re = 0;
  let im = 0;
  for (let n = 0; n < samples.length; n++) {
    re += samples[n]! * Math.cos((2 * Math.PI * freq * n) / RATE);
    im += samples[n]! * Math.sin((2 * Math.PI * freq * n) / RATE);
  }
  return Math.hypot(re, im);
}

/** The strongest pitch between 60 Hz and 4 kHz, to the nearest 5 Hz. */
export function loudestPitch(samples: Float64Array): number {
  let best = 0;
  let most = 0;
  for (let freq = 60; freq <= 4000; freq += 5) {
    const s = strength(samples, freq);
    if (s > most) [most, best] = [s, freq];
  }
  return best;
}

test("the theme is one freedesktop sound themes can be read as", () => {
  const index = theme.files[`${dir}/index.theme`] as string;
  expect(index).toContain("[Sound Theme]");
  expect(index).toContain("Directories=stereo");
  expect(index).toContain("[stereo]\nOutputProfile=stereo");
  // The four the design asks for, by the names KDE and GTK look up.
  for (const name of ["bell", "trash-empty", "screen-capture", "audio-volume-change"]) {
    expect(theme.files[`${dir}/stereo/${name}.wav`], name).toBeDefined();
  }
});

test("every other name is a link to a sound that is there, and none shadows one", () => {
  for (const [link, target] of Object.entries(theme.links)) {
    expect(theme.files[`${dir}/stereo/${target}`], link).toBeDefined();
    expect(theme.files[link], link).toBeUndefined();
  }
  expect(theme.links[`${dir}/stereo/dialog-warning.wav`]).toBe("bell.wav");
});

test("each file is a 48 kHz, 16-bit, two-channel WAV as long as its recipe says", () => {
  for (const [name, sound] of Object.entries(sounds)) {
    const file = theme.files[`${dir}/stereo/${name}.wav`] as Uint8Array;
    const view = new DataView(file.buffer, file.byteOffset, file.byteLength);
    expect(new TextDecoder().decode(file.subarray(0, 4)) + new TextDecoder().decode(file.subarray(8, 12))).toBe("RIFFWAVE");
    expect([view.getUint16(20, true), view.getUint16(22, true), view.getUint32(24, true), view.getUint16(34, true)]).toEqual([1, 2, RATE, 16]);
    expect(view.getUint32(40, true)).toBe(file.length - 44);
    expect((file.length - 44) / 4 / RATE).toBeCloseTo(sound.length, 3);
    expect(view.getUint32(4, true)).toBe(file.length - 8);
  }
});

test("each sound peaks where its recipe says, and is short", () => {
  for (const [name, sound] of Object.entries(sounds)) {
    const samples = synthesize(name, sound);
    expect(db(peak(samples)), name).toBeCloseTo(sound.peak, 1);
    expect(sound.peak, name).toBeLessThanOrEqual(-6);
    expect(sound.length, name).toBeLessThanOrEqual(1.2);
  }
});

test("no sound starts or ends with a click, or sits off the middle", () => {
  for (const [name, sound] of Object.entries(sounds)) {
    const samples = synthesize(name, sound);
    const top = peak(samples);
    // The first sample and the last are silence (60 dB under the peak).
    expect(Math.abs(samples[0]!) / top, `${name} starts`).toBeLessThan(0.001);
    expect(Math.abs(samples[samples.length - 1]!) / top, `${name} ends`).toBeLessThan(0.001);
    // What is left by the end has died away: the last 20 ms are 30 dB down.
    expect(db(peak(samples.subarray(samples.length - RATE * 0.02)) / top), `${name} tail`).toBeLessThan(-30);
    const mean = samples.reduce((sum, sample) => sum + sample, 0) / samples.length;
    expect(Math.abs(mean) / top, `${name} offset`).toBeLessThan(0.01);
  }
});

test("a note is at the pitch its recipe names", () => {
  // The alert is its one note; the notification's stronger note is its second.
  expect(Math.abs(loudestPitch(synthesize("bell", sounds.bell!)) - 659.26)).toBeLessThan(6);
  expect(Math.abs(loudestPitch(synthesize("message-new-instant", sounds["message-new-instant"]!)) - 1046.5)).toBeLessThan(6);
  expect(Math.abs(loudestPitch(synthesize("power-plug", sounds["power-plug"]!)) - 659.26)).toBeLessThan(6);
  // The volume's pop slides from 720 to 540.
  const pop = loudestPitch(synthesize("audio-volume-change", sounds["audio-volume-change"]!));
  expect(pop).toBeGreaterThan(540);
  expect(pop).toBeLessThan(720);
});

test("the shutter is two clicks, the second the louder", () => {
  const samples = synthesize("screen-capture", sounds["screen-capture"]!);
  const first = peak(samples.subarray(0, RATE * 0.06));
  const between = peak(samples.subarray(RATE * 0.055, RATE * 0.07));
  const second = peak(samples.subarray(RATE * 0.07, RATE * 0.14));
  expect(second).toBeGreaterThan(first);
  expect(between).toBeLessThan(first * 0.2);
});

test("the crumple is noise, not a note, and thins out", () => {
  const samples = synthesize("trash-empty", sounds["trash-empty"]!);
  const energy = (from: number, to: number) => samples.subarray(RATE * from, RATE * to).reduce((sum, sample) => sum + sample * sample, 0);
  expect(energy(0, 0.3)).toBeGreaterThan(energy(0.3, 0.6) * 2);
  // No one pitch holds more than a fifth of what the whole does.
  const whole = Math.sqrt(samples.reduce((sum, sample) => sum + sample * sample, 0) * samples.length);
  expect(strength(samples, loudestPitch(samples)) / whole).toBeLessThan(0.2);
});

test("the same recipe gives the same bytes", () => {
  const again = soundTheme();
  for (const [path, content] of Object.entries(theme.files)) {
    if (typeof content !== "string") expect(Buffer.compare(Buffer.from(content), Buffer.from(again.files[path] as Uint8Array)), path).toBe(0);
  }
  expect(wav(new Float64Array([0, 1, -1])).length).toBe(44 + 12);
});
