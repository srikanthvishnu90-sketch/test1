/**
 * Prediction — a student's pre-registered estimate, captured BEFORE the outcome
 * is known. Item-level confidence (probability 0..1) + a global predicted score
 * (0..1). See CLAUDE.md → Domain glossary.
 *
 * Pure domain: no imports from next, react, or any adapter. Value objects are
 * immutable and self-validating — an invalid Prediction cannot be constructed.
 */

/** A probability in the closed interval [0, 1]. */
export type Probability = number & { readonly __brand: "Probability" };

/** Smart constructor: the only way to obtain a Probability. Throws if out of range. */
export function probability(value: number): Probability {
  if (!Number.isFinite(value) || value < 0 || value > 1) {
    throw new RangeError(`Probability must be within [0, 1]; got ${value}`);
  }
  return value as Probability;
}

/** The student's probability that a given item is answered correctly. */
export interface ItemConfidence {
  readonly itemId: string;
  readonly confidence: Probability;
}

export interface Prediction {
  /** Per-item confidence. Non-empty; itemIds unique. */
  readonly items: readonly ItemConfidence[];
  /** The student's global predicted score, a probability in [0, 1]. */
  readonly predictedScore: Probability;
}

export interface PredictionInput {
  readonly items: ReadonlyArray<{ readonly itemId: string; readonly confidence: number }>;
  readonly predictedScore: number;
}

/** Build a Prediction, enforcing every invariant. Throws on invalid input. */
export function createPrediction(input: PredictionInput): Prediction {
  if (input.items.length === 0) {
    throw new RangeError("A prediction must cover at least one item.");
  }

  const seen = new Set<string>();
  const items: ItemConfidence[] = input.items.map((it) => {
    if (it.itemId.trim() === "") {
      throw new RangeError("Every item must have a non-empty itemId.");
    }
    if (seen.has(it.itemId)) {
      throw new RangeError(`Duplicate itemId: ${it.itemId}`);
    }
    seen.add(it.itemId);
    return { itemId: it.itemId, confidence: probability(it.confidence) };
  });

  return {
    items,
    predictedScore: probability(input.predictedScore),
  };
}
