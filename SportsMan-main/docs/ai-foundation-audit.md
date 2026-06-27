# Sporve — AI Foundation Audit (read-only)

**Date:** 2026-06-27 · **Scope:** repo (`/Users/vishnusrikanth/SportsMan-main`) + connected Supabase project (`tseszaprvtvqrkfpditu`). **Nothing was changed.**

> ⚠️ **BLOCKER — plan file missing.** `/docs/ai-layer-plan.md` **does not exist** anywhere in the repo (`docs/` did not exist before this audit). I could not read "sections 0 and 1," so the "AI foundation described in plan section 1" is **unknown**. Section 6 (Gaps) is therefore written against a *standard* AI-foundation baseline (pgvector + embeddings + an AI Edge Function + provider keys), NOT against the real plan. Re-run once the plan exists to align.

> **Access caveats (flagged, not guessed):** I have only the **public anon key**. I can read schema/data via PostgREST and probe Edge Functions, but I **cannot** read `pg_extension`/`pg_policies` directly, **cannot** enumerate configured Edge-Function secrets, and **cannot** read deployed function source that isn't in the repo. Those items are marked **UNKNOWN/UNVERIFIED** below.

---

## 1. Database schema

**Live DB has 11 tables** (verified). Two more — `services`, `availability` — are **defined in a migration but NOT applied** (PostgREST returns HTTP 404 for both); treat them as not-yet-live.

### Role mapping
| Concept | Table(s) |
|---|---|
| Coaches / providers | **`providers`** (business identity; `owner_id` → `profiles.id` = `auth.uid()`) + `profiles` (per-user identity/role) |
| Listings / services | **`programs`** (the live offering/listing). `services` is defined but **not applied**. |
| Bookings | **`bookings`** |
| Reviews | **NONE** — there is **no reviews table**. Only aggregate columns `programs.average_rating` + `programs.total_reviews`. Individual reviews are not stored. |
| Messages | **`messages`** (+ `conversations` threads) |
| **session_notes** | **DOES NOT EXIST.** |
| **Embeddings** | **NONE.** No `vector` columns, no embeddings table, no embedding usage anywhere in migrations. |

### Tables & columns
- **profiles** — id (uuid pk = auth.users.id), role, first_name, last_name, email, phone_number, preferred_sports text[], profile_image, created_at.
- **providers** — id (uuid pk), owner_id→profiles, business_name, bio, sports text[], location, latitude, longitude, status, onboarding_completed, verification_status, stripe_account_id, stripe_charges_enabled, created_at; `unique(owner_id)`.
- **programs** — id, provider_id→providers, title, description, sport_type, skill_level, age_group, language, cover_image, gallery text[], whats_included text[], price numeric(10,2), currency, pricing_model, max_capacity, enrolled_count, latitude, longitude, address_line1, city, state, zip, country, cancellation_policy, minimum_age, maximum_age, is_featured, status, average_rating, total_reviews, created_at.
- **sessions** — id, program_id→programs, title, start_date, end_date, start_time (text), end_time (text), timezone, address, capacity, created_at.
- **athletes** (MINORS) — id, parent_id→profiles, first_name, last_name, date_of_birth, gender, preferred_sports text[], medical_conditions, emergency_contact jsonb, profile_image, created_at, parent_consent, consent_at, consent_version.
- **bookings** — id, searcher_id→profiles, session_id→sessions (nullable, SET NULL), athlete_id→athletes, program_id→programs, athlete_first_name, athlete_age_band, selected_tier, original_price, final_price, currency, status, payment_status, created_at, stripe_checkout_session_id.
- **conversations** — id, searcher_id→profiles, provider_id→profiles, program_id→programs, last_message, last_message_at, created_at.
- **messages** — id, conversation_id→conversations, sender_id→profiles, body, created_at.
- **notifications** — id, user_id→profiles, title, message, read, created_at.
- **teams** — id, provider_id→providers, name, sport, created_at.
- **team_athletes** — id, team_id→teams, athlete_id→athletes, jersey_number, is_available, is_paid, created_at; `unique(team_id, athlete_id)`.
- *(defined, NOT applied)* **services**, **availability** — provider-owned supply tables.

