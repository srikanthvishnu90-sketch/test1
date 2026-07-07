/**
 * Calibration — the correspondence between a student's confidence and their
 * correctness. Pure functions over Prediction + Outcome. See CLAUDE.md → Domain
 * glossary. AI is never involved here: calibration is computed deterministically.
 */

import type { Prediction } from "./prediction";
import type { Outcome } from "./outcome";

export interface ItemError {
  readonly itemId: string;
  /** (confidence - correct)^2 for this item. */
  readonly squaredError: number;
}

export interface Calibration {
  /** Mean of (confidence - correct)^2 over items. Lower is better; range 0..1. */
  readonly brier: number;
  /** mean(confidence) - mean(correct). >0 overconfident, <0 underconfident. */
  readonly bias: number;
  readonly meanConfidence: number;
  readonly meanCorrect: number;
  /** Per-item squared error, aligned with prediction.items order. */
  readonly itemError: readonly ItemError[];
}

/**
 * Compute calibration. Prediction and Outcome must cover the exact same item set
 * (order need not match); otherwise this throws rather than guessing.
 */
export function calibrate(prediction: Prediction, outcome: Outcome): Calibration {
  const correctById = new Map(outcome.items.map((it) => [it.itemId, it.correct]));

  if (correctById.size !== prediction.items.length) {
    throw new RangeError("Prediction and outcome must cover the same items.");
  }

  let squaredErrorSum = 0;
  let confidenceSum = 0;
  let correctSum = 0;

  const itemError: ItemError[] = prediction.items.map((it) => {
    const isCorrect = correctById.get(it.itemId);
    if (isCorrect === undefined) {
      throw new RangeError(`Outcome is missing itemId: ${it.itemId}`);
    }
    const correct = isCorrect ? 1 : 0;
    const squaredError = (it.confidence - correct) ** 2;
    squaredErrorSum += squaredError;
    confidenceSum += it.confidence;
    correctSum += correct;
    return { itemId: it.itemId, squaredError };
  });

  const n = prediction.items.length;
  const meanConfidence = confidenceSum / n;
  const meanCorrect = correctSum / n;

  return {
    brier: squaredErrorSum / n,
    bias: meanConfidence - meanCorrect,
    meanConfidence,
    meanCorrect,
    itemError,
  };
}
