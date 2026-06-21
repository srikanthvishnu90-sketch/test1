-- ============================================================================
-- Sporve — initial schema + Row-Level Security
-- ============================================================================
-- Columns match the app's real shapes (lib/core/mock/mock_data.dart + the #16
-- repository interfaces). This migration ONLY defines schema/RLS/grants — the
-- app is not wired to Supabase yet (that is #19).
--
-- SECURITY MODEL
--   • RLS is enabled on EVERY table → default-deny. A row is reachable only if a
--     policy explicitly allows it for the caller's role (anon / authenticated).
--   • GRANTs govern *API exposure* (what PostgREST will even attempt); RLS
--     governs *which rows*. BOTH are required — projects created after
--     2026-05-30 return nothing without explicit grants.
--   • `service_role` BYPASSES RLS. It is used ONLY server-side (Edge Functions,
--     #20/#21) and must NEVER be shipped in the client. The client uses the
--     anon/publishable key, under which these policies are the only access.
--   • `athletes` are MINORS — the table is parent-only; providers see a MINIMAL
--     display (first name + age band) denormalized onto `bookings`, never DOB,
--     contact, or the athletes table itself.
-- ============================================================================

create extension if not exists pgcrypto; -- gen_random_uuid()

-- ============================================================================
-- TABLES
-- ============================================================================

-- profiles: one row per auth user (id = auth.uid()).
create table public.profiles (
  id               uuid primary key references auth.users (id) on delete cascade,
  role             text not null check (role in ('searcher','provider')),
  first_name       text not null,
  last_name        text,
  email            text,
  phone_number     text,
  preferred_sports text[] not null default '{}',
  profile_image    text,
  created_at       timestamptz not null default now()
);

-- providers: business identity owned by a provider profile. PUBLIC-safe fields
-- only (no PII) — this is the table authenticated/anon users read for discovery,
-- so we never expose `profiles` for that purpose.
create table public.providers (
  id                  uuid primary key default gen_random_uuid(),
  owner_id            uuid not null references public.profiles (id) on delete cascade,
  business_name       text not null,
  bio                 text,
  sports              text[] not null default '{}',
  location            text,
  latitude            double precision,
  longitude           double precision,
  status              text not null default 'pending'
                        check (status in ('pending','approved','rejected','suspended')),
  onboarding_completed boolean not null default false,
  verification_status text not null default 'unverified'
                        check (verification_status in ('unverified','pending','verified')),
  stripe_account_id   text,
  created_at          timestamptz not null default now(),
  unique (owner_id)
);

-- programs: a provider's offering. Publicly discoverable when status='published'.
create table public.programs (
  id                  uuid primary key default gen_random_uuid(),
  provider_id         uuid not null references public.providers (id) on delete cascade,
  title               text not null,
  description         text,
  sport_type          text not null,
  skill_level         text,
  age_group           text,
  language            text not null default 'English',
  cover_image         text,
  gallery             text[] not null default '{}',
  whats_included      text[] not null default '{}',
  price               numeric(10,2) not null default 0 check (price >= 0),
  currency            text not null default 'USD',
  pricing_model       text not null default 'single_session'
                        check (pricing_model in ('single_session','monthly','seasonal','package')),
  max_capacity        integer not null default 0 check (max_capacity >= 0),
  enrolled_count      integer not null default 0 check (enrolled_count >= 0),
  latitude            double precision,
  longitude           double precision,
  address_line1       text,
  city                text,
  state               text,
  zip                 text,
  country             text,
  cancellation_policy text not null default 'flexible'
                        check (cancellation_policy in ('flexible','moderate','strict')),
  minimum_age         integer check (minimum_age >= 0),
  maximum_age         integer check (maximum_age >= 0),
  is_featured         boolean not null default false,
  status              text not null default 'draft'
                        check (status in ('draft','published','archived')),
  average_rating      numeric(2,1) not null default 0
                        check (average_rating >= 0 and average_rating <= 5),
  total_reviews       integer not null default 0 check (total_reviews >= 0),
  created_at          timestamptz not null default now()
);

-- sessions: scheduled occurrences of a program.
create table public.sessions (
  id          uuid primary key default gen_random_uuid(),
  program_id  uuid not null references public.programs (id) on delete cascade,
  title       text,
  start_date  date not null,
  end_date    date,
  start_time  text,  -- display form from the app, e.g. "05:00 PM"
  end_time    text,
  timezone    text,
  address     text,
  capacity    integer check (capacity >= 0),
  created_at  timestamptz not null default now()
);

-- athletes: MINORS. Parent-only — no provider/public read of this table, EVER.
create table public.athletes (
  id                 uuid primary key default gen_random_uuid(),
  parent_id          uuid not null references public.profiles (id) on delete cascade,
  first_name         text not null,
  last_name          text,
  date_of_birth      date,
  gender             text check (gender in ('male','female','other','prefer_not_to_say')),
  preferred_sports   text[] not null default '{}',
  medical_conditions text,
  emergency_contact  jsonb,
  profile_image      text,
  created_at         timestamptz not null default now()
);

-- bookings: a searcher books a session for an athlete.
create table public.bookings (
  id                 uuid primary key default gen_random_uuid(),
  searcher_id        uuid not null references public.profiles (id) on delete cascade,
  session_id         uuid not null references public.sessions (id) on delete cascade,
  athlete_id         uuid references public.athletes (id) on delete set null,
  program_id         uuid references public.programs (id) on delete set null,
  -- MINIMAL athlete display for the provider — denormalized so the provider can
  -- read the booking WITHOUT any access to the athletes table. Never DOB/contact.
  athlete_first_name text,
  athlete_age_band   text,
  selected_tier      text,
  original_price     numeric(10,2) not null default 0 check (original_price >= 0),
  final_price        numeric(10,2) not null default 0 check (final_price >= 0),
  currency           text not null default 'USD',
  status             text not null default 'pending'
                       check (status in ('pending','confirmed','declined','completed')),
  payment_status     text not null default 'unpaid'
                       check (payment_status in ('unpaid','paid','refunded','failed')),
  created_at         timestamptz not null default now()
);

-- conversations: 1:1 thread between a searcher profile and a provider profile.
create table public.conversations (
  id              uuid primary key default gen_random_uuid(),
  searcher_id     uuid not null references public.profiles (id) on delete cascade,
  provider_id     uuid not null references public.profiles (id) on delete cascade,
  program_id      uuid references public.programs (id) on delete set null,
  last_message    text,
  last_message_at timestamptz,
  created_at      timestamptz not null default now(),
  check (searcher_id <> provider_id)
);

-- messages: belong to a conversation; sender must be a participant.
create table public.messages (
  id              uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations (id) on delete cascade,
  sender_id       uuid not null references public.profiles (id) on delete cascade,
  body            text not null,
  created_at      timestamptz not null default now()
);

-- notifications: addressed to a single recipient profile.
create table public.notifications (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references public.profiles (id) on delete cascade,
  title      text,
  message    text,
  read       boolean not null default false,
  created_at timestamptz not null default now()
);

-- teams: a provider's roster group.
create table public.teams (
  id          uuid primary key default gen_random_uuid(),
  provider_id uuid not null references public.providers (id) on delete cascade,
  name        text not null,
  sport       text,
  created_at  timestamptz not null default now()
);

-- team_athletes: athletes belonging to a team (+ roster metadata).
create table public.team_athletes (
  id            uuid primary key default gen_random_uuid(),
  team_id       uuid not null references public.teams (id) on delete cascade,
  athlete_id    uuid not null references public.athletes (id) on delete cascade,
  jersey_number text,
  is_available  boolean not null default true,
  is_paid       boolean not null default false,
  created_at    timestamptz not null default now(),
  unique (team_id, athlete_id)
);

-- Helpful FK indexes (PostgREST joins + policy subqueries).
create index idx_providers_owner       on public.providers (owner_id);
create index idx_programs_provider     on public.programs (provider_id);
create index idx_sessions_program      on public.sessions (program_id);
create index idx_athletes_parent       on public.athletes (parent_id);
create index idx_bookings_searcher     on public.bookings (searcher_id);
create index idx_bookings_session      on public.bookings (session_id);
create index idx_conversations_searcher on public.conversations (searcher_id);
create index idx_conversations_provider on public.conversations (provider_id);
create index idx_messages_conversation on public.messages (conversation_id);
create index idx_notifications_user    on public.notifications (user_id);
create index idx_teams_provider        on public.teams (provider_id);
create index idx_team_athletes_team    on public.team_athletes (team_id);
create index idx_team_athletes_athlete on public.team_athletes (athlete_id);

-- ============================================================================
-- ENABLE ROW LEVEL SECURITY (default-deny everywhere)
-- ============================================================================
alter table public.profiles      enable row level security;
alter table public.providers     enable row level security;
alter table public.programs      enable row level security;
alter table public.sessions      enable row level security;
alter table public.athletes      enable row level security;
alter table public.bookings      enable row level security;
alter table public.conversations enable row level security;
alter table public.messages      enable row level security;
alter table public.notifications enable row level security;
alter table public.teams         enable row level security;
alter table public.team_athletes enable row level security;

-- ============================================================================
-- POLICIES
-- ============================================================================

-- ── profiles: own row only (never expose others' PII) ──────────────────────
create policy profiles_select_own on public.profiles
  for select to authenticated using (id = auth.uid());
create policy profiles_insert_own on public.profiles
  for insert to authenticated with check (id = auth.uid());
create policy profiles_update_own on public.profiles
  for update to authenticated using (id = auth.uid()) with check (id = auth.uid());
-- (no delete policy — profile rows die with the auth user via cascade)

-- ── providers: public discovery (approved) + owner full CRUD ───────────────
create policy providers_select_public on public.providers
  for select to anon, authenticated using (status = 'approved');
create policy providers_select_owner on public.providers
  for select to authenticated using (owner_id = auth.uid());
create policy providers_insert_owner on public.providers
  for insert to authenticated with check (owner_id = auth.uid());
create policy providers_update_owner on public.providers
  for update to authenticated using (owner_id = auth.uid()) with check (owner_id = auth.uid());
create policy providers_delete_owner on public.providers
  for delete to authenticated using (owner_id = auth.uid());

-- ── programs: public discovery (published) + owning provider full CRUD ──────
create policy programs_select_public on public.programs
  for select to anon, authenticated using (status = 'published');
create policy programs_select_owner on public.programs
  for select to authenticated using (
    exists (select 1 from public.providers pv
            where pv.id = programs.provider_id and pv.owner_id = auth.uid()));
create policy programs_insert_owner on public.programs
  for insert to authenticated with check (
    exists (select 1 from public.providers pv
            where pv.id = programs.provider_id and pv.owner_id = auth.uid()));
create policy programs_update_owner on public.programs
  for update to authenticated using (
    exists (select 1 from public.providers pv
            where pv.id = programs.provider_id and pv.owner_id = auth.uid()))
  with check (
    exists (select 1 from public.providers pv
            where pv.id = programs.provider_id and pv.owner_id = auth.uid()));
create policy programs_delete_owner on public.programs
  for delete to authenticated using (
    exists (select 1 from public.providers pv
            where pv.id = programs.provider_id and pv.owner_id = auth.uid()));

-- ── sessions: public when parent program published + owner full CRUD ───────
create policy sessions_select_public on public.sessions
  for select to anon, authenticated using (
    exists (select 1 from public.programs pr
            where pr.id = sessions.program_id and pr.status = 'published'));
create policy sessions_select_owner on public.sessions
  for select to authenticated using (
    exists (select 1 from public.programs pr
            join public.providers pv on pv.id = pr.provider_id
            where pr.id = sessions.program_id and pv.owner_id = auth.uid()));
create policy sessions_insert_owner on public.sessions
  for insert to authenticated with check (
    exists (select 1 from public.programs pr
            join public.providers pv on pv.id = pr.provider_id
            where pr.id = sessions.program_id and pv.owner_id = auth.uid()));
create policy sessions_update_owner on public.sessions
  for update to authenticated using (
    exists (select 1 from public.programs pr
            join public.providers pv on pv.id = pr.provider_id
            where pr.id = sessions.program_id and pv.owner_id = auth.uid()))
  with check (
    exists (select 1 from public.programs pr
            join public.providers pv on pv.id = pr.provider_id
            where pr.id = sessions.program_id and pv.owner_id = auth.uid()));
create policy sessions_delete_owner on public.sessions
  for delete to authenticated using (
    exists (select 1 from public.programs pr
            join public.providers pv on pv.id = pr.provider_id
            where pr.id = sessions.program_id and pv.owner_id = auth.uid()));

-- ── athletes (MINORS): owning parent ONLY, all operations. No one else. ─────
create policy athletes_select_parent on public.athletes
  for select to authenticated using (parent_id = auth.uid());
create policy athletes_insert_parent on public.athletes
  for insert to authenticated with check (parent_id = auth.uid());
create policy athletes_update_parent on public.athletes
  for update to authenticated using (parent_id = auth.uid()) with check (parent_id = auth.uid());
create policy athletes_delete_parent on public.athletes
  for delete to authenticated using (parent_id = auth.uid());

-- ── bookings: searcher CRUD own; provider (of the session) read + status ───
create policy bookings_select_searcher on public.bookings
  for select to authenticated using (searcher_id = auth.uid());
create policy bookings_select_provider on public.bookings
  for select to authenticated using (
    exists (select 1 from public.sessions s
            join public.programs pr on pr.id = s.program_id
            join public.providers pv on pv.id = pr.provider_id
            where s.id = bookings.session_id and pv.owner_id = auth.uid()));
create policy bookings_insert_searcher on public.bookings
  for insert to authenticated with check (searcher_id = auth.uid());
create policy bookings_update_searcher on public.bookings
  for update to authenticated using (searcher_id = auth.uid()) with check (searcher_id = auth.uid());
create policy bookings_update_provider on public.bookings
  for update to authenticated using (
    exists (select 1 from public.sessions s
            join public.programs pr on pr.id = s.program_id
            join public.providers pv on pv.id = pr.provider_id
            where s.id = bookings.session_id and pv.owner_id = auth.uid()))
  with check (
    exists (select 1 from public.sessions s
            join public.programs pr on pr.id = s.program_id
            join public.providers pv on pv.id = pr.provider_id
            where s.id = bookings.session_id and pv.owner_id = auth.uid()));
create policy bookings_delete_searcher on public.bookings
  for delete to authenticated using (searcher_id = auth.uid());

-- RLS can't restrict WHICH columns a provider updates, so a trigger pins the
-- provider's UPDATE to `status` only (price/searcher/athlete fields are locked).
-- The searcher (owner) is unaffected.
create or replace function public.enforce_booking_provider_update()
  returns trigger language plpgsql as $$
begin
  if auth.uid() = old.searcher_id then
    return new; -- owner: RLS already scoped this to their own row
  end if;
  -- otherwise the actor is the session's provider → status changes only
  if new.searcher_id        is distinct from old.searcher_id
   or new.session_id        is distinct from old.session_id
   or new.athlete_id        is distinct from old.athlete_id
   or new.program_id        is distinct from old.program_id
   or new.athlete_first_name is distinct from old.athlete_first_name
   or new.athlete_age_band  is distinct from old.athlete_age_band
   or new.selected_tier     is distinct from old.selected_tier
   or new.original_price    is distinct from old.original_price
   or new.final_price       is distinct from old.final_price
   or new.currency          is distinct from old.currency
   or new.payment_status    is distinct from old.payment_status then
    raise exception 'Provider may only update booking status';
  end if;
  return new;
end;
$$;
create trigger trg_enforce_booking_provider_update
  before update on public.bookings
  for each row execute function public.enforce_booking_provider_update();

-- ── conversations: the two participants only ───────────────────────────────
create policy conversations_select_participant on public.conversations
  for select to authenticated using (auth.uid() in (searcher_id, provider_id));
create policy conversations_insert_participant on public.conversations
  for insert to authenticated with check (auth.uid() in (searcher_id, provider_id));
create policy conversations_update_participant on public.conversations
  for update to authenticated using (auth.uid() in (searcher_id, provider_id))
  with check (auth.uid() in (searcher_id, provider_id));

-- ── messages: participants read; sender_id = auth.uid() on insert ──────────
create policy messages_select_participant on public.messages
  for select to authenticated using (
    exists (select 1 from public.conversations c
            where c.id = messages.conversation_id
              and auth.uid() in (c.searcher_id, c.provider_id)));
create policy messages_insert_sender on public.messages
  for insert to authenticated with check (
    sender_id = auth.uid()
    and exists (select 1 from public.conversations c
                where c.id = messages.conversation_id
                  and auth.uid() in (c.searcher_id, c.provider_id)));
-- (messages are immutable: no update/delete policy → default-deny)

-- ── notifications: recipient reads + marks read; dismiss own ───────────────
-- (creation is server-side via service_role — no client INSERT policy.)
create policy notifications_select_own on public.notifications
  for select to authenticated using (user_id = auth.uid());
create policy notifications_update_own on public.notifications
  for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy notifications_delete_own on public.notifications
  for delete to authenticated using (user_id = auth.uid());

-- ── teams: owning provider CRUD; parent reads teams their athlete is in ────
create policy teams_select_owner on public.teams
  for select to authenticated using (
    exists (select 1 from public.providers pv
            where pv.id = teams.provider_id and pv.owner_id = auth.uid()));
create policy teams_select_parent on public.teams
  for select to authenticated using (
    exists (select 1 from public.team_athletes ta
            join public.athletes a on a.id = ta.athlete_id
            where ta.team_id = teams.id and a.parent_id = auth.uid()));
create policy teams_insert_owner on public.teams
  for insert to authenticated with check (
    exists (select 1 from public.providers pv
            where pv.id = teams.provider_id and pv.owner_id = auth.uid()));
create policy teams_update_owner on public.teams
  for update to authenticated using (
    exists (select 1 from public.providers pv
            where pv.id = teams.provider_id and pv.owner_id = auth.uid()))
  with check (
    exists (select 1 from public.providers pv
            where pv.id = teams.provider_id and pv.owner_id = auth.uid()));
create policy teams_delete_owner on public.teams
  for delete to authenticated using (
    exists (select 1 from public.providers pv
            where pv.id = teams.provider_id and pv.owner_id = auth.uid()));

-- ── team_athletes: owning provider CRUD; parent reads rows for own athlete ─
create policy team_athletes_select_owner on public.team_athletes
  for select to authenticated using (
    exists (select 1 from public.teams t
            join public.providers pv on pv.id = t.provider_id
            where t.id = team_athletes.team_id and pv.owner_id = auth.uid()));
create policy team_athletes_select_parent on public.team_athletes
  for select to authenticated using (
    exists (select 1 from public.athletes a
            where a.id = team_athletes.athlete_id and a.parent_id = auth.uid()));
create policy team_athletes_insert_owner on public.team_athletes
  for insert to authenticated with check (
    exists (select 1 from public.teams t
            join public.providers pv on pv.id = t.provider_id
            where t.id = team_athletes.team_id and pv.owner_id = auth.uid()));
create policy team_athletes_update_owner on public.team_athletes
  for update to authenticated using (
    exists (select 1 from public.teams t
            join public.providers pv on pv.id = t.provider_id
            where t.id = team_athletes.team_id and pv.owner_id = auth.uid()))
  with check (
    exists (select 1 from public.teams t
            join public.providers pv on pv.id = t.provider_id
            where t.id = team_athletes.team_id and pv.owner_id = auth.uid()));
create policy team_athletes_delete_owner on public.team_athletes
  for delete to authenticated using (
    exists (select 1 from public.teams t
            join public.providers pv on pv.id = t.provider_id
            where t.id = team_athletes.team_id and pv.owner_id = auth.uid()));

-- ============================================================================
-- GRANTS — API exposure. RLS still governs which rows are returned.
-- ============================================================================
grant usage on schema public to anon, authenticated;

-- authenticated: full DML on every table (RLS scopes the rows).
grant select, insert, update, delete on all tables in schema public to authenticated;

-- anon: SELECT ONLY on genuinely public discovery data (logged-out browsing).
-- Everything else is unreachable to anon (no grant + no anon policy).
grant select on public.providers to anon;
grant select on public.programs  to anon;
grant select on public.sessions  to anon;

-- Make these defaults apply to any future tables created by the migration role.
alter default privileges in schema public
  grant select, insert, update, delete on tables to authenticated;
