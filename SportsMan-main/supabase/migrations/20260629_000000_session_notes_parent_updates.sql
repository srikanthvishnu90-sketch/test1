-- ============================================================================
-- P2 — Session notes (coach raw input) + Parent updates (the deliverable)
-- ============================================================================
-- Adapts to the real audit schema:
--   • "child"    = public.athletes  (the COPPA minor; guardian = athletes.parent_id)
--   • "coach"    = public.providers (owner = providers.owner_id = auth.uid())
--   • bookings   = public.bookings
-- No existing session_notes table was found in the baseline, so it is created
-- here (not duplicated). Structured progress fields are captured now; NO
-- embedding column yet (added in a later phase).
--
-- FK delete behavior:
--   • booking_id  -> ON DELETE SET NULL  (preserve note/update if a booking is
--                                         removed; financial history is separate)
--   • child_id    -> ON DELETE SET NULL  (preserve the record; RLS then hides it
--                                         from parents since the guardian link is gone)
--   • provider_id -> ON DELETE CASCADE   (a coach's own content goes with them)
--   • session_note_id -> ON DELETE CASCADE (the deliverable derives from the note)
-- ============================================================================

-- ── 1. session_notes (coach's raw input) ───────────────────────────────────
create table if not exists public.session_notes (
  id          uuid primary key default gen_random_uuid(),
  booking_id  uuid references public.bookings (id) on delete set null,
  provider_id uuid not null references public.providers (id) on delete cascade,
  child_id    uuid references public.athletes (id) on delete set null,
  raw_notes   text not null,
  created_at  timestamptz not null default now()
);

create index if not exists idx_session_notes_provider on public.session_notes (provider_id);
create index if not exists idx_session_notes_child    on public.session_notes (child_id);
create index if not exists idx_session_notes_booking  on public.session_notes (booking_id);

-- ── 2. parent_updates (the deliverable) ────────────────────────────────────
create table if not exists public.parent_updates (
  id                   uuid primary key default gen_random_uuid(),
  session_note_id      uuid references public.session_notes (id) on delete cascade,
  booking_id           uuid references public.bookings (id) on delete set null,
  provider_id          uuid not null references public.providers (id) on delete cascade,
  child_id             uuid references public.athletes (id) on delete set null,
  summary_body         text,
  skills_worked        text[] not null default '{}',
  progress_signal      text,
  practice_suggestions text[] not null default '{}',
  encouragement        text,
  status               text not null default 'draft'
                         check (status in ('draft','approved','sent')),
  approved_by          uuid references public.profiles (id) on delete set null,
  approved_at          timestamptz,
  sent_at              timestamptz,
  delivery_channel     text,
  created_at           timestamptz not null default now()
);

create index if not exists idx_parent_updates_provider on public.parent_updates (provider_id);
create index if not exists idx_parent_updates_child    on public.parent_updates (child_id);
create index if not exists idx_parent_updates_note     on public.parent_updates (session_note_id);
create index if not exists idx_parent_updates_status   on public.parent_updates (status);

-- ── 3. RLS — strict youth-data isolation ───────────────────────────────────
-- (the rls_auto_enable event trigger also enables RLS on new public tables;
--  enabling explicitly here is belt-and-suspenders and self-documenting.)
alter table public.session_notes  enable row level security;
alter table public.parent_updates enable row level security;

-- session_notes: ONLY the owning coach (provider owner) — no parent/public access.
drop policy if exists session_notes_select_coach on public.session_notes;
create policy session_notes_select_coach on public.session_notes
  for select to authenticated using (
    exists (select 1 from public.providers pv
            where pv.id = session_notes.provider_id and pv.owner_id = auth.uid()));
drop policy if exists session_notes_insert_coach on public.session_notes;
create policy session_notes_insert_coach on public.session_notes
  for insert to authenticated with check (
    exists (select 1 from public.providers pv
            where pv.id = session_notes.provider_id and pv.owner_id = auth.uid()));
drop policy if exists session_notes_update_coach on public.session_notes;
create policy session_notes_update_coach on public.session_notes
  for update to authenticated using (
    exists (select 1 from public.providers pv
            where pv.id = session_notes.provider_id and pv.owner_id = auth.uid()))
  with check (
    exists (select 1 from public.providers pv
            where pv.id = session_notes.provider_id and pv.owner_id = auth.uid()));
drop policy if exists session_notes_delete_coach on public.session_notes;
create policy session_notes_delete_coach on public.session_notes
  for delete to authenticated using (
    exists (select 1 from public.providers pv
            where pv.id = session_notes.provider_id and pv.owner_id = auth.uid()));

-- parent_updates: owning coach has full CRUD …
drop policy if exists parent_updates_select_coach on public.parent_updates;
create policy parent_updates_select_coach on public.parent_updates
  for select to authenticated using (
    exists (select 1 from public.providers pv
            where pv.id = parent_updates.provider_id and pv.owner_id = auth.uid()));
drop policy if exists parent_updates_insert_coach on public.parent_updates;
create policy parent_updates_insert_coach on public.parent_updates
  for insert to authenticated with check (
    exists (select 1 from public.providers pv
            where pv.id = parent_updates.provider_id and pv.owner_id = auth.uid()));
drop policy if exists parent_updates_update_coach on public.parent_updates;
create policy parent_updates_update_coach on public.parent_updates
  for update to authenticated using (
    exists (select 1 from public.providers pv
            where pv.id = parent_updates.provider_id and pv.owner_id = auth.uid()))
  with check (
    exists (select 1 from public.providers pv
            where pv.id = parent_updates.provider_id and pv.owner_id = auth.uid()));
drop policy if exists parent_updates_delete_coach on public.parent_updates;
create policy parent_updates_delete_coach on public.parent_updates
  for delete to authenticated using (
    exists (select 1 from public.providers pv
            where pv.id = parent_updates.provider_id and pv.owner_id = auth.uid()));

-- … and a VERIFIED GUARDIAN may read ONLY their own child's rows, ONLY when
-- status = 'sent'. Drafts and approved-but-unsent rows are never parent-visible,
-- and the parent_id link prevents any cross-child leakage. (No insert/update/
-- delete for parents — read-only.)
drop policy if exists parent_updates_select_guardian on public.parent_updates;
create policy parent_updates_select_guardian on public.parent_updates
  for select to authenticated using (
    status = 'sent'
    and exists (select 1 from public.athletes a
                where a.id = parent_updates.child_id and a.parent_id = auth.uid()));
