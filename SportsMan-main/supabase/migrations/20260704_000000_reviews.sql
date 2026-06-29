-- ============================================================================
-- Sporve — reviews (Stage 3, C1)                                     2026-07-04
-- ============================================================================
-- Per-listing reviews with TEXT, so the retrieval core can return real review
-- excerpts for GROUNDED match explanations (ai-stage3-audit §4 flagged that only
-- aggregate rating/count existed). The aggregate columns programs.average_rating
-- / total_reviews remain the fast rank signal; this adds the queryable text.
--
-- RLS: review text for a PUBLISHED program is public (read-only excerpts power
-- explanations and the listing page). An author manages only their own review.
-- The search RPC reads via the service role regardless.
--
-- Idempotent. Safe to re-run.
-- ============================================================================

create table if not exists public.reviews (
  id         uuid primary key default gen_random_uuid(),
  program_id uuid not null references public.programs (id) on delete cascade,
  author_id  uuid references public.profiles (id) on delete set null,
  rating     integer not null check (rating between 1 and 5),
  body       text,
  created_at timestamptz not null default now()
);
create index if not exists idx_reviews_program on public.reviews (program_id, created_at desc);

alter table public.reviews enable row level security;

-- Public can read reviews of published programs (excerpts are public-safe).
drop policy if exists reviews_select_published on public.reviews;
create policy reviews_select_published on public.reviews for select to anon, authenticated
  using (exists (select 1 from public.programs p
                 where p.id = reviews.program_id and p.status = 'published'));

-- An author manages only their own review.
drop policy if exists reviews_insert_author on public.reviews;
create policy reviews_insert_author on public.reviews for insert to authenticated
  with check (author_id = auth.uid());
drop policy if exists reviews_update_author on public.reviews;
create policy reviews_update_author on public.reviews for update to authenticated
  using (author_id = auth.uid()) with check (author_id = auth.uid());
drop policy if exists reviews_delete_author on public.reviews;
create policy reviews_delete_author on public.reviews for delete to authenticated
  using (author_id = auth.uid());
