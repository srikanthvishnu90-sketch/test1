/**
 * Cycle — the data captured in one completed loop (prediction → outcome →
 * calibration, and an optional reflection). Pure domain; identity and timestamp
 * are assigned by the persistence adapter, not here.
 */

import type { Prediction } from "./prediction";
import type { Outcome } from "./outcome";
import type { Calibration } from "./calibration";
import type { Reflection } from "./reflection";

/** A completed loop, before it is persisted. */
export interface NewCycle {
  readonly prediction: Prediction;
  readonly outcome: Outcome;
  readonly calibration: Calibration;
  readonly reflection: Reflection | null;
}

/** A persisted cycle: a NewCycle with an identity and a creation timestamp. */
export interface Cycle extends NewCycle {
  readonly id: string;
  readonly createdAt: string; // ISO 8601
}
