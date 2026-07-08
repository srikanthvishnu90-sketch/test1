import type { Pool } from "pg";
import type { CycleRepository } from "@/domain/ports/cycleRepository";
import type { Cycle, NewCycle, CycleReflections } from "@/domain/cycle";
import { rowToCycle, type CycleRow } from "./rowToCycle";

const COLUMNS = `id, created_at, prediction, outcome, calibration, item_reflections, score_reflection`;

/**
 * Postgres-backed implementation of the CycleRepository port. Domain objects are
 * stored as jsonb (run adapters/postgres/schema.sql once). SERVER-SIDE ONLY — it
 * uses the `pg` driver. The Pool is injected so this class is decoupled from
 * connection management.
 */
export class PgCycleRepository implements CycleRepository {
  constructor(private readonly pool: Pool) {}

  async save(cycle: NewCycle): Promise<Cycle> {
    const { rows } = await this.pool.query<CycleRow>(
      `insert into cycles (prediction, outcome, calibration, item_reflections, score_reflection)
       values ($1, $2, $3, $4, $5)
       returning ${COLUMNS}`,
      [
        JSON.stringify(cycle.prediction),
        JSON.stringify(cycle.outcome),
        JSON.stringify(cycle.calibration),
        JSON.stringify(cycle.itemReflections),
        cycle.scoreReflection ? JSON.stringify(cycle.scoreReflection) : null,
      ],
    );
    return rowToCycle(rows[0]);
  }

  async attachReflections(
    id: string,
    reflections: CycleReflections,
  ): Promise<Cycle> {
    const { rows } = await this.pool.query<CycleRow>(
      `update cycles
         set item_reflections = $1, score_reflection = $2
       where id = $3
       returning ${COLUMNS}`,
      [
        JSON.stringify(reflections.itemReflections),
        reflections.scoreReflection
          ? JSON.stringify(reflections.scoreReflection)
          : null,
        id,
      ],
    );
    if (rows.length === 0) {
      throw new RangeError(`No cycle with id ${id}.`);
    }
    return rowToCycle(rows[0]);
  }

  async list(): Promise<readonly Cycle[]> {
    const { rows } = await this.pool.query<CycleRow>(
      `select ${COLUMNS} from cycles order by created_at asc`,
    );
    return rows.map(rowToCycle);
  }
}
