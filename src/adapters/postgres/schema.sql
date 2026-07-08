-- Postgres schema for the cycles store. Run once against your database:
--   psql "$DATABASE_URL" -f src/adapters/postgres/schema.sql

create extension if not exists pgcrypto; -- for gen_random_uuid()

create table if not exists cycles (
  id           uuid primary key default gen_random_uuid(),
  created_at   timestamptz not null default now(),
  prediction   jsonb not null,
  outcome      jsonb not null,
  calibration  jsonb not null,
  reflection   jsonb
);

create index if not exists cycles_created_at_idx on cycles (created_at);
