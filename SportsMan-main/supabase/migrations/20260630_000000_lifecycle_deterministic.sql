-- ============================================================================
-- Sporve — Lifecycle messaging: the DETERMINISTIC layer            2026-06-30
-- ============================================================================
-- This migration builds ONLY the deterministic layer (P4): it decides WHETHER
-- and WHEN a lifecycle message should happen, and enqueues a 'pending' row. It
-- generates NO content (no AI here) — drafting/sending are separate later layers.
--
-- Adapted to the REAL schema (per ai-stage2-audit.md):
--   • providers(id, owner_id), programs(id, provider_id), sessions(id, program_id,
--     start_date date, start_time text "05:00 PM", timezone text),
--     bookings(id, program_id, session_id, athlete_id, status), athletes(id, parent_id).
--   • Booking transitions happen as an UPDATE of bookings.status (there is no app
--     write path yet — audit §1), so the real hook is an AFTER UPDATE trigger.
--   • bookings.status had no 'no_show' value (audit §1). We ADDITIVELY widen the
--     CHECK to add 'no_show' so the no_show_followup transition is representable.
--   • pg_cron was not enabled (audit §3). We enable it defensively below; if it is
--     unavailable the time-driven FUNCTIONS still exist and can be run by any
--     scheduler.
--
-- Idempotent. Safe to re-run.
-- ============================================================================

-- ── 0. Widen bookings.status to allow 'no_show' (additive — nothing removed) ──
alter table public.bookings drop constraint if exists bookings_status_check;
alter table public.bookings add constraint bookings_status_check
  check (status in ('pending','confirmed','declined','completed','no_show'));

-- ── 1. lifecycle_message_prefs — per-coach, per-event delivery mode ──────────
create table if not exists public.lifecycle_message_prefs (
  id          uuid primary key default gen_random_uuid(),
  provider_id uuid not null references public.providers (id) on delete cascade,
  event_type  text not null
                check (event_type in ('booking_confirmed','reminder_24h',
                                      'post_session','no_show_followup','rebook_nudge')),
  -- Default for EVERY type is 'draft' (coach reviews before anything goes out).
  mode        text not null default 'draft' check (mode in ('off','draft','auto')),
  updated_at  timestamptz not null default now(),
  unique (provider_id, event_type),
  -- ENFORCE (DB layer): 'auto' (send without review) is ONLY valid for logistics
  -- types. Any other event_type may be 'off' or 'draft' but never 'auto'.
  constraint lifecycle_prefs_auto_only_logistics check (
    mode <> 'auto' or event_type in ('booking_confirmed','reminder_24h')
  )
);
create index if not exists idx_lmp_provider on public.lifecycle_message_prefs (provider_id);

-- keep updated_at fresh on edits
create or replace function public.touch_lifecycle_prefs()
  returns trigger language plpgsql set search_path = '' as $$
begin
  new.updated_at := now();
  return new;
end $$;
drop trigger if exists trg_touch_lifecycle_prefs on public.lifecycle_message_prefs;
create trigger trg_touch_lifecycle_prefs
  before update on public.lifecycle_message_prefs
  for each row execute function public.touch_lifecycle_prefs();

-- RLS: a coach manages ONLY their own prefs (provider they own). No parent/public.
alter table public.lifecycle_message_prefs enable row level security;
drop policy if exists lmp_select_owner on public.lifecycle_message_prefs;
create policy lmp_select_owner on public.lifecycle_message_prefs for select to authenticated
  using (exists (select 1 from public.providers pv
                 where pv.id = lifecycle_message_prefs.provider_id and pv.owner_id = auth.uid()));
drop policy if exists lmp_insert_owner on public.lifecycle_message_prefs;
create policy lmp_insert_owner on public.lifecycle_message_prefs for insert to authenticated
  with check (exists (select 1 from public.providers pv
                      where pv.id = lifecycle_message_prefs.provider_id and pv.owner_id = auth.uid()));
