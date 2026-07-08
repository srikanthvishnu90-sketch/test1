/**
 * recordCycle — the application use-case that orchestrates one completed cycle:
 * assemble the domain objects from raw inputs, compute calibration, and persist
 * through the CycleRepository port. Reflections are added later via
 * attachReflections. The repository is injected, so this is fully testable
 * without a browser, database, or network.
 */

import { createPrediction } from "@/domain/prediction";
import { createOutcome } from "@/domain/outcome";
import { calibrate } from "@/domain/calibration";
import type { CycleRepository } from "@/domain/ports/cycleRepository";
import type { Cycle, CycleReflections } from "@/domain/cycle";

export interface RecordCycleItem {
  readonly itemId: string;
  readonly confidence: number;
  readonly correct: boolean;
}

export interface RecordCycleInput {
  readonly items: readonly RecordCycleItem[];
  readonly predictedScore: number;
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
    itemReflections: [],
    scoreReflection: null,
  });
  return cycle;
}

/** Attach the student's reflections to a saved cycle. */
export function attachReflections(
  repo: CycleRepository,
  cycleId: string,
  reflections: CycleReflections,
): Promise<Cycle> {
  return repo.attachReflections(cycleId, reflections);
}
