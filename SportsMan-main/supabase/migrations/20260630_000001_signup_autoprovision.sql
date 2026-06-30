-- Phase B #1 follow-up — make signup fully self-provisioning.
--
-- handle_new_user previously created ONLY a profiles row, so:
--   • a phone number captured at signup was dropped, and
--   • a coach signup had no providers row, so "Set up payouts" failed with
--     "No provider profile for this user".
--
-- This version (create-or-replace; safe to re-run):
--   1. carries raw_user_meta_data->>'phone' into profiles.phone_number, and
--   2. when role = 'provider', also inserts the providers row (owner_id +
--      business_name from the signup name) so payout onboarding works
--      immediately after signup.
create or replace function public.handle_new_user()
  returns trigger
  language plpgsql
  security definer
  set search_path = ''
as $$
declare
  full_name  text := coalesce(new.raw_user_meta_data ->> 'name', '');
  first_tok  text := split_part(full_name, ' ', 1);
  rest_tok   text := btrim(substr(full_name, length(split_part(full_name, ' ', 1)) + 1));
  the_role   text := case
                       when (new.raw_user_meta_data ->> 'role') in ('searcher', 'provider')
                         then new.raw_user_meta_data ->> 'role'
                       else 'searcher'
                     end;
begin
  insert into public.profiles (id, role, first_name, last_name, email, phone_number)
  values (
    new.id,
    the_role,
    coalesce(nullif(first_tok, ''), split_part(coalesce(new.email, 'member'), '@', 1), 'Member'),
    nullif(rest_tok, ''),
    new.email,
    nullif(new.raw_user_meta_data ->> 'phone', '')
  )
  on conflict (id) do nothing;

  -- A coach needs a providers row to receive payouts and list programs.
  if the_role = 'provider' then
    insert into public.providers (owner_id, business_name)
    values (new.id, coalesce(nullif(full_name, ''), 'My Academy'))
    on conflict (owner_id) do nothing;
  end if;

  return new;
exception
  when others then
    raise log 'handle_new_user failed for %: %', new.id, sqlerrm;
    return new;
end;
$$;
revoke execute on function public.handle_new_user() from public, anon, authenticated;

-- Re-bind the trigger (idempotent).
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();
