# Sporve — AI Stage-2 Audit (read-only)

**Date:** 2026-06-28 · **Scope:** repo (`/Users/vishnusrikanth/SportsMan-main`) — migrations, Edge Functions, Flutter `lib/`. **Nothing was changed.** This audit answers the five Stage-2 questions (Bookings, Messaging, Scheduling, Tone source, Flutter) ahead of P3/P4 work.

> ⚠️ **BLOCKER — plan file still missing.** `/docs/ai-layer-plan.md` **does not exist** anywhere in the repo (searched: `find`/`grep` over the tree). The requested sections **2 (P3, P4)** and **0.4 (deterministic-trigger vs AI-content split)** could not be read. This audit is grounded in `/docs/ai-foundation-audit.md` (2026-06-27) + the live code instead. **The deterministic-vs-AI split named in the prompt is therefore UNVERIFIED against any plan** — re-run once the plan exists.

> **Method caveat:** this pass reads the **repo only** (no live DB / no Edge-Function secrets). Anything that depends on the running database (e.g. is an extension actually installed, what the deployed `stripe-webhook` body does) is flagged **UNKNOWN/UNVERIFIED**. The repo is the source of truth for what *code* exists; the live project may differ.

> **Drift note vs foundation audit:** since the 2026-06-27 foundation audit, the repo gained four migrations (`program_embeddings`, `ai_audit_log`, `session_notes_parent_updates`, `services_availability`) and several Edge Functions (`ai-gateway`, `ai-chat`, `generate-embedding`, `backfill-embeddings`, `provider-onboard-draft`, `session-note-summarize`, `parent-update-send`). Findings below reflect the **current** repo, not that earlier snapshot.

---

## 1. Bookings — status values & transitions

