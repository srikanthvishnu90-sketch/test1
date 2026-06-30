# Sporve

**AI-native youth-sports training & marketplace** (Flutter). Two audiences share
one codebase:

- **Clients** — athletes & families discovering and booking coaching/programs.
- **Providers** — coaches & academies running listings, schedules, and rosters.

The app pairs a deterministic marketplace (search, booking, payments) with an AI
layer for discovery, ranking, lifecycle messaging, and coach-assist drafting —
all routed server-side through a single gateway, never the model API directly.

---

## Quick start

**Prerequisites**

- Flutter **3.44.2** (stable), Dart SDK `^3.11.5`.
- A `env.json` with public client config (gitignored). Copy the template:

  ```bash
  cp env.example.json env.json
  ```

  `env.json` holds **public-safe** keys only — `SUPABASE_URL`,
  `SUPABASE_ANON_KEY` (the publishable/anon key; RLS protects the data), and the
  hCaptcha **site** key. Server secrets (`service_role`, `ANTHROPIC_API_KEY`,
  Stripe/Resend secrets, the hCaptcha secret) live **only** in Supabase Edge
  Function / Vault config — never here, in Dart, or the web build.

**Run**

```bash
# Against the live Supabase backend (default)
flutter run -d chrome --dart-define-from-file=env.json

# Against in-memory demo data (no backend needed)
flutter run -d chrome --dart-define=USE_MOCK_REPO=true --dart-define-from-file=env.json
```

**Build**

```bash
flutter build web --release --dart-define-from-file=env.json
```

**Test**

```bash
flutter test          # 39 tests
flutter analyze       # must be clean
```

---

## Architecture

**State management** — Provider / `ChangeNotifier` is the **only** reactive state
system. GetX is a **utility layer only** (routing via `Get.toNamed`/`Get.off*`,
snackbars, `GetStorage`). No `GetxController`, `.obs`, `Obx`, or `GetBuilder`.
`MultiProvider` wraps `GetMaterialApp`, so any GetX route reaches providers via
`context.read` / `context.watch`.

**Data** — controllers depend on one `AppRepository` facade. A single switch in
[`lib/main.dart`](lib/main.dart) selects the implementation:

| Mode | Implementation | How |
| --- | --- | --- |
| Live (default) | `SupabaseRepository` | Postgres + RLS + Edge Functions |
| Demo | `MockRepository` | in-memory `MockData` (GetStorage) |

Pass `--dart-define=USE_MOCK_REPO=true` for the demo path. Both satisfy the same
interface, so no screen or controller changes when swapping.

**Auth** — owned solely by `AuthProvider` (backed by `AuthService` → the Supabase
session, kept in sync via the auth stream). Identity comes from one place.

**Design system** — black / white / slate `#536878` for all chrome; per-sport
identity colors used accent-only; red `#EF4444` is destructive-only. Serif
headers (Fraunces ≥18px) + sans body (Geist/Manrope). Tokens live in
`lib/core/theme/` — never hardcode hex outside the theme files.

**AI access (mandatory)** — every AI feature calls through the **`ai-gateway`**
Edge Function, which owns model routing (by task), prompt caching, the per-call
`max_tokens` ceiling, cost/latency capture, and the one-row-per-call audit log.
The client never touches a model API; embeddings are generated server-side via
`generate-embedding`. Price, location, availability, certifications, and
background-check status are queried deterministically — never embedded.

---

## Layout

```
lib/
  main.dart            # providers + repository swap + GetMaterialApp
  app.dart
  core/                # theme, config (env), data (repositories), auth, mock, utils, routes
  presentation/        # authentication, onboarding, client, provider, shared, splash, widgets, bottom_nav
supabase/
  functions/           # Edge Functions (ai-gateway, search-parse, search-execute, message-draft, lifecycle-*, stripe-*, …)
  migrations/          # Postgres schema + RLS
test/                  # widget + unit tests
```

> **Repo layout note:** this project lives in the `SportsMan-main/` subtree of
> its git repository. CI (`.github/workflows/ci.yml`, at the repo root) runs with
> `working-directory: SportsMan-main`.

---

## CI

GitHub Actions runs `flutter analyze` + `flutter test` on every push and PR that
touches the project. Formatting is reported but non-blocking while the
back-catalogue is brought up to `dart format` standard.

---

## Status

Functional prototype with a live Supabase backend deployed. The AI discovery
pipeline (NL query → editable constraint chips → gated, ranked results with a
grounded "why it matched") is wired end-to-end; chat is persisted + realtime;
the booking lifecycle and payments (Stripe Connect) are in place. Remaining work
is the server/dashboard tier — Stripe webhook + real finances, push delivery,
and provider verification.