drop policy if exists lmp_update_owner on public.lifecycle_message_prefs;
create policy lmp_update_owner on public.lifecycle_message_prefs for update to authenticated
  using (exists (select 1 from public.providers pv
                 where pv.id = lifecycle_message_prefs.provider_id and pv.owner_id = auth.uid()))
  with check (exists (select 1 from public.providers pv
                      where pv.id = lifecycle_message_prefs.provider_id and pv.owner_id = auth.uid()));
drop policy if exists lmp_delete_owner on public.lifecycle_message_prefs;
create policy lmp_delete_owner on public.lifecycle_message_prefs for delete to authenticated
  using (exists (select 1 from public.providers pv
                 where pv.id = lifecycle_message_prefs.provider_id and pv.owner_id = auth.uid()));

-- ── 2. outbound_messages — the staging QUEUE (server-managed) ────────────────
create table if not exists public.outbound_messages (
  id            uuid primary key default gen_random_uuid(),
  provider_id   uuid not null references public.providers (id) on delete cascade,
  child_id      uuid references public.athletes (id) on delete set null,
  booking_id    uuid references public.bookings (id) on delete set null,
  event_type    text not null
                  check (event_type in ('booking_confirmed','reminder_24h',
                                        'post_session','no_show_followup','rebook_nudge')),
  status        text not null default 'pending'
                  check (status in ('pending','drafted','approved','sent','skipped')),
  scheduled_for timestamptz,
  content       jsonb,                                   -- null until a later draft layer fills it
  approved_by   uuid references public.profiles (id) on delete set null,
  approved_at   timestamptz,
  sent_at       timestamptz,
  created_at    timestamptz not null default now()
);
create index if not exists idx_outbound_provider  on public.outbound_messages (provider_id);
create index if not exists idx_outbound_status     on public.outbound_messages (status);
create index if not exists idx_outbound_scheduled  on public.outbound_messages (scheduled_for);
create index if not exists idx_outbound_booking    on public.outbound_messages (booking_id);
create index if not exists idx_outbound_child      on public.outbound_messages (child_id);

