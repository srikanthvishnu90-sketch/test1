-- SECURITY (review blockers): bookings could be self-confirmed-as-paid and the
-- charge amount was client-controlled. This migration closes both. Safe to re-run.

-- 1) Authoritative price on INSERT. The buyer's client-sent original_price /
--    final_price are IGNORED and recomputed from the program's price × the tier
--    multiplier (must mirror session_details: PRO ×1.6, ELITE ×2.6, else ×1).
--    So a $1500 program can never be booked (or charged) for $1.
create or replace function public.set_booking_price()
  returns trigger
  language plpgsql
  security definer
  set search_path = ''
as $$
declare
  base numeric := 0;
  mult numeric := 1;
begin
  select price into base from public.programs where id = new.program_id;
  base := coalesce(base, 0);
  mult := case upper(coalesce(new.selected_tier, ''))
            when 'PRO' then 1.6
            when 'ELITE' then 2.6
            else 1
          end;
  new.original_price := round(base, 2);
  new.final_price := round(base * mult, 2);
  return new;
end;
$$;
revoke execute on function public.set_booking_price() from public, anon, authenticated;

drop trigger if exists trg_set_booking_price on public.bookings;
create trigger trg_set_booking_price
  before insert on public.bookings
  for each row execute function public.set_booking_price();

-- 2) Lock down booking UPDATEs. Only the SERVICE ROLE (the Stripe webhook) may
--    write payment_status / status freely. Authenticated users (searcher OR
--    provider) may NEVER change price, payment_status, or identity columns — the
--    old trigger let the owner change anything, so a buyer could flip
--    payment_status='paid' with no charge. Now only `status` is mutable by a
--    user (provider confirm/decline/complete), and payment is webhook-only.
create or replace function public.enforce_booking_provider_update()
  returns trigger
  language plpgsql
  set search_path = ''
as $$
begin
  -- Service role (no end-user uid): the webhook. Trusted to set payment_status.
  if auth.uid() is null then
    return new;
  end if;

  if new.searcher_id         is distinct from old.searcher_id
   or new.session_id         is distinct from old.session_id
   or new.athlete_id         is distinct from old.athlete_id
   or new.program_id         is distinct from old.program_id
   or new.athlete_first_name is distinct from old.athlete_first_name
   or new.athlete_age_band   is distinct from old.athlete_age_band
   or new.selected_tier      is distinct from old.selected_tier
   or new.original_price     is distinct from old.original_price
   or new.final_price        is distinct from old.final_price
   or new.currency           is distinct from old.currency
   or new.payment_status     is distinct from old.payment_status then
    raise exception 'Not allowed to modify booking price/payment/identity fields';
  end if;
  return new; -- only `status` may change
end;
$$;
revoke execute on function public.enforce_booking_provider_update() from public, anon, authenticated;

drop trigger if exists trg_enforce_booking_provider_update on public.bookings;
create trigger trg_enforce_booking_provider_update
  before update on public.bookings
  for each row execute function public.enforce_booking_provider_update();
