// Turns a (response, damping) spring into physical constants, a settle time,
// and a sampled curve for toolkits that can only play back easing curves.

import type { Spring } from "../../design/tokens";

export interface SolvedSpring {
  mass: number;
  stiffness: number;
  /** Damping coefficient (not the 0–1 damping fraction). */
  damping: number;
  /** Milliseconds until the spring is visually at rest. */
  duration: number;
  /** Progress samples at even time steps from 0 to `duration`. */
  samples: number[];
}

const STEP = 1 / 2000; // seconds per integration step
const REST = 0.001; // displacement below this (0.1%) counts as at rest
const REST_VELOCITY = 0.02; // progress per second
const SAMPLES = 48;

export function solveSpring({ response, damping }: Spring): SolvedSpring {
  const stiffness = (2 * Math.PI / response) ** 2;
  const coefficient = (4 * Math.PI * damping) / response;

  // Semi-implicit Euler from 0 toward 1, recording the whole trajectory.
  const path: number[] = [0];
  let x = 0;
  let v = 0;
  let restSince = -1;
  for (let i = 1; i < 20_000; i++) {
    v += (-stiffness * (x - 1) - coefficient * v) * STEP;
    x += v * STEP;
    path.push(x);
    const atRest = Math.abs(1 - x) < REST && Math.abs(v) < REST_VELOCITY;
    if (atRest && restSince < 0) restSince = i;
    if (!atRest) restSince = -1;
    // Stay at rest for 50ms before calling it settled.
    if (restSince > 0 && i - restSince > 0.05 / STEP) break;
  }

  const settled = restSince > 0 ? restSince : path.length - 1;
  const duration = Math.round((settled * STEP * 1000) / 10) * 10;
  const samples = Array.from({ length: SAMPLES + 1 }, (_, i) => {
    const at = Math.round((i / SAMPLES) * settled);
    return i === SAMPLES ? 1 : +path[at]!.toFixed(4);
  });

  return { mass: 1, stiffness: +stiffness.toFixed(2), damping: +coefficient.toFixed(2), duration, samples };
}

/** CSS `linear()` easing that replays the spring over its `duration`. */
export const toCssLinear = (s: SolvedSpring) => `linear(${s.samples.map((v) => +v.toFixed(3)).join(", ")})`;