### RLS — the 11 live tables (all have `enable row level security`; 46 policies total)
- **profiles** (3): select/insert/update own row only (`id = auth.uid()`); no delete (dies with auth user).
- **providers** (5): public select where `status='approved'` (anon+auth); owner select/insert/update/delete (`owner_id = auth.uid()`).
- **programs** (5): public select where `status='published'`; owning-provider full CRUD via `exists(providers where id=provider_id and owner_id=auth.uid())`.
- **sessions** (5): public select when parent program published; owning-provider full CRUD via program→provider join.
- **athletes** (4): owning **parent only**, all ops (`parent_id = auth.uid()`). No provider/public access.
- **bookings** (6): searcher CRUD own (`searcher_id=auth.uid()`); provider of the session may select + update via session→program→provider join (a trigger pins provider updates to `status` only).
- **conversations** (3): participants only (`auth.uid() in (searcher_id, provider_id)`) for select/insert/update.
- **messages** (2): participants select; insert requires `sender_id=auth.uid()` + participant. Immutable (no update/delete).
- **notifications** (3): recipient select/update/delete (`user_id=auth.uid()`); no client insert (server-side only).
- **teams** (5): owning-provider CRUD; parent may select teams their athlete is in.
- **team_athletes** (5): owning-provider CRUD; parent may select rows for own athlete.

Hardening present: `handle_new_user()` (auto-creates profile on signup), `enforce_booking_provider_update()` (locks provider edits to status), `rls_auto_enable` event trigger (auto-enables RLS on any new public table). All SECURITY DEFINER fns are `search_path`-pinned with EXECUTE revoked from client roles.

---

## 2. pgvector
- **No usage** in any migration (no `create extension … vector`, no `vector` columns, no embeddings).
- Extension enabled state is **UNVERIFIED** (cannot read `pg_extension` with the anon key).
- **Treat as a GAP:** assume **NOT enabled** until confirmed; it must be enabled before any embeddings work.

---

## 3. Edge Functions
**In repo:** only `supabase/functions/stripe-connect-onboarding/index.ts` (a reviewed copy).
**Deployed (probed live):**
- `stripe-connect-onboarding` → HTTP 200 (working).
- `stripe-create-checkout` → deployed (HTTP 400 on empty body = needs params).
- `stripe-webhook` → deployed (HTTP 400 on empty body).
- Source for the latter two is **not in the repo** → internals **UNKNOWN** (not modified, not readable here).

### Shared / reference pattern (from `stripe-connect-onboarding`)
- **Runtime:** `Deno.serve(async (req) => …)`, `npm:` imports (`stripe`, `@supabase/supabase-js`).
- **CORS:** shared `cors` map; `OPTIONS` short-circuits to `"ok"`.
- **Response shape:** `json(body, status)` helper → `Response(JSON.stringify(body), {headers:{...cors,'Content-Type':'application/json'}})`. Success returns a plain data object; failures return `{ error: <message> }` with an HTTP status (400/401/404/500).
- **Auth handling:** read `Authorization` header → **user-scoped client** (`createClient(URL, ANON_KEY, {global:{headers:{Authorization}}})`) → `auth.getUser()` to identify the caller (401 if missing/invalid).
- **Privileged writes:** a separate **service-role client** (`createClient(URL, SERVICE_ROLE, {auth:{persistSession:false}})`) that bypasses RLS — used only server-side for write-backs.
- **Secrets:** read via `Deno.env.get('NAME')` (`STRIPE_SECRET_KEY`, plus auto-injected `SUPABASE_URL` / `SUPABASE_SERVICE_ROLE_KEY` / `SUPABASE_ANON_KEY`).
- **Error handling:** top-level `try/catch` → `console.error(...)` + `json({error}, 500)`; per-step guards return early with the PostgREST/Stripe error message.
- **This is the template to copy for an AI Edge Function** (auth → optional service-role → call provider with a `Deno.env` key → typed JSON response). **Do not modify the Stripe functions.**

