/**
 * Server-side composition root. Chooses the CycleRepository adapter from the
 * environment: Postgres when DATABASE_URL is set, otherwise in-memory.
 *
 * SERVER ONLY. Imported by route handlers / server code — never by a client
 * component (it pulls in the `pg` driver). The browser demo uses the separate
 * in-memory composition in `@/composition`.
 */

import { Pool } from "pg";
import type { CycleRepository } from "@/domain/ports/cycleRepository";
import { InMemoryCycleRepository } from "@/adapters/memory/inMemoryCycleRepository";
import { PgCycleRepository } from "@/adapters/postgres/pgCycleRepository";

let repo: CycleRepository | undefined;

export function getCycleRepository(): CycleRepository {
  if (!repo) {
    const url = process.env.DATABASE_URL;
    repo = url
      ? new PgCycleRepository(new Pool({ connectionString: url }))
      : new InMemoryCycleRepository();
  }
  return repo;
}
