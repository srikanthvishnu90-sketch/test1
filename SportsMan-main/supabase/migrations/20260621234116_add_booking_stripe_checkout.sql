-- #20b: track the Stripe Checkout Session that paid for a booking. Set when the
-- checkout is created; the #20c webhook reads it back to flip payment_status to
-- 'paid'. (payment_status already exists on bookings.)
alter table public.bookings
  add column if not exists stripe_checkout_session_id text;
