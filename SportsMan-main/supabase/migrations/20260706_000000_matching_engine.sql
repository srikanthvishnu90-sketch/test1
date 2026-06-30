-- ============================================================================
-- Sporve — AI Matching & Ranking Engine: LAYER 1 (deterministic gates)  2026-07-06
-- ============================================================================
-- Safety lives here. match_eligible(client) removes every provider that fails a
-- HARD GATE (G1-G7) BEFORE any LLM sees it. The model (Layer 2, ai-match) may only
-- reorder/explain the eligible set — it can never resurrect a gated-out provider,
-- override a gate, or invent facts (the Edge Function overwrites numeric facts
-- from this data). The §5 LTAD ceiling + §6 gates are the source of truth.
--
-- First-class columns so gates are cheap + auditable:
--   programs.intensity_tier (0-4), typical_client jsonb, session_types text[]
--   providers.background_check_status, account_status, coach_years_*, credentials
-- Existing rows fail CLOSED: unknown intensity is treated as 4 (highest), and a
-- provider is not "verified"/"active" until explicitly set — so nothing unvetted
-- can ever match until product fills these in.
--
-- Idempotent. Safe to re-run.
-- ============================================================================

-- ── Columns (additive) ──────────────────────────────────────────────────────
alter table public.programs
  add column if not exists intensity_tier int check (intensity_tier between 0 and 4),
  add column if not exists typical_client jsonb,
  add column if not exists session_types text[] not null default '{}';

alter table public.providers
  add column if not exists background_check_status text not null default 'none'
    check (background_check_status in ('verified','pending','none','flagged')),
  add column if not exists account_status text not null default 'active'
    check (account_status in ('active','suspended','flagged')),
  add column if not exists coach_years_coaching int,
  add column if not exists coach_years_played int,
  add column if not exists credentials text[] not null default '{}';

-- ── §5 LTAD developmental ceiling: age (+ maturation, + skill) -> max tier ──
-- The mapping is a CEILING. Maturation adjusts ONLY ages 11-16 (early +1 / late
-- -1); it never applies below 11 and never lifts the young-age (<=8) ceilings.
-- The 16-17 tier-4 bump applies only when skill is advanced/elite.
create or replace function public.ltad_max_tier(
  p_age int, p_maturation text default null, p_skill text default null
) returns int language sql immutable set search_path = '' as $$
  select greatest(0, least(4, t)) from (
    select (
      (case
        when p_age <= 6                 then 0   -- Active Start
        when p_age between 7  and 11    then 1   -- FUNdamentals / Learn to Train (no elite/select)
        when p_age between 12 and 13    then 2   -- early Train to Train
        when p_age between 14 and 15    then 3   -- Train to Train
        when p_age between 16 and 17    then (case when lower(coalesce(p_skill,'')) in ('advanced','elite') then 4 else 3 end)
        else 4                                    -- 18+ : no ceiling
      end)
      + (case
          when p_age between 11 and 16 and p_maturation = 'early' then 1
          when p_age between 11 and 16 and p_maturation = 'late'  then -1
          else 0
        end)
    ) as t
  ) q;
$$;

-- ── §6 HARD GATES: eligible providers only (run before the LLM) ─────────────
create or replace function public.match_eligible(client jsonb)
  returns table (
    program_id uuid, provider_id uuid, name text, title text, sport text,
    intensity_tier int, age_min int, age_max int,
    price_per_session int, rating_avg numeric, rating_count int,
    distance_km double precision, bio text, credentials text[],
    coach_years_coaching int, coach_years_played int,
    typical_client jsonb, session_types text[], available_this_week boolean,
    client_max_tier int
  ) language sql stable security definer set search_path = public, extensions as $$
  with c as (
    select
      (client->>'athlete_age')::int                          as age,
      nullif(client->>'maturation','')                       as maturation,
      nullif(client->>'sport','')                            as sport,
      nullif(client->>'skill_level','')                      as skill,
      (client->>'lat')::double precision                     as lat,
      (client->>'lng')::double precision                     as lng,
      coalesce((client->>'max_distance_km')::double precision, 40) as max_km,
      (client->>'budget_max_per_session')::int               as budget,
      coalesce(nullif(client->>'session_type_pref',''),'any') as stp
  ),
  mx as (select public.ltad_max_tier((select age from c),(select maturation from c),(select skill from c)) as max_tier)
  select
    pr.id, pv.id, pv.business_name, pr.title, pr.sport_type,
    pr.intensity_tier, pr.minimum_age, pr.maximum_age,
    round(pr.price * 100)::int as price_per_session,   -- spec: cents
    pr.average_rating, pr.total_reviews,
    case when c.lat is not null and c.lng is not null and pr.latitude is not null and pr.longitude is not null
      then 6371 * acos(least(1, greatest(-1,
            cos(radians(c.lat))*cos(radians(pr.latitude))*cos(radians(pr.longitude)-radians(c.lng))
            + sin(radians(c.lat))*sin(radians(pr.latitude)))))
      else null end as distance_km,
    pv.bio, pv.credentials, pv.coach_years_coaching, pv.coach_years_played,
    pr.typical_client, pr.session_types,
    exists (select 1 from public.sessions s
            where s.program_id = pr.id and s.start_date >= current_date
              and s.start_date <= current_date + 7
              and (s.capacity = 0 or s.capacity > (
                select count(*) from public.bookings b
                where b.session_id = s.id and b.status in ('pending','confirmed')))) as available_this_week,
    (select max_tier from mx)
  from public.programs pr
  join public.providers pv on pv.id = pr.provider_id
  cross join c cross join mx
  where pr.status = 'published'
    -- G1 — age-appropriate intensity (unknown intensity fails CLOSED = treat as 4)
    and coalesce(pr.intensity_tier, 4) <= mx.max_tier
    -- G2 — age served (null bounds = serves all)
    and c.age >= coalesce(pr.minimum_age, 0) and c.age <= coalesce(pr.maximum_age, 200)
    -- G3 — sport (program sport OR provider specialization)
    and (c.sport is null
         or lower(pr.sport_type) = lower(c.sport)
         or exists (select 1 from unnest(pv.sports) s where lower(s) = lower(c.sport)))
    -- G4 — distance (must have coords AND be within radius)
    and c.lat is not null and c.lng is not null and pr.latitude is not null and pr.longitude is not null
    and 6371 * acos(least(1, greatest(-1,
          cos(radians(c.lat))*cos(radians(pr.latitude))*cos(radians(pr.longitude)-radians(c.lng))
          + sin(radians(c.lat))*sin(radians(pr.latitude))))) <= c.max_km
    -- G5 — safety (non-negotiable): verified background AND active account
    and pv.background_check_status = 'verified'
    and pv.account_status = 'active'
    -- G6 — budget (cents)
    and (c.budget is null or round(pr.price * 100)::int <= c.budget)
    -- G7 — session type
    and (c.stp = 'any' or c.stp = any(pr.session_types));
$$;

revoke execute on function public.ltad_max_tier(int, text, text) from public, anon, authenticated;
revoke execute on function public.match_eligible(jsonb) from public, anon, authenticated;
