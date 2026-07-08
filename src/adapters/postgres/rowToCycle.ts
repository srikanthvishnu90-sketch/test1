import type { Cycle } from "@/domain/cycle";
import type { Prediction } from "@/domain/prediction";
import type { Outcome } from "@/domain/outcome";
import type { Calibration } from "@/domain/calibration";
import type { Reflection } from "@/domain/reflection";
import type { ScoreReflection } from "@/domain/scoreReflection";

/**
 * A row from the `cycles` table. jsonb columns come back already parsed, and
 * `created_at` may be a Date or a string depending on the pg type parser.
 * Declared as a type alias (not interface) so it satisfies pg's QueryResultRow.
 */
export type CycleRow = {
  id: string;
  created_at: Date | string;
  prediction: unknown;
  outcome: unknown;
  calibration: unknown;
  item_reflections: unknown;
  score_reflection: unknown;
};

/** Pure mapping from a db row to a domain Cycle. No I/O — unit-testable. */
export function rowToCycle(row: CycleRow): Cycle {
  return {
    id: row.id,
    createdAt:
      row.created_at instanceof Date
        ? row.created_at.toISOString()
        : String(row.created_at),
    prediction: row.prediction as Prediction,
    outcome: row.outcome as Outcome,
    calibration: row.calibration as Calibration,
    itemReflections: (row.item_reflections ?? []) as readonly Reflection[],
    scoreReflection: (row.score_reflection ?? null) as ScoreReflection | null,
  };
}
