# Postgres adapter

A `pg`-backed implementation of the `CycleRepository` port — the same interface
the rest of the app depends on. Swapping to it requires **no changes to any
consumer**; the choice happens in the server composition root.

## Activate it (3 steps)

1. **Create the table** in your database:
   ```bash
   psql "$DATABASE_URL" -f src/adapters/postgres/schema.sql
   ```
2. **Set the connection string** in `.env.local`:
   ```
   DATABASE_URL=postgres://user:pass@host:5432/dbname
   ```
3. Restart. `src/composition.server.ts` now returns `PgCycleRepository` instead
   of the in-memory one — everywhere on the server.

## Where it's used

- **Server**: the route handler `src/app/api/cycles/route.ts`
  - `GET  /api/cycles` → list persisted cycles
  - `POST /api/cycles` → record one (body = `RecordCycleInput`)
- **Browser demo**: still uses the in-memory adapter (`@/composition`) so the
  interactive page runs with no database. To make the page persist to Postgres,
  point `CalibrationDemo` at `POST /api/cycles` instead of the client repo.

## Notes

- Domain objects are stored as `jsonb`; the pure `rowToCycle` mapper (unit-tested,
  no DB needed) turns rows back into `Cycle`s.
- `pg` is a Node driver and **cannot run in the browser** — only import
  `@/composition.server` (and this adapter) from server code.