---

## 4. Secrets / env vars (NAMES only — values never read)
- **Edge-Function env referenced in code:** `STRIPE_SECRET_KEY`, `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, `SUPABASE_ANON_KEY`. (`stripe-webhook` almost certainly also needs `STRIPE_WEBHOOK_SECRET` — **inferred, UNVERIFIED**.)
- **Client config (`env.json`, gitignored):** `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `HCAPTCHA_SITE_KEY`.
- **`ANTHROPIC_API_KEY`:** **NOT present** anywhere in the repo/env (no reference in code). Whether it's set as a deployed Edge-Function secret is **UNKNOWN** (cannot enumerate) — but nothing consumes it → effectively **MISSING**.
- **Embeddings key** (OpenAI / Voyage / Cohere / etc.): **NOT present** anywhere → **MISSING**.

---

## 5. Flutter app
- **State management:** **Provider / ChangeNotifier only** (sole system). GetX used **only** for routing/snackbars/storage. **0** reactive-GetX usages (no `.obs`/`Obx`/`GetxController`/`GetBuilder`). Providers registered in `lib/main.dart`: Onboarding, Home, ProviderController, Auth, Chat (+ `AuthService` as a value).
- **Data layer pattern:** `AppRepository` interface (`lib/core/data/app_repository.dart`, split into Program/Booking/Profile/Athlete/Conversation/Team/Notification repos) → implemented by `SupabaseRepository` (bound in `lib/main.dart`; `MockRepository` is the rollback). Widgets → ChangeNotifier controllers → repository. Map shapes are camelCase UI ↔ snake_case DB.
- **Edge-Function call pattern:** `Supabase.instance.client.functions.invoke('<name>', body: {...})`, read `res.data` (Map), handle `FunctionException`. Call sites today: `provider_dashboard_screen.dart` (stripe-connect-onboarding ×2), `booking_flow_screen.dart` (stripe checkout). ⚠️ **Note:** these invoke calls live **directly in screens**, *not* behind the repository — an AI feature should ideally add a repository method for consistency.
- **Provider profile screens:** `lib/presentation/provider/view/` → `provider_profile_screen.dart`, `provider_edit_profile_screen.dart`, `service_profile_screen.dart`, `personal_profile_screen.dart`.
- **Onboarding screens:** `lib/presentation/onboarding/` → identity / mission / selection / sports / provider_activation / provider_capacity / provider_identity / provider_media / provider_pricing / provider_sports / provider_tutorial / almost_done (+ `controllers/onboarding_controller.dart`).

---

## 6. Gaps to build the AI foundation
*(Against a standard AI baseline — the real plan section 1 is unavailable; see top blocker.)*
- **No `/docs/ai-layer-plan.md`** — the source of truth for required scope is missing; everything below is provisional.
- **pgvector not enabled** (no extension/usage) — required before embeddings.
- **No embeddings storage** — no `vector` columns or embeddings table on coaches/listings/etc.; needs schema + an embedding-generation path, all behind RLS.
- **No `session_notes` table** — does not exist; needed if the AI summarizes/reads sessions.
- **No reviews table** — only aggregate rating columns on `programs`; per-review text isn't stored, limiting review-grounded AI.
- **`ANTHROPIC_API_KEY` not configured / not consumed** — no Claude provider wired.
- **No embeddings-provider key** configured.
- **No AI Edge Function** — only Stripe functions exist; an AI function should be added following the Stripe reference pattern (auth → service-role as needed → `Deno.env` key → JSON).
- **No Flutter AI service/repository method** — no `functions.invoke` for an AI endpoint; should be added as a repository method (current invoke calls bypass the repo).
- **`services` / `availability` defined but not applied** to the live DB (404) — relevant if AI reasons over supply/availability.
- **Verification gaps to close with elevated access:** confirm pgvector state, enumerate Edge-Function secrets, and read `stripe-create-checkout` / `stripe-webhook` source.
