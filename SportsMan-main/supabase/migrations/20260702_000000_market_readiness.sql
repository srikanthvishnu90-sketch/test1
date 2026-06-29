-- ============================================================================
-- Sporve — Market readiness GATE (Stage 3, C1)                       2026-07-02
-- ============================================================================
-- Search must never run in a market (sport × metro) that hasn't earned it. This
-- migration builds ONLY the gate — no search, no AI. A market is "ready" when it
-- has enough active bookable listings AND enough review signal; the two floors
-- live in a config row so they tune WITHOUT a code deploy.
--
-- Adapted to the real schema (docs/ai-stage3-audit.md):
--   • Listings live on public.programs (status, sport_type, total_reviews, and
--     latitude/longitude/city/state for geo). There is NO metro column, so metro
--     is derived: a coarse ~0.5° lat/lng bucket when coordinates exist, else
--     city,state, else 'unknown'.
--   • Bookable availability = an upcoming public.sessions row with open capacity
--     (capacity 0 is treated as "unspecified/open"); bookings link via session_id.
--   • There is NO reviews table yet, so "review signal" uses the aggregate
--     programs.total_reviews. Swap to counting reviews rows when that table lands.
--
-- ACCESS: gate internals are SERVICE-ROLE / admin only (the search Edge Function
-- calls them with the service role). EXECUTE/SELECT are revoked from client roles;
-- there is no admin DB role yet (profiles.role ∈ searcher|provider), so "admin"
-- == service role until one exists. No existing policy is touched.
--
-- Idempotent. Safe to re-run.
-- ============================================================================

-- ── 1. Tunable floors (single config row, no-redeploy tuning) ───────────────
create table if not exists public.market_readiness_config (
  id                  boolean primary key default true check (id),  -- singleton
  min_active_listings integer not null default 15,
  min_review_signals  integer not null default 30,
  updated_at          timestamptz not null default now()
);
insert into public.market_readiness_config (id) values (true) on conflict (id) do nothing;

-- ── 2. Per-market admin override (staging testing; default: no rows) ─────────
create table if not exists public.market_overrides (
  sport       text not null,
  metro       text not null,
  force_ready boolean not null default false,  -- default OFF; only an explicit true forces ready
  note        text,
  created_at  timestamptz not null default now(),
  primary key (sport, metro)
);

-- Both config + overrides are service-role/admin only (RLS default-deny, grants revoked).
alter table public.market_readiness_config enable row level security;
alter table public.market_overrides        enable row level security;
revoke all on public.market_readiness_config from anon, authenticated;
revoke all on public.market_overrides        from anon, authenticated;

-- ── 3. metro derivation (coarse, deterministic) ─────────────────────────────
create or replace function public.metro_key(
  p_lat double precision, p_lng double precision, p_city text, p_state text
) returns text language sql immutable as $$
  select case
    when p_lat is not null and p_lng is not null
      then 'geo:' || round((floor(p_lat * 2) / 2)::numeric, 1)::text
                  || ',' || round((floor(p_lng * 2) / 2)::numeric, 1)::text
    when coalesce(nullif(trim(p_city), ''), '') <> ''
      then lower(trim(p_city)) || ',' || lower(coalesce(trim(p_state), ''))
    else 'unknown'
  end
$$;

-- ── 4. market_readiness(sport, metro) — counts per sport × metro ────────────
-- Returns one row per market (optionally filtered). active_bookable_listings =
-- published programs with an upcoming session that still has open capacity;
-- review_signals = sum of total_reviews across the market's published listings.
create or replace function public.market_readiness(
  p_sport text default null, p_metro text default null
) returns table (
  sport text, metro text, active_bookable_listings bigint, review_signals bigint
) language sql stable security definer set search_path = '' as $$
  with listings as (
    select
      pr.sport_type as sport,
      public.metro_key(pr.latitude, pr.longitude, pr.city, pr.state) as metro,
      pr.total_reviews as reviews,
      exists (
        select 1 from public.sessions s
        where s.program_id = pr.id
          and s.start_date >= current_date
          and (s.capacity = 0 or s.capacity > (
            select count(*) from public.bookings b
            where b.session_id = s.id and b.status in ('pending', 'confirmed')
          ))
      ) as bookable
    from public.programs pr
    where pr.status = 'published'
  )
  select
    l.sport,
    l.metro,
    count(*) filter (where l.bookable)::bigint as active_bookable_listings,
    coalesce(sum(l.reviews), 0)::bigint        as review_signals
  from listings l
  where (p_sport is null or l.sport = p_sport)
    and (p_metro is null or l.metro = p_metro)
  group by l.sport, l.metro
  order by l.sport, l.metro;
$$;

-- ── 5. is_market_ready(sport, metro) — the GATE the search fn calls ─────────
-- Order: explicit admin force_ready override > config floors. Never true by
-- default for a sparse market.
create or replace function public.is_market_ready(p_sport text, p_metro text)
  returns boolean language plpgsql stable security definer set search_path = '' as $$
declare
  v_min_listings int; v_min_reviews int;
  v_active bigint; v_reviews bigint; v_force boolean;
begin
  -- Admin/staging override wins when explicitly set true (default: no row => normal logic).
  select force_ready into v_force
    from public.market_overrides where sport = p_sport and metro = p_metro;
  if v_force is true then return true; end if;

  select min_active_listings, min_review_signals into v_min_listings, v_min_reviews
    from public.market_readiness_config where id = true;
  v_min_listings := coalesce(v_min_listings, 15);
  v_min_reviews  := coalesce(v_min_reviews, 30);

  select active_bookable_listings, review_signals into v_active, v_reviews
    from public.market_readiness(p_sport, p_metro) limit 1;

  return coalesce(v_active, 0) >= v_min_listings
     and coalesce(v_reviews, 0) >= v_min_reviews;
end $$;

-- ── 6. Admin overview — coverage at a glance (service-role/admin only) ───────
create or replace view public.market_readiness_overview as
  select
    m.sport, m.metro, m.active_bookable_listings, m.review_signals,
    c.min_active_listings, c.min_review_signals,
    public.is_market_ready(m.sport, m.metro) as ready,
    coalesce(o.force_ready, false) as force_ready
  from public.market_readiness() m
  cross join public.market_readiness_config c
  left join public.market_overrides o on o.sport = m.sport and o.metro = m.metro
  where c.id = true;

-- Gate internals are server-only. Clients can never read counts or call the gate
-- directly (the search Edge Function uses the service role, which bypasses these).
revoke all     on public.market_readiness_overview            from anon, authenticated;
revoke execute on function public.market_readiness(text, text) from public, anon, authenticated;
revoke execute on function public.is_market_ready(text, text)  from public, anon, authenticated;
-- metro_key is a pure helper; safe to leave callable, but keep it server-side too.
revoke execute on function public.metro_key(double precision, double precision, text, text) from public, anon, authenticated;
