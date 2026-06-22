-- ============================================================================
-- DRAFT — DO NOT APPLY without approval (see FLAG list in the agent report).
-- ============================================================================
-- Adds a denormalized athlete display name to team_athletes so a provider can
-- show roster names WITHOUT reading the athletes table (which is parent-only by
-- RLS — athletes are minors). This mirrors bookings.athlete_first_name.
--
-- After applying, the roster-create flow must populate athlete_first_name when
-- adding an athlete to a team (parent-side, where the name is readable), and
-- SupabaseRepository.getTeams already reads team_athletes.athlete_first_name.
--
-- Why flagged: it is a remote schema change. Review before running.
-- ============================================================================
alter table public.team_athletes
  add column if not exists athlete_first_name text;
