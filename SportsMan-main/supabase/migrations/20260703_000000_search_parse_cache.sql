-- ============================================================================
-- Sporve — search-parse cache (Stage 3, C1)                          2026-07-03
-- ============================================================================
-- Caches the parsed constraints for identical query strings so a repeated search
-- skips the model entirely (no duplicate ai_audit_log rows, lower latency/cost).
-- Server-only: the search-parse Edge Function reads/writes this with the service
-- role. No client access.
--
-- Idempotent. Safe to re-run.
-- ============================================================================

create table if not exists public.search_parse_cache (
  query_hash    text primary key,        -- sha256(normalized query + '|' + location hint)
  query         text not null,           -- the normalized query (for inspection)
  location_hint jsonb,                    -- the hint that participated in the key (if any)
  result        jsonb not null,          -- the parsed constraints returned to the client
  created_at    timestamptz not null default now()
);
create index if not exists idx_search_parse_cache_created
  on public.search_parse_cache (created_at desc);

-- Service-role only (default-deny RLS + revoked grants). The Edge Function uses
-- the service role; clients never read or write the cache.
alter table public.search_parse_cache enable row level security;
revoke all on public.search_parse_cache from anon, authenticated;
