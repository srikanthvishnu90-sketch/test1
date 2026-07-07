/**
 * recordCycle — the application use-case that orchestrates one completed cycle:
 * assemble the domain objects from raw inputs, compute calibration, and persist
 * through the CycleRepository port. The UI passes raw values and gets a Cycle
 * back; all domain assembly lives here, not in the view.
 *
 * The repository is injected, so this use-case is fully testable without a
 * browser, database, or network.
 */

import { createPrediction } from "@/domain/prediction";
import { createOutcome } from "@/domain/outcome";
import { calibrate } from "@/domain/calibration";
import type { CycleRepository } from "@/domain/ports/cycleRepository";
import type { Cycle } from "@/domain/cycle";
import type { Reflection } from "@/domain/reflection";

export interface RecordCycleItem {
  readonly itemId: string;
  readonly confidence: number;
  readonly correct: boolean;
}

export interface RecordCycleInput {
  readonly items: readonly RecordCycleItem[];
  readonly predictedScore: number;
  readonly reflection?: Reflection | null;
}

export async function recordCycle(
  repo: CycleRepository,
  input: RecordCycleInput,
): Promise<Cycle> {
  const prediction = createPrediction({
    items: input.items.map((it) => ({
      itemId: it.itemId,
      confidence: it.confidence,
    })),
    predictedScore: input.predictedScore,
  });

  const outcome = createOutcome({
    items: input.items.map((it) => ({ itemId: it.itemId, correct: it.correct })),
  });

  const calibration = calibrate(prediction, outcome);

  const cycle = await repo.save({
    prediction,
    outcome,
    calibration,
    reflection: input.reflection ?? null,
  });
  return cycle;
}
