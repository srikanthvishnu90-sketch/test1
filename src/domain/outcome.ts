/**
 * Outcome — item-level correctness, revealed AFTER the prediction is captured.
 * See CLAUDE.md → Domain glossary. Pure domain; no framework imports.
 */

export interface ItemOutcome {
  readonly itemId: string;
  readonly correct: boolean;
}

export interface Outcome {
  readonly items: readonly ItemOutcome[];
}

export interface OutcomeInput {
  readonly items: ReadonlyArray<{ readonly itemId: string; readonly correct: boolean }>;
}

/** Build an Outcome, enforcing the same structural invariants as Prediction. */
export function createOutcome(input: OutcomeInput): Outcome {
  if (input.items.length === 0) {
    throw new RangeError("An outcome must cover at least one item.");
  }

  const seen = new Set<string>();
  const items: ItemOutcome[] = input.items.map((it) => {
    if (it.itemId.trim() === "") {
      throw new RangeError("Every item must have a non-empty itemId.");
    }
    if (seen.has(it.itemId)) {
      throw new RangeError(`Duplicate itemId: ${it.itemId}`);
    }
    seen.add(it.itemId);
    return { itemId: it.itemId, correct: it.correct };
  });

  return { items };
}
