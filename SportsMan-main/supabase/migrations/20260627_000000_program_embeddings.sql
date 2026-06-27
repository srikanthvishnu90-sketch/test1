-- ============================================================================
-- Sporve — listing (programs) embeddings for semantic discovery   2026-06-27
-- ============================================================================
-- AI foundation step (Phase 1.x). Adds a pgvector embedding to the LISTING table
-- — public.programs (the live offering; see docs/ai-foundation-audit.md). Coach
-- identity lives on providers; the embeddable content lives on programs.
--
-- WHAT IS EMBEDDED (descriptive content only): title, description, sport_type,
-- skill_level, age_group, whats_included. NEVER price, location/lat/lng/address,
-- availability (sessions), certifications, or background-check/verification —
-- those stay structured and are queried deterministically (hard rule).
--
-- RLS: embeddings INHERIT the parent row's visibility. The embedding is just a
-- column on programs, so the existing programs policies (public select when
-- status='published' + owning-provider full CRUD) already govern who can read
-- it. No policy is added, changed, or weakened here. (Recommendation: do
-- semantic search via a server-side RPC/Edge Function so raw vectors are never
-- shipped to clients — don't `select=embedding` from the client.)
--
-- Idempotent: extension/columns/index are all "if not exists". Safe to re-run.
-- ============================================================================

-- 1. pgvector. On Supabase the `extensions` schema is on the API roles'
--    search_path, so the unqualified `vector` type + `vector_cosine_ops` opclass
--    resolve without schema-qualifying.
create extension if not exists vector;

-- 2. Embedding columns on the listing table.
--    text-embedding-3-small (and the planned Voyage swap) produce 1536 dims.
alter table public.programs
  add column if not exists embedding            vector(1536),
  add column if not exists embedding_updated_at timestamptz,
  add column if not exists embedding_source_hash text;

-- 3. HNSW index for cosine-similarity search over the embedding.
create index if not exists idx_programs_embedding
  on public.programs using hnsw (embedding vector_cosine_ops);
