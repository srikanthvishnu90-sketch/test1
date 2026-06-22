-- ============================================================================
-- Sporve — bookable FUTURE sessions for every program (fixes "No bookable
-- session is available for this program yet.")
-- ============================================================================
-- Why: the booking flow attaches a booking to the soonest UPCOMING session of
-- the chosen program (SupabaseRepository.addBooking filters start_date >= today).
-- A program with zero future sessions can't be booked. This gives EVERY
-- published program 5 sessions over the next ~3 weeks.
--
-- Columns match public.sessions exactly:
--   program_id, title, start_date (DATE), end_date (DATE), start_time (TEXT,
--   12h display form), end_time (TEXT), timezone (TEXT), address (TEXT),
--   capacity (INTEGER >= 0). id/created_at use their defaults.
--
-- Dates are CURRENT_DATE + N, so they are ALWAYS in the future when this runs
-- (no fixed dates that rot into the past; no timezone math — start_date is a
-- plain calendar date, matching the app's UTC-midnight convention).
--
-- Idempotent: re-running the SAME day inserts nothing new (guarded on
-- program_id + start_date + start_time). Re-running on a LATER day tops up with
-- fresh future sessions.
-- ============================================================================

with slots(day_offset, st, et) as (
  values
    (3,  '05:00 PM', '06:30 PM'),
    (7,  '10:00 AM', '11:30 AM'),
    (11, '05:00 PM', '06:30 PM'),
    (15, '04:00 PM', '05:30 PM'),
    (19, '10:00 AM', '11:30 AM')
)
insert into public.sessions
  (program_id, title, start_date, end_date, start_time, end_time,
   timezone, address, capacity)
select
  p.id,
  p.title,
  (current_date + s.day_offset)::date,
  (current_date + s.day_offset)::date,
  s.st,
  s.et,
  'EST',
  coalesce(
    nullif(concat_ws(', ', p.address_line1, p.city, p.state), ''),
    'See provider for location'
  ),
  8
from public.programs p
cross join slots s
where p.status = 'published'
  and not exists (
    select 1
    from public.sessions x
    where x.program_id = p.id
      and x.start_date = (current_date + s.day_offset)::date
      and x.start_time = s.st
  );
