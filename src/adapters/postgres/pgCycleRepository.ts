import type { Pool } from "pg";
import type { CycleRepository } from "@/domain/ports/cycleRepository";
import type { Cycle, NewCycle } from "@/domain/cycle";
import { rowToCycle, type CycleRow } from "./rowToCycle";

/**
 * Postgres-backed implementation of the CycleRepository port. Domain objects are
 * stored as jsonb (run adapters/postgres/schema.sql once). SERVER-SIDE ONLY — it
 * uses the `pg` driver, which cannot run in the browser. The Pool is injected so
 * this class is decoupled from connection management.
 */
export class PgCycleRepository implements CycleRepository {
  constructor(private readonly pool: Pool) {}

  async save(cycle: NewCycle): Promise<Cycle> {
    const { rows } = await this.pool.query<CycleRow>(
      `insert into cycles (prediction, outcome, calibration, reflection)
       values ($1, $2, $3, $4)
       returning id, created_at, prediction, outcome, calibration, reflection`,
      [
        JSON.stringify(cycle.prediction),
        JSON.stringify(cycle.outcome),
        JSON.stringify(cycle.calibration),
        cycle.reflection ? JSON.stringify(cycle.reflection) : null,
      ],
    );
    return rowToCycle(rows[0]);
  }

  async list(): Promise<readonly Cycle[]> {
    const { rows } = await this.pool.query<CycleRow>(
      `select id, created_at, prediction, outcome, calibration, reflection
       from cycles
       order by created_at asc`,
    );
    return rows.map(rowToCycle);
  }
}
