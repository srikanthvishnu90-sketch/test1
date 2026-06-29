-- ============================================================================
-- Sporve — hybrid retrieval RPC + relax suggestion (Stage 3, C1)     2026-07-05
-- ============================================================================
-- search_listings(constraints, query_embedding): HARD constraints as SQL WHERE
-- (deterministic pass/fail — never ranked away), then RANK the survivors by a
-- blend of pgvector cosine + review-quality + keyword/FTS. Returns the top 20
-- with distance/price/rating/availability + real bio/specialty + up to 2 review
-- excerpts (for grounded explanations).
--
-- search_relax(constraints): when too few listings pass the hard filters, returns
-- the single cheapest constraint to relax, computed from the ACTUAL data
-- (e.g. "nearest is $85" / "expand radius to 10mi for 3 options").
--
-- Geo: lat/lng are plain doubles (no PostGIS — ai-stage3-audit §2), so distance
-- is Haversine in SQL. vector ops live in the `extensions` schema on Supabase, so
-- search_path includes it (locally pgvector is in public — both resolve).
--
-- Idempotent. Safe to re-run.
-- ============================================================================

-- ── Hard-filtered candidate set (shared by search + relax) ──────────────────
-- Applies the STRUCTURAL hard constraints (published, sport, age, availability)
-- but NOT price/radius, so relax can evaluate those two against the same base.
create or replace function public.search_candidates(constraints jsonb)
  returns table (
    program_id uuid, price numeric, dist double precision, avail boolean
  ) language sql stable security definer set search_path = public, extensions as $$
  with c as (
    select
      nullif(constraints->>'sport','')            as sport,
      (constraints->>'athlete_age')::int          as athlete_age,
      (constraints->>'lat')::double precision      as lat,
      (constraints->>'lng')::double precision      as lng,
      coalesce((constraints->>'within_days')::int, 30) as within_days
  )
  select
    pr.id,
    pr.price,
    case when c.lat is not null and c.lng is not null
              and pr.latitude is not null and pr.longitude is not null
      then 3959 * acos(least(1, greatest(-1,
            cos(radians(c.lat))*cos(radians(pr.latitude))*cos(radians(pr.longitude)-radians(c.lng))
            + sin(radians(c.lat))*sin(radians(pr.latitude)))))
      else null end as dist,
    exists (
      select 1 from public.sessions s
      where s.program_id = pr.id
        and s.start_date >= current_date
        and s.start_date <= current_date + c.within_days
        and (s.capacity = 0 or s.capacity > (
          select count(*) from public.bookings b
          where b.session_id = s.id and b.status in ('pending','confirmed')))
    ) as avail
  from public.programs pr cross join c
  where pr.status = 'published'
    and (c.sport is null or lower(pr.sport_type) = lower(c.sport))
    and (c.athlete_age is null
         or ((pr.minimum_age is null or c.athlete_age >= pr.minimum_age)
             and (pr.maximum_age is null or c.athlete_age <= pr.maximum_age)));
$$;
revoke execute on function public.search_candidates(jsonb) from public, anon, authenticated;

-- ── The retrieval core ──────────────────────────────────────────────────────
create or replace function public.search_listings(
  constraints jsonb, query_embedding text default null
) returns table (
  program_id uuid, title text, bio text, specialty text,
  price numeric, currency text, rating numeric, review_count integer,
  distance_miles double precision, has_availability boolean,
  review_excerpts text[],
  score double precision, sem_score double precision,
  review_score double precision, keyword_score double precision
) language sql stable security definer set search_path = public, extensions as $$
  with c as (
    select
      (constraints->>'max_price')::numeric        as max_price,
      (constraints->>'radius_miles')::double precision as radius_miles,
      nullif(constraints->>'query_text','')        as query_text
  ),
  filtered as (
    select cand.program_id, cand.dist
    from public.search_candidates(constraints) cand cross join c
    where cand.avail = true                                  -- HARD: bookable availability
      and (c.max_price is null or cand.price <= c.max_price) -- HARD: price cap
      and (                                                  -- HARD: radius (only if asked)
        c.radius_miles is null
        or (cand.dist is not null and cand.dist <= c.radius_miles)
      )
  ),
  scored as (
    select
      pr.id, pr.title, pv.bio as bio,
      (coalesce(pr.sport_type,'') ||
        case when pr.skill_level is not null then ' · ' || pr.skill_level else '' end) as specialty,
      pr.price, pr.currency, pr.average_rating, pr.total_reviews,
      f.dist,
      -- semantic: cosine similarity 0..1 (0 when either vector is absent)
      case when query_embedding is not null and pr.embedding is not null
        then 1 - (pr.embedding <=> query_embedding::vector) else 0 end as sem,
      -- review quality: rating scaled by a volume-confidence factor (caps at 1)
      least(1, (coalesce(pr.average_rating,0)/5.0) * (ln(coalesce(pr.total_reviews,0)+1)/ln(50))) as revq,
      -- keyword/FTS: ts_rank over descriptive text vs the raw query (no index; fine here)
      case when (select query_text from c) is not null then least(1, 10 * ts_rank(
             to_tsvector('english', coalesce(pr.title,'')||' '||coalesce(pr.description,'')||' '||array_to_string(pr.whats_included,' ')),
             plainto_tsquery('english', (select query_text from c)))) else 0 end as kw
    from filtered f
    join public.programs pr on pr.id = f.program_id
    join public.providers pv on pv.id = pr.provider_id
  )
  select
    s.id, s.title, s.bio, s.specialty,
    s.price, s.currency, s.average_rating, s.total_reviews,
    s.dist, true as has_availability,
    coalesce((
      select array_agg(r.body)
      from (select body from public.reviews rv
            where rv.program_id = s.id and rv.body is not null
            order by rv.created_at desc limit 2) r
    ), '{}'::text[]) as review_excerpts,
    (0.60*s.sem + 0.25*s.revq + 0.15*s.kw) as score,
    s.sem, s.revq, s.kw
  from scored s
  order by score desc, s.average_rating desc nulls last, s.total_reviews desc
  limit 20;
