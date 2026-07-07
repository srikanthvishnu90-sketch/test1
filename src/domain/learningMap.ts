/**
 * Learning map — the externalized skill progression a student locates themselves
 * on. Here: the progression of CALIBRATION skill. Pure domain. Trajectory over
 * any single judgment: the student is located from their recent evidence, and
 * the map moves as more cycles accumulate.
 */

export interface Stage {
  readonly id: string;
  readonly label: string;
  readonly description: string;
}

export const CALIBRATION_STAGES: readonly Stage[] = [
  {
    id: "forming",
    label: "Forming",
    description: "Confidence and results still diverge a lot.",
  },
  {
    id: "emerging",
    label: "Emerging",
    description: "Confidence tracks results some of the time.",
  },
  {
    id: "reliable",
    label: "Reliable",
    description: "Confidence closely matches results.",
  },
];

/**
 * Locate the student from their recent Brier scores (lower = better calibrated).
 * With no evidence yet, they start at the first stage.
 */
export function locateOnMap(recentBriers: readonly number[]): Stage {
  if (recentBriers.length === 0) {
    return CALIBRATION_STAGES[0];
  }
  const mean =
    recentBriers.reduce((sum, b) => sum + b, 0) / recentBriers.length;

  if (mean <= 0.1) return CALIBRATION_STAGES[2]; // reliable
  if (mean <= 0.25) return CALIBRATION_STAGES[1]; // emerging
  return CALIBRATION_STAGES[0]; // forming
}
