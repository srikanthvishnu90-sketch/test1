#!/usr/bin/env bash
# DEV-ONLY: stand up a local Postgres 17 + pgvector, apply the SHIPPED retrieval
# migration (20260705) against a minimal schema, and load the eval seed catalog.
# Then: export EVAL_PGDSN="host=/tmp/pgs17 port=5437 dbname=eval user=postgres"
#       python3 eval/run_hybrid_eval.py
# Requires: brew install postgresql@17 pgvector
set -e
export LC_ALL=C LANG=C
PG=/opt/homebrew/opt/postgresql@17/bin
HERE="$(cd "$(dirname "$0")" && pwd)"
DATA="${EVAL_PGDATA:-/tmp/eval_pgdata}"; SOCK=/tmp/pgs17; PORT=5437
[ -x "$PG/initdb" ] || { echo "postgresql@17 not found — brew install postgresql@17 pgvector"; exit 1; }

"$PG/pg_ctl" -D "$DATA" stop >/dev/null 2>&1 || true
rm -rf "$DATA"; mkdir -p "$DATA" "$SOCK"
"$PG/initdb" -D "$DATA" -U postgres --locale=C -E UTF8 >/dev/null 2>&1
"$PG/pg_ctl" -D "$DATA" -o "-p $PORT -k $SOCK" -l /tmp/eval_pg.log start >/dev/null 2>&1
sleep 3
export PGHOST="$SOCK" PGPORT="$PORT" PGUSER=postgres
"$PG/createdb" eval
"$PG/psql" -d eval -v ON_ERROR_STOP=1 -q -c "create role anon nologin; create role authenticated nologin; create role service_role nologin;"
"$PG/psql" -d eval -v ON_ERROR_STOP=1 -q <<'SQL'
create extension if not exists pgcrypto;
create extension if not exists vector;
create table profiles (id uuid primary key default gen_random_uuid());
create table providers (id uuid primary key default gen_random_uuid(), owner_id uuid, bio text,
  latitude double precision, longitude double precision, location text);
create table programs (id uuid primary key default gen_random_uuid(),
  provider_id uuid references providers(id) on delete cascade,
  title text, description text, sport_type text not null, skill_level text, age_group text,
  whats_included text[] not null default '{}', price numeric(10,2) not null default 0,
  currency text not null default 'USD', minimum_age int, maximum_age int,
  status text not null default 'draft', average_rating numeric(2,1) not null default 0,
  total_reviews int not null default 0, latitude double precision, longitude double precision,
  embedding vector(1536));
create table sessions (id uuid primary key default gen_random_uuid(),
  program_id uuid references programs(id) on delete cascade, start_date date, capacity int not null default 0);
create table bookings (id uuid primary key default gen_random_uuid(),
  session_id uuid references sessions(id) on delete set null, status text not null default 'pending');
create table reviews (id uuid primary key default gen_random_uuid(),
  program_id uuid references programs(id) on delete cascade, author_id uuid, rating int, body text,
  created_at timestamptz not null default now());
SQL
"$PG/psql" -d eval -v ON_ERROR_STOP=1 -f "$HERE/../supabase/migrations/20260705_000000_search_listings.sql" >/dev/null
"$PG/psql" -d eval -v ON_ERROR_STOP=1 -q -f "$HERE/seed.sql"
echo "eval DB ready: host=$SOCK port=$PORT dbname=eval  ($("$PG/psql" -d eval -tA -c 'select count(*) from programs') listings)"
echo 'run: export EVAL_PGDSN="host=/tmp/pgs17 port=5437 dbname=eval user=postgres"; python3 eval/run_hybrid_eval.py'
