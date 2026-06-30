-- ============================================================================
-- Sporve — enable realtime on chat messages                          2026-07-07
-- ============================================================================
-- The Flutter app subscribes to message inserts per conversation (RLS-scoped:
-- participants only). Realtime delivers postgres_changes only for tables in the
-- supabase_realtime publication, so add messages to it. Idempotent.
-- ============================================================================
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'messages'
  ) then
    alter publication supabase_realtime add table public.messages;
  end if;
exception when others then
  raise notice 'realtime publication not updated (%): ensure supabase_realtime exists', sqlerrm;
end $$;
