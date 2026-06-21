-- ============================================================================
-- Sporve — auto-provision a public.profiles row on signup (#18, auth)
-- ============================================================================
-- Supabase auth.signUp() only writes auth.users (with role/name in
-- user_metadata). The app keeps its DATA on MockRepository until #19, so the
-- profile row is created server-side by this trigger — keeping the client's
-- data layer untouched while still giving every user a profiles row keyed to
-- auth.uid() with the role they chose at signup.
--
-- SECURITY DEFINER: the trigger runs as the function owner so it can insert
-- past RLS (the new user has no session yet at insert time). search_path is
-- pinned to public to prevent search-path hijacking.
-- ============================================================================

create or replace function public.handle_new_user()
  returns trigger
  language plpgsql
  security definer
  set search_path = public
as $$
declare
  full_name text := coalesce(new.raw_user_meta_data ->> 'name', '');
begin
  insert into public.profiles (id, role, first_name, last_name, email)
  values (
    new.id,
    -- role must satisfy the profiles check (searcher|provider); default safely.
    case
      when (new.raw_user_meta_data ->> 'role') in ('searcher', 'provider')
        then new.raw_user_meta_data ->> 'role'
      else 'searcher'
    end,
    -- first token of the name (profiles.first_name is NOT NULL).
    coalesce(nullif(split_part(full_name, ' ', 1), ''), 'Member'),
    -- everything after the first token, or null.
    nullif(trim(substring(full_name from position(' ' in full_name))), ''),
    new.email
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();
