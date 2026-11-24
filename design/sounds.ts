// Ambrosia's sounds: the few a Mac makes by itself, written as recipes and
// synthesized by tools/gen (targets/sounds.ts) into a freedesktop sound
// theme, "ambrosia". Short, soft and pitched, as a Mac's are; each is our
// own, built from tones and filtered noise, not a recording of anyone's.
//
// A sound is layers mixed together. Times are seconds, frequencies hertz,
// levels 0 to 1 against the other layers of the same sound; the whole is
// then brought to `peak` (dBFS).
//
// Nobody has listened to these yet: they are checked by their numbers
// (tools/gen/sounds.test.ts). Tune them here by ear.

/** A pitched note: a sine and its partials, struck and left to ring. */
export type Tone = {
  kind: "tone";
  at: number;
  freq: number;
  /** Where the pitch has slid to by the time the note has died away. */
  to?: number;
  /** Seconds to full strength. */
  attack: number;
  /** Seconds for the note to fall to about a third (its time constant). */
  decay: number;
  level: number;
  /** Partials above the note itself: [times its pitch, level, decay as a share of the note's]. */
  partials?: [multiple: number, level: number, decay: number][];
};

/** A burst of noise kept to a band: a click, a puff, a thump's breath. */
export type Noise = {
  kind: "noise";
  at: number;
  attack: number;
  decay: number;
  band: [low: number, high: number];
  level: number;
};

/** Many small bursts thinning out: paper crumpling. */
export type Grains = {
  kind: "grains";
  at: number;
  /** Seconds the bursts are spread over, most of them early. */
  span: number;
  count: number;
  decay: [shortest: number, longest: number];
  band: [low: number, high: number];
  /** How steeply later bursts are quieter: 1 falls evenly, more falls sooner. */
  fall: number;
  level: number;
};

export type Layer = Tone | Noise | Grains;

export type Sound = {
  /** What it is for, in a line. */
  says: string;
  length: number;
  /** The loudest sample, dBFS. */
  peak: number;
  layers: Layer[];
  /** Other names of the sound-naming spec this sound answers to. */
  also?: string[];
};

/** A struck bar's upper partials: the octave, and the one a marimba is tuned to. */
const BAR: Tone["partials"] = [
  [2, 0.16, 0.6],
  [4, 0.1, 0.3],
];

/** Sound-theme names (the freedesktop sound naming spec, and two of our own). */
export const sounds: Record<string, Sound> = {
  // The alert: one soft wooden note. KWin plays it as the bell; apps'
  // warnings and errors are the same sound, as on a Mac.
  bell: {
    says: "the alert",
    length: 0.42,
    peak: -6,
    layers: [
      { kind: "tone", at: 0, freq: 659.26, attack: 0.004, decay: 0.085, level: 1, partials: BAR },
      { kind: "noise", at: 0, attack: 0.001, decay: 0.005, band: [1500, 5000], level: 0.12 },
    ],
    also: ["bell-window-system", "dialog-warning", "dialog-error", "dialog-information", "dialog-question"],
  },
  // A volume key: a small pop, falling a little as it goes.
  "audio-volume-change": {
    says: "a step of the volume",
    length: 0.14,
    peak: -9,
    layers: [{ kind: "tone", at: 0, freq: 720, to: 540, attack: 0.002, decay: 0.022, level: 1, partials: [[2, 0.1, 0.5]] }],
  },
  // A picture of the screen: a shutter, its two clicks.
  "screen-capture": {
    says: "a picture of the screen taken",
    length: 0.3,
    peak: -6,
    layers: [
      { kind: "noise", at: 0, attack: 0.0005, decay: 0.01, band: [1200, 7000], level: 0.7 },
      { kind: "tone", at: 0, freq: 1900, attack: 0.0005, decay: 0.007, level: 0.2 },
      { kind: "noise", at: 0.072, attack: 0.0005, decay: 0.018, band: [700, 5500], level: 1 },
      { kind: "tone", at: 0.072, freq: 1320, attack: 0.0005, decay: 0.011, level: 0.25 },
      { kind: "tone", at: 0.072, freq: 190, to: 140, attack: 0.002, decay: 0.03, level: 0.4 },
    ],
    also: ["camera-shutter"],
  },
  // Something dropped into the Trash: a soft thump and what settles after.
  "trash-fill": {
    says: "something moved to the Trash",
    length: 0.36,
    peak: -8,
    layers: [
      { kind: "tone", at: 0, freq: 150, to: 85, attack: 0.003, decay: 0.055, level: 0.9 },
      { kind: "noise", at: 0, attack: 0.003, decay: 0.045, band: [300, 2600], level: 0.6 },
      { kind: "noise", at: 0.095, attack: 0.004, decay: 0.04, band: [500, 3200], level: 0.22 },
    ],
  },
  // The Trash emptied: paper crumpled and gone.
  "trash-empty": {
    says: "the Trash emptied",
    length: 0.9,
    peak: -8,
    layers: [
      { kind: "grains", at: 0, span: 0.62, count: 34, decay: [0.006, 0.028], band: [900, 7500], fall: 1.4, level: 1 },
      { kind: "noise", at: 0, attack: 0.05, decay: 0.22, band: [400, 3000], level: 0.2 },
    ],
  },
  // A notification that asks for a sound: two notes, a fourth apart, rising.
  "message-new-instant": {
    says: "a notification",
    length: 0.8,
    peak: -8,
    layers: [
      { kind: "tone", at: 0, freq: 783.99, attack: 0.005, decay: 0.15, level: 0.8, partials: [[2, 0.12, 0.5], [3, 0.04, 0.4]] },
      { kind: "tone", at: 0.11, freq: 1046.5, attack: 0.005, decay: 0.2, level: 1, partials: [[2, 0.12, 0.5], [3, 0.04, 0.4]] },
    ],
    also: ["message", "message-new-email"],
  },
  // Power connected: one long note with its fifth inside it.
  "power-plug": {
    says: "the power adapter connected",
    length: 1.1,
    peak: -9,
    layers: [
      { kind: "tone", at: 0, freq: 659.26, attack: 0.008, decay: 0.3, level: 1, partials: [[2, 0.14, 0.6]] },
      { kind: "tone", at: 0, freq: 987.77, attack: 0.008, decay: 0.24, level: 0.45 },
    ],
  },
};
