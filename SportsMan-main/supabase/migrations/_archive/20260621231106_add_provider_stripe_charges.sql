-- #20a: track whether the provider's Stripe Connect account can accept
-- charges/payouts. Flipped to true by the Stripe webhook in #20c; defaults
-- false until Connect onboarding completes. (stripe_account_id already exists.)
alter table public.providers
  add column if not exists stripe_charges_enabled boolean not null default false;
