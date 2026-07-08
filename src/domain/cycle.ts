/**
 * Cycle — the data captured in one completed loop (prediction → outcome →
 * calibration), plus the reflections a student adds afterward: one Reflection
 * per reviewed wrong item, and the closing ScoreReflection. Pure domain;
 * identity and timestamp are assigned by the persistence adapter, not here.
 */

import type { Prediction } from "./prediction";
import type { Outcome } from "./outcome";
import type { Calibration } from "./calibration";
import type { Reflection } from "./reflection";
import type { ScoreReflection } from "./scoreReflection";

/** The reflections attached to a cycle after the truth is revealed. */
export interface CycleReflections {
  readonly itemReflections: readonly Reflection[];
  readonly scoreReflection: ScoreReflection | null;
}

/** A completed loop, before it is persisted. Reflections start empty. */
export interface NewCycle {
  readonly prediction: Prediction;
  readonly outcome: Outcome;
  readonly calibration: Calibration;
  readonly itemReflections: readonly Reflection[];
  readonly scoreReflection: ScoreReflection | null;
}

/** A persisted cycle: a NewCycle with an identity and a creation timestamp. */
export interface Cycle extends NewCycle {
  readonly id: string;
  readonly createdAt: string; // ISO 8601
}