### Status domain (authoritative, from the CHECK constraints)
Defined in [supabase/migrations/20260623_000000_baseline.sql:160-163](../supabase/migrations/20260623_000000_baseline.sql#L160-L163):

```sql
status         text not null default 'pending'
               check (status in ('pending','confirmed','declined','completed')),
payment_status text not null default 'unpaid'
               check (payment_status in ('unpaid','paid','refunded','failed')),
```

- **`status` ∈ { `pending`, `confirmed`, `declined`, `completed` }** — default `pending`.
- **`payment_status` ∈ { `unpaid`, `paid`, `refunded`, `failed` }** — default `unpaid`.
- ⚠️ **There is NO `no-show` and NO `cancelled` status.** The prompt asks "how does a booking become … no-show?" — **answer: it cannot.** Those values are outside the CHECK domain and would be rejected. If Stage-2 needs no-show / cancellation, the constraint must be widened first. **Flagged as a gap.**

### Transitions that actually exist in the repo

| Transition | Where it is triggered (code) | Status |
|---|---|---|
| (none) → `pending` | **Client insert.** `SupabaseRepository.addBooking()` hard-codes `'status': 'pending'` at [lib/core/data/supabase_repository.dart:336](../lib/core/data/supabase_repository.dart#L336). This is the **only** booking-status write anywhere in the app code. | ✅ exists |
| `pending` → `confirmed` | **No code in repo.** | ❌ **MISSING / UNKNOWN** |
| `pending`/`confirmed` → `declined` | **No code in repo.** | ❌ **MISSING / UNKNOWN** |
| `confirmed` → `completed` | **No code in repo.** | ❌ **MISSING / UNKNOWN** |
| `unpaid` → `paid` / `refunded` / `failed` | Presumed Stripe-driven; see below. | ⚠️ **UNVERIFIED** |

**The booking lifecycle past `pending` is not implemented in the repo.** Concrete evidence:

- `BookingRepository` ([lib/core/data/app_repository.dart:23-29](../lib/core/data/app_repository.dart#L23-L29)) exposes only `getBookings()`, `saveBookings()`, `addBooking()` — **there is no `updateBookingStatus` / `confirmBooking` / `declineBooking` method.**
- `SupabaseRepository.saveBookings()` is an **explicit no-op** with a comment deferring it: [lib/core/data/supabase_repository.dart:272-275](../lib/core/data/supabase_repository.dart#L272-L275) — *"Intentionally a no-op (status changes are #20)."* So status changes are a known, deferred item (#20).
- The provider schedule UI **reads** `session.isConfirmed` / `session.isCompleted` ([lib/presentation/provider/view/provider_schedule_screen.dart:103-104](../lib/presentation/provider/view/provider_schedule_screen.dart#L103-L104), [:680](../lib/presentation/provider/view/provider_schedule_screen.dart#L680)) but those booleans come from the in-memory `Session` model on `ProviderController` ([lib/presentation/provider/controllers/provider_controller.dart:226-228](../lib/presentation/provider/controllers/provider_controller.dart#L226-L228)), **not** from a DB status write. The provider has no path to actually persist a confirm/decline/complete.

### Server-side enforcement that DOES exist
- **DB trigger `enforce_booking_provider_update()`** ([supabase/migrations/20260623_000000_baseline.sql:664-695](../supabase/migrations/20260623_000000_baseline.sql#L664-L695)) — when a **provider** (not the searcher who owns the booking) updates a booking row, it may change **`status` only**; any other column change raises `Provider may only update booking status`. So the DB is *ready* for provider status transitions even though no app code issues them.
- **RLS** ([:423-454](../supabase/migrations/20260623_000000_baseline.sql#L423-L454)): searcher has full CRUD on own bookings; the owning provider (via `session → program → provider` join) gets SELECT + UPDATE. The plumbing for a provider confirm/decline exists at the DB layer; the **client call to use it does not**.

### Stripe / payment transitions
- The repo contains **only** `supabase/functions/stripe-connect-onboarding/`. **`stripe-webhook` and `stripe-create-checkout` are NOT in the repo** (the Flutter app invokes `stripe-create-checkout` from [lib/presentation/client/view/booking_flow_screen.dart:482](../lib/presentation/client/view/booking_flow_screen.dart#L482), proving it's *deployed*, but its source is absent).
- Therefore **how `payment_status` flips to `paid`/`refunded`, and whether the webhook also flips `status` to `confirmed`, is UNKNOWN** (cannot read the deployed function source here). This is the most likely real home of the `pending → confirmed` transition, but it is **unverifiable from the repo**.

**Stage-2 implication:** booking-state changes (confirm/decline/complete/no-show) are the deterministic triggers an AI layer would react to, yet today only `pending` is ever written in-repo. Either (a) the missing `stripe-webhook` drives it server-side, or (b) #20 is genuinely unbuilt. **This must be resolved with live access before wiring AI off booking transitions.**

---

## 2. Messaging — schema, send path, guardian↔child link

### Schema (baseline migration)
**`conversations`** ([supabase/migrations/20260623_000000_baseline.sql:168-178](../supabase/migrations/20260623_000000_baseline.sql#L168-L178)):
`id` (uuid pk) · `searcher_id` → profiles (cascade) · `provider_id` → profiles (cascade) · `program_id` → programs (set null) · `last_message` (text) · `last_message_at` (timestamptz) · `created_at` · CHECK `searcher_id <> provider_id`.

**`messages`** ([:180-187](../supabase/migrations/20260623_000000_baseline.sql#L180-L187)):
`id` (uuid pk) · `conversation_id` → conversations (cascade) · `sender_id` → profiles (cascade) · `body` (text not null) · `created_at`. **Immutable** — RLS allows participant SELECT + sender INSERT only, no UPDATE/DELETE ([:468-481](../supabase/migrations/20260623_000000_baseline.sql#L468-L481)).

### How a message is sent today — **it is NOT persisted server-side**
- The send path is `ChatProvider.sendMessage()` ([lib/presentation/shared/controllers/chat_provider.dart:95-129](../lib/presentation/shared/controllers/chat_provider.dart#L95-L129)) → `_repo.saveMessages(conversationId, _messages)`.
- But `SupabaseRepository.saveMessages()` is an **empty no-op**: [lib/core/data/supabase_repository.dart:693](../lib/core/data/supabase_repository.dart#L693) — `Future<void> saveMessages(...) async {}`. So **outgoing chat messages are currently held in local memory (optimistic UI) and never written to the `messages` table.**
- **There is no `send-message` Edge Function**, and no client `from('messages').insert(...)`. The schema + RLS exist, but the write path is unbuilt.
- **Notification channel:** the `notifications` table ([:189-197](../supabase/migrations/20260623_000000_baseline.sql#L189-L197)) has **no client-insert policy** and **no DB trigger fires a notification when a message is created.** The *only* code that inserts notifications is the `parent-update-send` Edge Function ([supabase/functions/parent-update-send/index.ts:100](../supabase/functions/parent-update-send/index.ts#L100), service-role insert). So chat has no notification fan-out today.

⚠️ **Gap:** Stage-2 messaging (and any AI-drafted message delivery) needs a real message-write path — most cleanly a server function that inserts into `messages` + `notifications` under service role, mirroring `parent-update-send`.

### Guardian ↔ child link (COPPA — reuse this)
- **`athletes.parent_id`** → `profiles` (ON DELETE CASCADE) is the single guardian link ([supabase/migrations/20260623_000000_baseline.sql:128](../supabase/migrations/20260623_000000_baseline.sql#L128)). One parent per athlete (no multi-guardian table). ⚠️ If multiple guardians per child is ever required, that's a schema gap.
- **Consent columns on `athletes`:** `parent_consent` (bool, default false), `consent_at`, `consent_version` ([:138-140](../supabase/migrations/20260623_000000_baseline.sql#L138-L140)).
- **Isolation:** `athletes` RLS is **parent-only** — owning parent (`parent_id = auth.uid()`) for all ops; **zero provider/public read** ([:409-421](../supabase/migrations/20260623_000000_baseline.sql#L409-L421)). Providers only ever see the denormalized `athlete_first_name` + `athlete_age_band` carried on the `bookings` row.
- **This is the relationship Stage-2 must reuse to fan out to guardians.** It is exactly how `parent-update-send` resolves recipients: it reads `athletes.parent_id` for the update's `child_id` and notifies that profile ([supabase/functions/parent-update-send/index.ts:14](../supabase/functions/parent-update-send/index.ts#L14), [:84-100](../supabase/functions/parent-update-send/index.ts#L84-L100)).

---

## 3. Scheduling — pg_cron & scheduled functions

- **pg_cron is NOT enabled in the repo.** The only `create extension` statements are `pgcrypto` ([supabase/migrations/20260623_000000_baseline.sql:31](../supabase/migrations/20260623_000000_baseline.sql#L31)) and `vector` ([supabase/migrations/20260627_000000_program_embeddings.sql:26](../supabase/migrations/20260627_000000_program_embeddings.sql#L26)). No `create extension … pg_cron`, no `cron.schedule(...)` anywhere in `supabase/migrations/`.
- **No scheduled Edge Functions / cron jobs exist.** All eight functions (`ai-chat`, `ai-gateway`, `backfill-embeddings`, `generate-embedding`, `parent-update-send`, `provider-onboard-draft`, `session-note-summarize`, `stripe-connect-onboarding`) are request-triggered (`Deno.serve`); none is wired to a schedule.
- ⚠️ **Whether pg_cron is enabled on the live Supabase project is UNKNOWN** (cannot read `pg_extension` from the repo). Treat as **not enabled until confirmed**.
- **GAP to enable:** any Stage-2 feature needing time-based work (e.g. nudge a coach who hasn't sent an update, batch digests, re-embedding sweeps) has **no scheduler today**. Enabling `pg_cron` (or Supabase scheduled functions) is a prerequisite and should be added as an explicit migration + a thin scheduled invoker.

---

## 4. Tone source — approved coach writing for anchoring

**Confirmed: `parent_updates` exists and is a clean source of the coach's APPROVED writing.**

`parent_updates` ([supabase/migrations/20260629_000000_session_notes_parent_updates.sql:36-54](../supabase/migrations/20260629_000000_session_notes_parent_updates.sql#L36-L54)) carries the coach-authored, human-approved content:
- Content fields: `summary_body`, `skills_worked text[]`, `progress_signal`, `practice_suggestions text[]`, `encouragement`.
- Lifecycle: **`status` ∈ { `draft`, `approved`, `sent` }** ([:48](../supabase/migrations/20260629_000000_session_notes_parent_updates.sql#L48)) + `approved_by`, `approved_at`, `sent_at`, `delivery_channel`.
- **`status='approved'` and `status='sent'` rows are records of writing the coach explicitly signed off on** → ideal tone anchors. `status='sent'` is additionally visible to the guardian (RLS [:121-126](../supabase/migrations/20260629_000000_session_notes_parent_updates.sql#L121-L126)), so it's the safest "definitely went out in the coach's voice" set.
- `session_notes.raw_notes` ([:22-29](../supabase/migrations/20260629_000000_session_notes_parent_updates.sql#L22-L29)) is the coach's *unprocessed* input — useful as raw voice but **not** "approved."

**Wiring already half-present:** `session-note-summarize` already accepts tone inputs — `lastUpdateSummary` and `coachStyleSamples[]` — used for **voice continuity only, never as a fact source** (the guardrail forbids inventing content). ⚠️ **Gap:** nothing currently *auto-loads* prior approved/sent `parent_updates` into those parameters; the app must pass them. A Stage-2 helper that fetches the last N `status in ('approved','sent')` rows for a provider and feeds them as `coachStyleSamples` is the natural next step.

**Sent-message history as a tone source: NOT usable today.** Per §2, chat messages are never persisted (`saveMessages` no-op), so there is **no stored coach chat history** to anchor on. The only durable approved-writing corpus is `parent_updates`.

---

## 5. Flutter — inbox/thread UI, coach settings, Edge-Function service pattern

### Inbox / thread UI
| Screen | File |
|---|---|
| Client inbox (conversation list) | [lib/presentation/client/view/messages_screen.dart](../lib/presentation/client/view/messages_screen.dart) |
| Client message thread | [lib/presentation/client/view/chat_details_screen.dart](../lib/presentation/client/view/chat_details_screen.dart) |
| Provider chat list | [lib/presentation/provider/view/provider_chat_screen.dart](../lib/presentation/provider/view/provider_chat_screen.dart) |
| Driver (ChangeNotifier) | [lib/presentation/shared/controllers/chat_provider.dart](../lib/presentation/shared/controllers/chat_provider.dart) — registered in [lib/main.dart](../lib/main.dart) |

`ChatProvider` loads via `_repo.getConversations()` / `_repo.getMessages()` and "sends" via `_repo.saveMessages()` (the no-op — see §2). All chat I/O goes through `AppRepository`, not inline Supabase calls.

### Coach (provider) settings screens
Under `lib/presentation/provider/view/`: `provider_profile_screen.dart` (settings hub), `provider_edit_profile_screen.dart`, `service_profile_screen.dart`, `personal_profile_screen.dart`, plus `provider_roster_screen.dart`, `provider_finances_screen.dart`, `provider_payouts_payments_screen.dart`; shared `lib/presentation/shared/notification_settings_screen.dart`.
- **Natural home for a coach-facing AI toggle** (e.g. "AI-drafted parent updates / tone"): `service_profile_screen.dart` (owns business/voice settings) or `notification_settings_screen.dart` (if it governs *delivery*). ⚠️ **No AI settings screen exists yet.**
- Note: `provider_profile_screen.dart:273-343` already renders an **"AI Coach" card whose button is a mock snackbar** — placeholder, not wired to `ai-chat`/`ai-gateway` yet. (See §6 — flagged for "glow" cleanup.)

### Edge-Function service-layer pattern
**Canonical call:** `Supabase.instance.client.functions.invoke('<name>', body: {...snake_case...})` → read `(res.data as Map)` → branch on `data['error']` → catch `FunctionException` (read `e.details['error']`).

| Function | Call site | Behind repository? |
|---|---|---|
| `session-note-summarize` | [lib/core/data/supabase_repository.dart:381](../lib/core/data/supabase_repository.dart#L381) (`summarizeSessionNote()`) | ✅ **Yes** — only one wrapped in the repo |
| `backfill-embeddings` | [lib/presentation/provider/controllers/provider_controller.dart:341](../lib/presentation/provider/controllers/provider_controller.dart#L341) | ❌ inline (fire-and-forget) |
| `stripe-connect-onboarding` | [lib/presentation/provider/view/provider_dashboard_screen.dart:54](../lib/presentation/provider/view/provider_dashboard_screen.dart#L54), [:83](../lib/presentation/provider/view/provider_dashboard_screen.dart#L83) | ❌ inline in screen |
| `stripe-create-checkout` | [lib/presentation/client/view/booking_flow_screen.dart:482](../lib/presentation/client/view/booking_flow_screen.dart#L482) | ❌ inline in screen |
| `provider-onboard-draft` | [lib/presentation/onboarding/controllers/onboard_draft_controller.dart:65](../lib/presentation/onboarding/controllers/onboard_draft_controller.dart#L65) | ❌ inline in controller |

⚠️ **Inconsistency:** only `session-note-summarize` is behind the repository; the rest invoke inline. The foundation audit + CLAUDE.md both prefer routing AI calls through a repository method. **Stage-2 should add new AI Edge-Function calls as repository methods** (following `summarizeSessionNote`), not inline in screens.

### Existing AI Flutter surface (Stage-1, present)
- Parent-update flow: `parent_update_controller.dart` (stages: input → clarifying → draft → approved → sent) + `parent_update_screen.dart`.
- Repository AI methods: `createSessionNote`, `summarizeSessionNote`, `upsertParentUpdateDraft`, `approveParentUpdate`, `sendParentUpdate`, `getParentUpdatesForChild` ([lib/core/data/app_repository.dart:77-104](../lib/core/data/app_repository.dart#L77-L104)).
- Onboarding AI draft: `onboard_draft_controller.dart`. Embedding refresh on provider save: `provider_controller.dart:341`.
- ✅ All AI goes through Edge Functions; **no direct Anthropic/model calls in Flutter** (matches CLAUDE.md "AI access" rule).

---

## Explicit unknowns / gaps (consolidated)

1. **`/docs/ai-layer-plan.md` missing** — P3/P4 and the §0.4 deterministic-vs-AI split could not be read; the prompt's framing is unverified against any plan.
2. **Booking transitions past `pending` are not in the repo** — no `updateBookingStatus` method; `saveBookings` is a deferred no-op (#20). Confirm/decline/complete have no client path.
3. **`no-show` and `cancelled` are not valid booking statuses** — CHECK domain is only `pending|confirmed|declined|completed`.
4. **`stripe-webhook` / `stripe-create-checkout` source absent from repo** — payment→status flips are UNKNOWN/UNVERIFIED.
5. **Chat messages are never persisted** — `saveMessages` is a no-op; no `send-message` function; no message→notification trigger.
6. **Single guardian per child only** (`athletes.parent_id`) — no multi-guardian support.
7. **pg_cron not enabled in repo; no scheduled jobs** — and unverifiable on the live project. Required for any time-based Stage-2 feature.
8. **Tone anchors not auto-loaded** — `parent_updates` (approved/sent) is the corpus, but nothing feeds it into `session-note-summarize` automatically; no chat-history corpus exists.
9. **AI Edge-Function calls are inconsistently placed** — only one behind the repository; the rest inline.
10. **Live-project state generally UNVERIFIED** — extensions installed, deployed function bodies, and Edge-Function secrets cannot be read from the repo.
