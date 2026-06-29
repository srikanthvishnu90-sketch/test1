-- ============================================================================
-- Sporve — Lifecycle messaging: drive the worker on a schedule       2026-07-01
-- ============================================================================
-- Wires pg_cron to invoke the `lifecycle-process` Edge Function every minute
-- (it picks up DUE 'pending' outbound_messages and drafts/auto-sends per the
-- coach's mode). The time-based ENQUEUERS (reminder_24h hourly, rebook_nudge
-- daily) were already scheduled in 20260630_000000_lifecycle_deterministic.sql;
-- this migration adds the content/processing tick.
--
-- The worker is reached over HTTP via pg_net, authenticated with the service
-- role. The project URL + service-role key are read from Supabase Vault so no
-- secret is committed. Set them once per project:
--     select vault.create_secret('https://<ref>.supabase.co', 'project_url');
--     select vault.create_secret('<service_role_key>',          'service_role_key');
--
-- Defensive: if pg_cron / pg_net are unavailable the migration still succeeds;
-- run lifecycle-process from any external scheduler until they are enabled.
-- Idempotent. Safe to re-run.
-- ============================================================================

-- Add a transient 'processing' status so the worker can ATOMICALLY claim a row
-- (pending -> processing) before doing any side-effect. This makes the worker
-- safe against overlapping cron ticks (no double-draft / double-send). Additive.
alter table public.outbound_messages drop constraint if exists outbound_messages_status_check;
alter table public.outbound_messages add constraint outbound_messages_status_check
  check (status in ('pending','processing','drafted','approved','sent','skipped'));

-- Invoker: POSTs to the Edge Function with the service-role bearer. Reads URL+key
-- from Vault at call time (never hardcoded). SECURITY DEFINER, server-only.
create or replace function public.invoke_lifecycle_process()
  returns void
  language plpgsql
  security definer
  set search_path = ''
as $$
declare v_url text; v_key text;
begin
  select decrypted_secret into v_url from vault.decrypted_secrets where name = 'project_url';
  select decrypted_secret into v_key from vault.decrypted_secrets where name = 'service_role_key';
  if v_url is null or v_url = '' or v_key is null or v_key = '' then
    raise log 'invoke_lifecycle_process: vault secrets project_url/service_role_key not set; skipping tick';
    return;
  end if;
  perform net.http_post(
    url     => v_url || '/functions/v1/lifecycle-process',
    headers => jsonb_build_object(
                 'Content-Type', 'application/json',
                 'Authorization', 'Bearer ' || v_key),
    body    => '{}'::jsonb
  );
end $$;
revoke execute on function public.invoke_lifecycle_process() from public, anon, authenticated;

-- Schedule it (defensive — skip cleanly if pg_cron / pg_net are unavailable).
do $$
begin
  create extension if not exists pg_cron;
  create extension if not exists pg_net;

  if exists (select 1 from cron.job where jobname = 'lifecycle-process') then
    perform cron.unschedule('lifecycle-process');
  end if;
  -- every minute: process due pending rows
  perform cron.schedule('lifecycle-process', '* * * * *',
                        $cron$select public.invoke_lifecycle_process();$cron$);

  raise notice 'lifecycle-process scheduled (every minute) via pg_cron + pg_net.';
exception when others then
  raise notice 'pg_cron/pg_net unavailable (%); lifecycle-process NOT scheduled. Invoke the Edge Function from an external scheduler until they are enabled.', sqlerrm;
end $$;
