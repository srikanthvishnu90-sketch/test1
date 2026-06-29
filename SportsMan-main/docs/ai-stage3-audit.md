# Sporve — AI Stage-3 Audit (read-only)

**Date:** 2026-06-29 · **Scope:** repo + **live** Supabase project `tseszaprvtvqrkfpditu` (queried read-only via the Management API). **Nothing was changed.** Prepares the discovery/match layer (C1).

> ⚠️ **BLOCKER — plan file still missing.** `/docs/ai-layer-plan.md` does **not** exist in the repo (confirmed by search across prompts 11–16). Sections **3 (C1), 0.2–0.3, 1.2–1.5** could not be read. This audit is grounded in `docs/ai-foundation-audit.md`, `docs/ai-stage2-audit.md`, the live schema, and the Flutter code. Re-run against the plan once it exists.

> **Headline finding:** The Stage-0 **embedding column is NOT live** and **pgvector is NOT enabled** on the production DB — the `20260627_program_embeddings.sql` migration was never applied (same pattern as `services/availability`). Semantic discovery has **no backing column or index** today. See §1.

> **Data caveat:** the live DB currently holds **1 program** (1 published, 0 with geo) and **1 session** (0 upcoming) — essentially demo/empty. "Populated" numbers below reflect that.

---

## 1. Listing data — fields a parent filters/ranks on