$$;
revoke execute on function public.search_listings(jsonb, text) from public, anon, authenticated;

-- ── Relax suggestion (data-driven; cheapest single constraint to relax) ─────
create or replace function public.search_relax(constraints jsonb, p_min_results int default 3)
  returns jsonb language plpgsql stable security definer set search_path = public, extensions as $$
declare
  v_cap numeric := (constraints->>'max_price')::numeric;
  v_radius double precision := (constraints->>'radius_miles')::double precision;
  v_full int;
  v_price_gain int; v_cheapest numeric;
  v_radius_needed double precision; v_radius_gain int;
begin
  -- full result count (all hard constraints applied)
  select count(*) into v_full
  from public.search_candidates(constraints) cand
  where cand.avail
    and (v_cap is null or cand.price <= v_cap)
    and (v_radius is null or (cand.dist is not null and cand.dist <= v_radius));
  if v_full >= p_min_results then
    return jsonb_build_object('relax', null, 'results', v_full);
  end if;

  -- PRICE relax: cheapest listing just over the cap (radius still applied).
  if v_cap is not null then
    select min(price), count(*) into v_cheapest, v_price_gain
    from public.search_candidates(constraints) cand
    where cand.avail and cand.price > v_cap
      and (v_radius is null or (cand.dist is not null and cand.dist <= v_radius));
  end if;

  -- RADIUS relax: the radius needed to reach p_min_results (price still applied).
  if v_radius is not null then
    select dist into v_radius_needed from (
      select cand.dist
      from public.search_candidates(constraints) cand
      where cand.avail and cand.dist is not null and cand.dist > v_radius
        and (v_cap is null or cand.price <= v_cap)
      order by cand.dist
      offset greatest(0, p_min_results - v_full - 1) limit 1
    ) q;
    select count(*) into v_radius_gain
    from public.search_candidates(constraints) cand
    where cand.avail and cand.dist is not null and cand.dist <= coalesce(v_radius_needed, v_radius)
      and (v_cap is null or cand.price <= v_cap);
  end if;

  -- Pick the SINGLE CHEAPEST constraint to relax, measured as the smallest
  -- RELATIVE stretch from what the parent asked for (price % over cap vs radius
  -- % over the asked radius). Whichever is the smaller change wins.
  declare
    price_cost double precision := case when v_cheapest is not null and v_cap > 0
                                        then (v_cheapest - v_cap) / v_cap else null end;
    radius_cost double precision := case when v_radius_needed is not null and v_radius > 0
                                         then (v_radius_needed - v_radius) / v_radius else null end;
  begin
    -- Budget is the stickiest constraint: prefer expanding radius (which keeps
    -- the parent WITHIN their price cap) unless raising price is clearly cheaper
    -- (radius gets a 2x cost advantage so we never suggest blowing the budget
    -- over a marginal stretch). Only suggest price when widening can't help.
    if radius_cost is not null and (price_cost is null or radius_cost <= 2 * price_cost) then
      return jsonb_build_object(
        'relax', 'radius', 'results', v_full,
        'radius_needed_miles', ceil(v_radius_needed),
        'options_if_relaxed', coalesce(v_radius_gain,0),
        'message', format('Expand your radius to %s mi for %s option(s).',
                          ceil(v_radius_needed)::text, coalesce(v_radius_gain,0)));
    elsif v_cheapest is not null then  -- price the cheaper (or only) lever
      return jsonb_build_object(
        'relax', 'price', 'results', v_full,
        'cheapest_over_cap', v_cheapest,
        'options_if_relaxed', coalesce(v_price_gain,0) + v_full,
        'message', format('The nearest match is $%s. Raise your max to $%s for %s option(s).',
                          round(v_cheapest)::text, round(v_cheapest)::text, coalesce(v_price_gain,0) + v_full));
    else
      return jsonb_build_object('relax', 'broaden', 'results', v_full,
        'message', 'No matches with these constraints. Try a different sport, age, or location.');
    end if;
  end;
end $$;
revoke execute on function public.search_relax(jsonb, int) from public, anon, authenticated;
