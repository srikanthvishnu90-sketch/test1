-- ============================================================================
-- RLS verification for parent_updates (run AFTER the migration is applied).
-- Paste into the Supabase SQL Editor and Run. It seeds inside a transaction and
-- ROLLS BACK at the end, so it leaves no data behind. Nothing here is a migration.
--
-- Proves: (1) a guardian CANNOT read another child's rows (no cross-child leak),
--         (2) a guardian CANNOT see any non-'sent' row,
--         (3) the real guardian sees ONLY their child's 'sent' rows.
--
-- STEP 0 — find ids first (run these, then paste the values below):
--   select id, parent_id, first_name from public.athletes;     -- pick childA + a different childB
--   select id, owner_id, business_name from public.providers;  -- pick any provider
-- ============================================================================

begin;

-- >>> FILL THESE THREE <<<
\set provider '00000000-0000-0000-0000-000000000000'
\set childA   '00000000-0000-0000-0000-000000000000'
\set childB   '00000000-0000-0000-0000-000000000000'

-- Setup runs as the SQL-Editor superuser (RLS bypassed): two rows for child A.
insert into public.parent_updates (provider_id, child_id, summary_body, status) values
  (:'provider', :'childA', 'SENT update for child A',  'sent'),
  (:'provider', :'childA', 'DRAFT update for child A', 'draft');

-- ── Impersonate PARENT B (guardian of child B only) ─────────────────────────
select set_config('request.jwt.claims',
  json_build_object('sub', (select parent_id from public.athletes where id = :'childB')::text)::text, true);
set local role authenticated;

-- TEST 1 — cross-child leak: MUST be 0
select 'T1 parentB sees child A rows (expect 0)' as test, count(*) as rows
from public.parent_updates where child_id = :'childA';

-- TEST 2 — non-'sent' visibility: MUST be 0
select 'T2 parentB sees any non-sent rows (expect 0)' as test, count(*) as rows
from public.parent_updates where status <> 'sent';

-- ── Impersonate PARENT A (real guardian of child A) ─────────────────────────
reset role;
select set_config('request.jwt.claims',
  json_build_object('sub', (select parent_id from public.athletes where id = :'childA')::text)::text, true);
set local role authenticated;

-- TEST 3 — guardian sees ONLY the 'sent' row: sent expect 1, draft expect 0
select 'T3 parentA sees child A SENT rows (expect 1)' as test, count(*) as rows
from public.parent_updates where child_id = :'childA' and status = 'sent';
select 'T4 parentA sees child A DRAFT rows (expect 0)' as test, count(*) as rows
from public.parent_updates where child_id = :'childA' and status = 'draft';

reset role;
rollback;
