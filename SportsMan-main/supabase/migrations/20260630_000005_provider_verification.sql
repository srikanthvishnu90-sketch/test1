-- SECURITY (B2 provider verification): a provider could self-set their own
-- `status` (→ 'approved', publicly discoverable) AND self-grant the 'verified'
-- trust badge, because providers_update_owner allows updating ANY column and
-- there was no trigger guard (unlike bookings). This migration makes status and
-- the trust/payment columns SERVER-CONTROLLED. Safe to re-run.
--
-- Model:
--   • verification_status ('verified' = the trust badge families see) → ADMIN /
--     service-role ONLY. A provider can NEVER self-verify.
--   • stripe_account_id / stripe_charges_enabled → server-only (set by the
--     stripe-connect-onboarding function as service role).
--   • status → DERIVED, never taken from the client: completing onboarding
--     (onboarding_completed = true) lists the provider ('approved'); otherwise
--     'pending'. An admin 'suspended'/'rejected' can't be undone by the owner.

create or replace function public.enforce_provider_trust()
  returns trigger
  language plpgsql
  security definer
  set search_path = ''
as $$
begin
  -- Service role (Stripe onboarding, admin SQL/RPC): fully trusted — auth.uid()
  -- is null with no end-user JWT. This is how verification + payment get set.
  if auth.uid() is null then
    return new;
  end if;

  -- ── Owner path: trust + payment columns are server-controlled ─────────────
  if tg_op = 'INSERT' then
    -- A provider can never be born verified or payment-enabled.
    new.verification_status    := 'unverified';
    new.stripe_charges_enabled := false;
    new.stripe_account_id      := null;
  elsif tg_op = 'UPDATE' then
    if new.verification_status    is distinct from old.verification_status
     or new.stripe_account_id      is distinct from old.stripe_account_id
     or new.stripe_charges_enabled is distinct from old.stripe_charges_enabled then
      raise exception
        'verification_status / stripe fields are server-controlled and cannot be self-set';
    end if;
  end if;

  -- ── status is DERIVED, never trusted from the client ──────────────────────
  -- Completing onboarding lists the provider (discoverability only — NOT the
  -- 'verified' trust badge, which is admin-only above).
  if tg_op = 'UPDATE' and old.status in ('suspended','rejected') then
    new.status := old.status;                 -- admin action the owner can't undo
  else
    new.status := case
                    when coalesce(new.onboarding_completed, false) then 'approved'
                    else 'pending'
                  end;
  end if;

  return new;
end;
$$;
revoke execute on function public.enforce_provider_trust() from public, anon, authenticated;

drop trigger if exists trg_enforce_provider_trust on public.providers;
create trigger trg_enforce_provider_trust
  before insert or update on public.providers
  for each row execute function public.enforce_provider_trust();

-- Backfill: keep already-listed providers listed. Existing rows were made
-- 'approved' by the old self-set path (often with onboarding_completed still
-- false); mark them complete so the new derivation keeps status = 'approved'
-- instead of flipping them back to 'pending' on their next profile edit.
update public.providers
  set onboarding_completed = true
  where status = 'approved' and onboarding_completed = false;

-- Admin helper (service-role only) to grant/revoke the verified trust badge.
-- Runs as service role in the SQL editor; callable via service key. Not exposed
-- to anon/authenticated, so no provider can invoke it to self-verify.
create or replace function public.admin_set_provider_verification(
  p_provider_id uuid,
  p_status text
) returns void
  language plpgsql
  security definer
  set search_path = ''
as $$
begin
  -- Defense in depth: service-role only, even if a future migration mistakenly
  -- GRANTs EXECUTE to authenticated. The service role has no end-user JWT, so
  -- auth.uid() is null; any real user (auth.uid() set) is rejected here.
  if auth.uid() is not null then
    raise exception 'admin_set_provider_verification is service-role only';
  end if;
  if p_status not in ('unverified','pending','verified') then
    raise exception 'verification_status must be unverified | pending | verified';
  end if;
  update public.providers
    set verification_status = p_status
    where id = p_provider_id;
end;
$$;
revoke execute on function public.admin_set_provider_verification(uuid, text)
  from public, anon, authenticated;