-- RLS: coaches SELECT only their own rows. Parents NEVER see this table (it is
-- the staging queue, not the delivered message). Writes are SERVICE-ROLE only
-- (the SECURITY DEFINER enqueue functions below) — no client DML.
alter table public.outbound_messages enable row level security;
-- The schema's default privileges grant DML to `authenticated`; revoke it here so
-- clients can never write the queue, then grant read-only back. (Does not touch
-- any other table's grants.)
revoke all on public.outbound_messages from anon, authenticated;
grant select on public.outbound_messages to authenticated;
drop policy if exists om_select_owner on public.outbound_messages;
create policy om_select_owner on public.outbound_messages for select to authenticated
  using (exists (select 1 from public.providers pv
                 where pv.id = outbound_messages.provider_id and pv.owner_id = auth.uid()));
-- (No insert/update/delete policies → default-deny for clients.)

-- ── 3. enqueue helper — the single WHETHER/WHEN gate (no content) ────────────
-- Respects the coach's pref ('off' => skip) and is idempotent per booking+event.
-- SECURITY DEFINER so triggers/cron can write the queue under RLS.
create or replace function public.enqueue_outbound_message(
  p_provider_id  uuid,
  p_child_id     uuid,
  p_booking_id   uuid,
  p_event_type   text,
  p_scheduled_for timestamptz
) returns uuid
  language plpgsql
  security definer
  set search_path = ''
as $$
declare v_id uuid;
begin
  if p_provider_id is null or p_event_type is null then
    return null;
  end if;

  -- WHETHER: the coach turned this lifecycle message off (default 'draft' => on).
  if exists (select 1 from public.lifecycle_message_prefs p
             where p.provider_id = p_provider_id
               and p.event_type = p_event_type
               and p.mode = 'off') then
    return null;
  end if;

  -- Idempotency: never double-enqueue an active row for the same booking+event.
  -- ('skipped' is intentionally excluded — a skipped message may be re-enqueued.)
  if p_booking_id is not null then
    if exists (select 1 from public.outbound_messages o
               where o.booking_id = p_booking_id
                 and o.event_type = p_event_type
                 and o.status in ('pending','drafted','approved','sent')) then
      return null;
    end if;
  end if;

  insert into public.outbound_messages
    (provider_id, child_id, booking_id, event_type, status, scheduled_for)
  values
    (p_provider_id, p_child_id, p_booking_id, p_event_type, 'pending', p_scheduled_for)
  returning id into v_id;
  return v_id;
end $$;

-- ── 3a. Event-driven trigger: bookings.status transition -> enqueue ──────────
create or replace function public.enqueue_lifecycle_on_booking()
  returns trigger
  language plpgsql
  security definer
  set search_path = ''
as $$
declare v_provider uuid;
begin
  if new.status is distinct from old.status then
    -- Resolve the owning provider from program (or session -> program).
    select pr.provider_id into v_provider
      from public.programs pr where pr.id = new.program_id;
    if v_provider is null and new.session_id is not null then
      select pr.provider_id into v_provider
        from public.sessions s join public.programs pr on pr.id = s.program_id
        where s.id = new.session_id;
    end if;

    if v_provider is not null then
      if new.status = 'confirmed' then
        perform public.enqueue_outbound_message(v_provider, new.athlete_id, new.id, 'booking_confirmed', now());
      elsif new.status = 'completed' then
        perform public.enqueue_outbound_message(v_provider, new.athlete_id, new.id, 'post_session', now());
      elsif new.status = 'no_show' then
        perform public.enqueue_outbound_message(v_provider, new.athlete_id, new.id, 'no_show_followup', now());
      end if;
    end if;
  end if;
  return new;
end $$;

drop trigger if exists trg_enqueue_lifecycle_on_booking on public.bookings;
create trigger trg_enqueue_lifecycle_on_booking
  after update of status on public.bookings
  for each row execute function public.enqueue_lifecycle_on_booking();

-- ── 3b. Time-driven: reminder_24h ~24h before each upcoming session ──────────
-- Hourly job enqueues a reminder when the "24h before start" mark falls in the
-- next hour. scheduled_for = session_start - 24h (the intended send time).
create or replace function public.enqueue_reminders_24h()
  returns integer
  language plpgsql
  security definer
  set search_path = ''
as $$
declare v_count int := 0; r record; v_start timestamptz; v_id uuid;
begin
  for r in
    select b.id as booking_id, b.athlete_id, pr.provider_id,
           s.start_date, s.start_time, s.timezone
    from public.bookings b
    join public.sessions s on s.id = b.session_id
    join public.programs pr on pr.id = s.program_id
    where b.status = 'confirmed' and b.session_id is not null
  loop
    -- Best-effort instant from (date + display time) in the session's timezone.
    begin
      v_start := (r.start_date::text || ' ' || coalesce(nullif(r.start_time,''),'12:00 PM'))::timestamp
                 at time zone coalesce(nullif(r.timezone,''),'UTC');
    exception when others then
      raise log 'enqueue_reminders_24h: unparseable start for booking % (date=%, time=%, tz=%); using date@UTC',
        r.booking_id, r.start_date, r.start_time, r.timezone;
      v_start := r.start_date::timestamp at time zone 'UTC';
    end;

    if v_start is not null
       and (v_start - interval '24 hours') >= now()
       and (v_start - interval '24 hours') <  now() + interval '1 hour' then
      v_id := public.enqueue_outbound_message(
                r.provider_id, r.athlete_id, r.booking_id, 'reminder_24h', v_start - interval '24 hours');
      if v_id is not null then v_count := v_count + 1; end if;
    end if;
  end loop;
  return v_count;
end $$;

-- ── 3c. Time-driven: rebook_nudge for lapsed guardians (default 21 days) ─────
-- For each (provider, child): if the last COMPLETED booking is older than the
-- lapse window AND nothing is upcoming with that coach, enqueue a rebook_nudge.
-- (No completed_at column exists — audit §1 — so created_at is the lapse proxy.)
create or replace function public.enqueue_rebook_nudges(p_lapse_days integer default 21)
  returns integer
  language plpgsql
  security definer
  set search_path = ''
as $$
declare v_count int := 0; r record; v_id uuid;
begin
  for r in
    select pr.provider_id, b.athlete_id as child_id, max(b.created_at) as last_completed
    from public.bookings b
    join public.programs pr on pr.id = b.program_id
    where b.status = 'completed' and b.athlete_id is not null
    group by pr.provider_id, b.athlete_id
    having max(b.created_at) < now() - make_interval(days => p_lapse_days)
  loop
    -- Skip if anything is upcoming with this coach for this child.
    if exists (
      select 1 from public.bookings b2
      join public.programs pr2 on pr2.id = b2.program_id
      left join public.sessions s2 on s2.id = b2.session_id
      where pr2.provider_id = r.provider_id
        and b2.athlete_id = r.child_id
        and b2.status in ('pending','confirmed')
        and (s2.start_date is null or s2.start_date >= current_date)
    ) then
      continue;
    end if;

    -- Dedup: skip if an active OR recent rebook_nudge already exists for the pair.
    if exists (
      select 1 from public.outbound_messages o
      where o.provider_id = r.provider_id
        and o.child_id = r.child_id
        and o.event_type = 'rebook_nudge'
        and (o.status in ('pending','drafted','approved')
             or o.created_at > now() - make_interval(days => p_lapse_days))
    ) then
      continue;
    end if;

    v_id := public.enqueue_outbound_message(r.provider_id, r.child_id, null, 'rebook_nudge', now());
    if v_id is not null then v_count := v_count + 1; end if;
  end loop;
  return v_count;
end $$;

-- Client roles can NEVER call these (server/cron only).
revoke execute on function public.enqueue_outbound_message(uuid,uuid,uuid,text,timestamptz) from public, anon, authenticated;
revoke execute on function public.enqueue_lifecycle_on_booking() from public, anon, authenticated;
revoke execute on function public.enqueue_reminders_24h() from public, anon, authenticated;
revoke execute on function public.enqueue_rebook_nudges(integer) from public, anon, authenticated;
revoke execute on function public.touch_lifecycle_prefs() from public, anon, authenticated;

-- ── 4. pg_cron schedules (defensive — skip cleanly if pg_cron is unavailable) ─
do $$
begin
  create extension if not exists pg_cron;

  -- hourly: 24h reminders
  if exists (select 1 from cron.job where jobname = 'lifecycle-reminders-24h') then
    perform cron.unschedule('lifecycle-reminders-24h');
  end if;
  perform cron.schedule('lifecycle-reminders-24h', '0 * * * *',
                        $cron$select public.enqueue_reminders_24h();$cron$);

  -- daily 08:00: rebook nudges (default 21-day lapse)
  if exists (select 1 from cron.job where jobname = 'lifecycle-rebook-nudges') then
    perform cron.unschedule('lifecycle-rebook-nudges');
  end if;
  perform cron.schedule('lifecycle-rebook-nudges', '0 8 * * *',
                        $cron$select public.enqueue_rebook_nudges();$cron$);

  raise notice 'lifecycle cron scheduled via pg_cron.';
exception when others then
  raise notice 'pg_cron unavailable (%); lifecycle cron NOT scheduled. Run enqueue_reminders_24h() / enqueue_rebook_nudges() from an external scheduler until pg_cron is enabled.', sqlerrm;
end $$;
