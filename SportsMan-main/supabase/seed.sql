-- ============================================================================
-- Sporve — demo seed (#19). Mirrors lib/core/mock/mock_data.dart so the live
-- app shows the same kind of content the mock demo did.
-- ============================================================================
-- PREREQUISITE: create these 3 auth users first (Supabase → Authentication →
-- Add user, or sign them up in-app), so the owner lookups below resolve:
--     coach.soccer@sporve.demo   (Soccer  — Apex Performance Club)
--     coach.tennis@sporve.demo   (Tennis  — Baseline Tennis Academy)
--     coach.hoops@sporve.demo    (Basketball — Downtown Hoops Lab)
-- (Plus a SEARCHER account to browse/book, e.g. searcher@sporve.demo — it needs
--  no seed rows; it creates its own athletes/bookings in-app.)
--
-- RE-RUNNABLE: providers upsert on unique(owner_id); programs/sessions use fixed
-- UUIDs with `on conflict (id) do nothing`, and child rows insert via SELECT so
-- a missing parent simply inserts nothing (no FK error). Safe to run repeatedly.
-- Dates are FUTURE (relative to 2026-06-21) so they land in Home/Schedule.
-- ============================================================================

-- ── PROVIDERS (owner_id looked up from auth.users by email) ─────────────────
insert into public.providers
  (owner_id, business_name, bio, sports, location, latitude, longitude,
   status, onboarding_completed, verification_status)
select u.id, 'Apex Performance Club',
       'Elite youth soccer training clinics with certified coaches.',
       array['Soccer'], 'Miami, FL', 25.7617, -80.1918,
       'approved', true, 'verified'
from auth.users u where u.email = 'coach.soccer@sporve.demo'
on conflict (owner_id) do nothing;

insert into public.providers
  (owner_id, business_name, bio, sports, location, latitude, longitude,
   status, onboarding_completed, verification_status)
select u.id, 'Baseline Tennis Academy',
       'Junior tennis coaching for all levels, from first racquet to match play.',
       array['Tennis'], 'Miami, FL', 25.7700, -80.2000,
       'approved', true, 'verified'
from auth.users u where u.email = 'coach.tennis@sporve.demo'
on conflict (owner_id) do nothing;

insert into public.providers
  (owner_id, business_name, bio, sports, location, latitude, longitude,
   status, onboarding_completed, verification_status)
select u.id, 'Downtown Hoops Lab',
       'Skills-focused basketball training for developing young players.',
       array['Basketball'], 'Miami, FL', 25.7740, -80.1937,
       'approved', true, 'verified'
from auth.users u where u.email = 'coach.hoops@sporve.demo'
on conflict (owner_id) do nothing;

-- ── PROGRAMS (fixed UUIDs; inserted only if the owning coach exists) ─────────
-- Soccer (mirrors mock prog_1)
insert into public.programs
  (id, provider_id, title, description, sport_type, skill_level, age_group,
   language, cover_image, gallery, whats_included, price, currency,
   pricing_model, max_capacity, enrolled_count, longitude, latitude,
   address_line1, city, state, zip, country, cancellation_policy,
   minimum_age, maximum_age, is_featured, status, average_rating, total_reviews)
select 'a0000000-0000-0000-0000-000000000001', pv.id,
       'Elite Soccer Academy - U12 Training',
       'High-intensity technical training focusing on dribbling, passing, and match awareness.',
       'Soccer', 'Intermediate', 'Youth (Under 12)', 'English',
       'https://picsum.photos/seed/court-basketball/600/400',
       array['https://picsum.photos/seed/court-basketball/600/400',
             'https://picsum.photos/seed/court-tennis/600/400'],
       array['Training Bibs','Water Bottles','Professional Coaching'],
       45.0, 'USD', 'single_session', 15, 8, -80.1918, 25.7617,
       '123 Coral Way', 'Miami', 'FL', '33145', 'USA', 'moderate',
       9, 12, true, 'published', 4.8, 12
from public.providers pv
join auth.users u on u.id = pv.owner_id
where u.email = 'coach.soccer@sporve.demo'
on conflict (id) do nothing;

-- Tennis (mirrors mock prog_2)
insert into public.programs
  (id, provider_id, title, description, sport_type, skill_level, age_group,
   language, cover_image, gallery, whats_included, price, currency,
   pricing_model, max_capacity, enrolled_count, longitude, latitude,
   address_line1, city, state, zip, country, cancellation_policy,
   minimum_age, maximum_age, is_featured, status, average_rating, total_reviews)
select 'a0000000-0000-0000-0000-000000000002', pv.id,
       'Junior Tennis Clinic - All Levels',
       'Learn basic and advanced tennis strokes, service, and court strategies from certified instructors.',
       'Tennis', 'All Levels', 'Juniors (Under 16)', 'English',
       'https://picsum.photos/seed/court-soccer/600/400',
       array['https://picsum.photos/seed/court-soccer/600/400'],
       array['Tennis Balls','Racquet rentals'],
       120.0, 'USD', 'monthly', 8, 5, -80.2000, 25.7700,
       '450 Tennis Center Dr', 'Miami', 'FL', '33149', 'USA', 'strict',
       10, 16, false, 'published', 4.5, 8
from public.providers pv
join auth.users u on u.id = pv.owner_id
where u.email = 'coach.tennis@sporve.demo'
on conflict (id) do nothing;

-- Basketball (new third sport)
insert into public.programs
  (id, provider_id, title, description, sport_type, skill_level, age_group,
   language, cover_image, gallery, whats_included, price, currency,
   pricing_model, max_capacity, enrolled_count, longitude, latitude,
   address_line1, city, state, zip, country, cancellation_policy,
   minimum_age, maximum_age, is_featured, status, average_rating, total_reviews)
select 'a0000000-0000-0000-0000-000000000003', pv.id,
       'Downtown Hoops Skills Lab',
       'Ball-handling, shooting form, and footwork fundamentals for young players.',
       'Basketball', 'Beginner', 'Youth (Under 14)', 'English',
       'https://picsum.photos/seed/court-hoops/600/400',
       array['https://picsum.photos/seed/court-hoops/600/400'],
       array['Game Jersey','Basketball','Skills Assessment'],
       60.0, 'USD', 'single_session', 12, 6, -80.1937, 25.7740,
       '88 Downtown Ave', 'Miami', 'FL', '33130', 'USA', 'flexible',
       8, 14, true, 'published', 4.7, 9
from public.providers pv
join auth.users u on u.id = pv.owner_id
where u.email = 'coach.hoops@sporve.demo'
on conflict (id) do nothing;

-- ── SESSIONS (future dates; inserted only if the parent program exists) ─────
insert into public.sessions
  (id, program_id, title, start_date, end_date, start_time, end_time, timezone, address)
select 'b0000000-0000-0000-0000-000000000001', p.id,
       'Soccer Skill Session 1', date '2026-06-25', date '2026-06-25',
       '05:00 PM', '06:30 PM', 'EST', '123 Coral Way, Miami, FL'
from public.programs p where p.id = 'a0000000-0000-0000-0000-000000000001'
on conflict (id) do nothing;

insert into public.sessions
  (id, program_id, title, start_date, end_date, start_time, end_time, timezone, address)
select 'b0000000-0000-0000-0000-000000000002', p.id,
       'Soccer Skill Session 2', date '2026-06-29', date '2026-06-29',
       '05:00 PM', '06:30 PM', 'EST', '123 Coral Way, Miami, FL'
from public.programs p where p.id = 'a0000000-0000-0000-0000-000000000001'
on conflict (id) do nothing;

insert into public.sessions
  (id, program_id, title, start_date, end_date, start_time, end_time, timezone, address)
select 'b0000000-0000-0000-0000-000000000003', p.id,
       'Weekly Tennis Practice', date '2026-06-26', date '2026-06-26',
       '04:00 PM', '05:30 PM', 'EST', '450 Tennis Center Dr, Miami, FL'
from public.programs p where p.id = 'a0000000-0000-0000-0000-000000000002'
on conflict (id) do nothing;

insert into public.sessions
  (id, program_id, title, start_date, end_date, start_time, end_time, timezone, address)
select 'b0000000-0000-0000-0000-000000000004', p.id,
       'Tennis Match Play Clinic', date '2026-07-03', date '2026-07-03',
       '04:00 PM', '05:30 PM', 'EST', '450 Tennis Center Dr, Miami, FL'
from public.programs p where p.id = 'a0000000-0000-0000-0000-000000000002'
on conflict (id) do nothing;

insert into public.sessions
  (id, program_id, title, start_date, end_date, start_time, end_time, timezone, address)
select 'b0000000-0000-0000-0000-000000000005', p.id,
       'Hoops Fundamentals 1', date '2026-06-27', date '2026-06-27',
       '06:00 PM', '07:30 PM', 'EST', '88 Downtown Ave, Miami, FL'
from public.programs p where p.id = 'a0000000-0000-0000-0000-000000000003'
on conflict (id) do nothing;

insert into public.sessions
  (id, program_id, title, start_date, end_date, start_time, end_time, timezone, address)
select 'b0000000-0000-0000-0000-000000000006', p.id,
       'Hoops Fundamentals 2', date '2026-07-04', date '2026-07-04',
       '06:00 PM', '07:30 PM', 'EST', '88 Downtown Ave, Miami, FL'
from public.programs p where p.id = 'a0000000-0000-0000-0000-000000000003'
on conflict (id) do nothing;