All discovery content lives on **`public.programs`** (the live listing; coach identity is on `providers`). Columns relevant to filter/rank ([supabase/migrations/20260623_000000_baseline.sql:72-110](../supabase/migrations/20260623_000000_baseline.sql#L72-L110)):

| Concept | Column(s) | Type | Notes |
|---|---|---|---|
| **Sport** | `sport_type` | text (not null) | free text, no enum/lookup |
| **Price** | `price`, `currency`, `pricing_model` | numeric(10,2), text, text CHECK | pricing_model ∈ `single_session\|monthly\|seasonal\|package` |
| **Age / eligibility** | `age_group` (text), `minimum_age`, `maximum_age` (int) | mixed | both a display band AND numeric bounds exist |
| **Skill** | `skill_level` | text | free text |
| **Capacity** | `max_capacity`, `enrolled_count` | int | program-level, not per-session |
| **Rating** | `average_rating` (numeric(2,1)), `total_reviews` (int) | aggregate only (see §4) |
| **Status** | `status` | text CHECK `draft\|published\|archived` | public sees `published` only |
| **Featured** | `is_featured` | bool |

**"Session types":** there is **no `category`/`service_type` column.** The closest structured signal is `pricing_model` + `sport_type`. ⚠️ The Flutter filter offers a **"service type"** facet (`TRAINING/PROGRAMS/FACILITIES/CAMPS/GEAR`, [filter_screen.dart:169-192](../lib/presentation/client/view/filter_screen.dart#L169)) that **has no backing column** — it cannot be filtered server-side today (gap).

### Embedding column (Stage 0) — **NOT PRESENT on the live DB**
- The repo migration [supabase/migrations/20260627_000000_program_embeddings.sql](../supabase/migrations/20260627_000000_program_embeddings.sql) adds `embedding vector(1536)`, `embedding_updated_at`, `embedding_source_hash` + an HNSW index, embedding only descriptive fields (title/description/sport_type/skill_level/age_group/whats_included — never price/location/availability/certs).
- **Live check:** `select column_name … where table='programs' and column_name like 'embedding%'` → **`[]`** (no such columns). `pg_extension` shows **no `vector`** (nor `postgis/earthdistance/cube/pg_trgm`).
- **Conclusion:** the migration is **unapplied in production**; **embeddings do not exist and are not populated** (0 of 1 programs). The deployed `generate-embedding`/`backfill-embeddings` functions would currently fail to write the column. **This is the first gap to close for C1:** apply `20260627` (enable `vector`, add columns + HNSW), then backfill.

---

## 2. Geo / distance

- **Listings store lat/lng AND text address:** `programs.latitude`, `programs.longitude` (`double precision`) + `address_line1, city, state, zip, country` (text). `providers` also has `latitude`, `longitude` + a `location` (text).
- **BUT geo is unpopulated:** of 1 program, **0 have latitude/longitude and 0 have city**. So even though numeric columns exist, there is no usable coordinate data yet.
- **No distance/radius capability:** **no PostGIS, earthdistance, or cube** extensions are enabled (live `pg_extension` check). There is no SQL distance/radius function anywhere. The Flutter **radius slider** ([filter_screen.dart:60-73](../lib/presentation/client/view/filter_screen.dart#L60)) is **dead** (not wired to any query).
- ⚠️ **Gap: geocoding + distance.** Addresses are text and coordinates are empty.
  - **Lightest fix (proposed):** (a) **geocode on listing save** — when a coach saves a program with an address, resolve lat/lng server-side (Edge Function; store into the existing `latitude/longitude` columns — no schema change). (b) **distance without a new extension** — compute Haversine directly in a SQL RPC (`6371 * acos(...)`) for "within N km", since coordinates are plain doubles. Only reach for `cube`+`earthdistance` (or PostGIS) if you need indexed radius search at scale. A btree on `(latitude, longitude)` or a functional index can come later.

---

## 3. Availability

- Bookable availability = **`public.sessions`** (per-program scheduled sessions): `start_date` (date), `end_date`, `start_time`/`end_time` (**text**, e.g. `"05:00 PM"`), `timezone` (text), `address`, `capacity` (int). Bookings link via `bookings.session_id`.
- **"Open slot in next N days"** is expressible: `sessions` where `start_date between current_date and current_date + N` **and** `capacity > (count of bookings for that session)`. Joinable via `idx_bookings_session` (exists).
- ⚠️ **Cost flag:** there is **no index on `sessions.start_date`** (only `sessions_pkey` + `idx_sessions_program`). A date-range scan is fine at current scale (1 session) but should get a **btree on `start_date`** (and ideally a partial/expression index for upcoming sessions) before this is a hot query.
- ⚠️ **No richer availability model is live:** the `services`/`availability` supply tables defined in `20260626_000000_services_availability.sql` are **NOT applied** (live tables = only `sessions`). `programs.max_capacity/enrolled_count` is program-level, not per-slot. Treat `sessions`+`bookings` as the only availability source today.
- **Time-math caveat:** `start_time` is display text (`"05:00 PM"`), so "next N days" filtering on the **date** is cheap, but precise time-of-day ordering needs the same best-effort parse used by `enqueue_reminders_24h` ([20260630…sql](../supabase/migrations/20260630_000000_lifecycle_deterministic.sql)).

---

## 4. Reviews

- **There is NO reviews table.** Live check: no `public.*review*` table exists. The only review data is the **aggregate** pair on `programs`: `average_rating numeric(2,1)` (0–5 CHECK) and `total_reviews int`.
- **Per-listing rating + count:** available (the two aggregate columns).
- **Review TEXT is NOT stored anywhere** → **not queryable** for grounded match explanations (read-only excerpts). 
- ⚠️ **Gap:** grounding "why this matches" on real review snippets requires a **`reviews` table** (e.g. `id, program_id, author_id, rating, body, created_at` with RLS) that stores text. Until then, match explanations can only cite the aggregate rating/count, never quotes. (Out of scope to embed review text yet — the ask is read-only excerpts.)

---

## 5. Full-text search

- **Postgres FTS is NOT configured.** Live checks: **no `tsvector` columns**, **no GIN / `to_tsvector` indexes**, and **no `pg_trgm`** extension. (The only `*search*` column hits are `searcher_id` FKs — false positives.)
- Current "search" is **client-side substring matching** on `title`/`coach`/`team` only ([search_screen.dart:103-109](../lib/presentation/client/view/search_screen.dart#L103)) — no server-side keyword search at all.
- ⚠️ **Note (not yet required):** if C1 wants a keyword fallback alongside semantic ranking, add a generated `tsvector` (over `title, description, sport_type, whats_included`) + GIN index, or `pg_trgm` for fuzzy. Flagged as absent.

---

## 6. Existing browse/search UI (reuse target)

**Screens** (consumer):
- [home_screen.dart](../lib/presentation/client/view/home_screen.dart) — "NEAR YOU" carousel + program list; search field entry.
- [search_screen.dart](../lib/presentation/client/view/search_screen.dart) — map metaphor + draggable results sheet; **already shows an `AIBadge('AI Recommend')`** ([:314](../lib/presentation/client/view/search_screen.dart#L314)).
- [nearby_session_screen.dart](../lib/presentation/client/view/nearby_session_screen.dart) — simulated map of programs.

**Result cards (reuse these for AI results):**
- `NearYouCard` ([common_widgets.dart:376-502](../lib/presentation/widgets/common_widgets.dart#L376)) — image, sport tag, title, provider, price, rating.
- `ProgramListItem` ([common_widgets.dart:507-596](../lib/presentation/widgets/common_widgets.dart#L507)) — sport icon-tile, title, sport, rating, price.
- Search list/recommended cards: `_buildOpportunityCard` ([search_screen.dart:645-766](../lib/presentation/client/view/search_screen.dart#L645)) and `_buildRecommendedCard` ([:397-570](../lib/presentation/client/view/search_screen.dart#L397)).
- **Book path:** every card → `AppRoutes.sessionDetails` with an `Opportunity` → [session_details_screen.dart](../lib/presentation/client/view/session_details_screen.dart) (tier pricing) → **`AppRoutes.bookingFlow`** ([booking_flow_screen.dart](../lib/presentation/client/view/booking_flow_screen.dart), Stripe checkout). **AI results should return ranked listings and render through these same cards → SessionDetails → Book** (no new card needed).

**Service-layer pattern:**
- UI → `HomeProvider` (ChangeNotifier, [home_controller.dart](../lib/presentation/client/controllers/home_controller.dart)) → `_repo.getPrograms()` on `AppRepository`. ([home_controller.dart:133](../lib/presentation/client/controllers/home_controller.dart#L133)).
- Existing "recommend" is a **deterministic** keyword/team score ([home_controller.dart:226-267](../lib/presentation/client/controllers/home_controller.dart#L226)) — no AI/embeddings.
- ⚠️ Per CLAUDE.md, AI search MUST go through a **server-side RPC/Edge Function via `ai-gateway` + `generate-embedding`** (never ship vectors/keys to the client). Add a new repository method (e.g. `searchListings(query)`) that invokes that function and returns ranked listings to reuse the cards — mirror the `summarizeSessionNote`/`draftMessage` repo pattern.

**Filters:** [filter_screen.dart](../lib/presentation/client/view/filter_screen.dart) offers Sport / Service-type / Radius / Skill, **but the state is DEAD** — "Apply" only `Get.back()`s; nothing reaches `HomeProvider` or any query ([filter_screen.dart:100](../lib/presentation/client/view/filter_screen.dart#L100)). C1 must decide whether filters wire into the AI search RPC (recommended) or stay local.

---

## Explicit unknowns / gaps (consolidated)

1. **`/docs/ai-layer-plan.md` missing** — C1/§0.2–0.3/§1.2–1.5 unverified against any plan.
2. **Stage-0 embeddings NOT live** — `embedding` column absent, `vector` extension not enabled (`20260627` unapplied); 0/1 programs embedded. Must apply + backfill before semantic match.
3. **Geo unpopulated + no distance capability** — lat/lng columns exist but empty; no PostGIS/earthdistance; radius slider is dead. Needs geocode-on-save + Haversine RPC (lightest).
4. **"Service type" facet has no backing column** — the UI filter can't be served from the DB.
5. **Availability has no `start_date` index** and the `services/availability` tables are unapplied — `sessions`+`bookings` is the only source.
6. **No reviews table** — only aggregate rating/count; review text isn't stored, so grounded excerpt explanations aren't possible yet.
7. **No Postgres FTS / pg_trgm** — keyword search is client-side substring only.
8. **AI search not wired to `ai-gateway`** — consumer search has an `AIBadge` placeholder + a deterministic scorer; no server-side semantic path; filters are dead state.
9. **Near-empty live data** (1 program, 1 session) — all "populated" findings are against demo data; re-confirm once real listings exist.
