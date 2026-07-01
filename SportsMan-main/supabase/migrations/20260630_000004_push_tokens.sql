-- Phase B1 — push delivery foundation. Stores each user's push destination
-- (an FCM registration token, or a JSON web-push subscription — the `token`
-- column holds whichever, so this is provider-agnostic). RLS: a user owns only
-- their own tokens. Safe to re-run.
create table if not exists public.push_tokens (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references public.profiles (id) on delete cascade,
  token      text not null,
  platform   text not null default 'web', -- web | android | ios
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, token)
);

alter table public.push_tokens enable row level security;

drop policy if exists push_tokens_own on public.push_tokens;
create policy push_tokens_own on public.push_tokens
  for all to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

create index if not exists idx_push_tokens_user on public.push_tokens (user_id);
