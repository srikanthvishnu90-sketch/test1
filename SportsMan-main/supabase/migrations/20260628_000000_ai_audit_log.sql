-- ============================================================================
-- Sporve — AI audit log                                            2026-06-28
-- ============================================================================
-- One row per AI gateway call: which feature/model, who triggered it, token
-- counts, estimated cost, latency, and SUMMARIES/HASHES of the I/O — never full
-- prompt/response text, PII, or secrets (the ai-gateway writes hashes + sizes).
--
-- ACCESS:
--   • Writes: SERVICE ROLE ONLY (the ai-gateway uses the service-role client,
--     which bypasses RLS). There is no client insert path.
--   • Reads:  SERVICE ROLE (and, in future, admins). No anon/authenticated read.
--     The schema has no admin role yet (profiles.role ∈ searcher|provider), so
--     no client read policy is added — add one keyed to an admin role when it
--     exists. Until then RLS default-deny + the grant revoke below keep it
--     service-role-only. No existing policy is touched.
--
-- Idempotent. Safe to re-run.
-- ============================================================================

create table if not exists public.ai_audit_log (
  id              uuid primary key default gen_random_uuid(),
  created_at      timestamptz not null default now(),
  feature         text not null,
  model           text not null,
  actor_id        uuid references public.profiles (id) on delete set null,
  actor_role      text,
  input_summary   text,                              -- summary/hash ONLY (no PII/secrets)
  output_summary  text,                              -- summary/hash ONLY (no PII/secrets)
  tokens_in       integer not null default 0,
  tokens_out      integer not null default 0,
  est_cost_usd    numeric(12,6) not null default 0,
  approved_by     uuid references public.profiles (id) on delete set null,
  latency_ms      integer
);

create index if not exists idx_ai_audit_log_created  on public.ai_audit_log (created_at desc);
create index if not exists idx_ai_audit_log_actor    on public.ai_audit_log (actor_id);
create index if not exists idx_ai_audit_log_feature  on public.ai_audit_log (feature);

-- Default-deny: RLS on, no client policies → only the service role (which
-- bypasses RLS) can read or write. (rls_auto_enable also covers this; explicit
-- for clarity and to stay correct if that trigger is ever absent.)
alter table public.ai_audit_log enable row level security;

-- Belt-and-suspenders: remove the table-level API grant that baseline default
-- privileges hand to `authenticated`, so PostgREST never even exposes this table
-- to client roles. service_role retains access (granted separately by Supabase).
revoke all on public.ai_audit_log from anon, authenticated;
