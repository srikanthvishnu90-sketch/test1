# Sporve — project conventions

AI-native youth-sports training & marketplace (Flutter). Two audiences share one
codebase: **clients** (athletes/families) and **providers** (coaches/academies).
Demo runs on mock data (`lib/core/mock/mock_data.dart`, via GetStorage).

## State management (official convention — decided #15)
- **Provider / ChangeNotifier is the ONLY state-management system.** All new
  reactive / business state goes in a `ChangeNotifier` provider registered in
  `lib/main.dart`.
- **GetX is a UTILITY layer only** — routing (`Get.toNamed` / `Get.off*` /
  `Get.back`), snackbars (`Get.snackbar`), and `GetStorage` persistence. Do NOT
  introduce `GetxController`, `.obs`, `Obx`, or `GetBuilder`. No reactive state
  in GetX. (Verified: the app currently has 0 reactive-GetX usages — keep it 0.)
- **`MultiProvider` wraps `GetMaterialApp`** (`lib/main.dart` → `lib/app.dart`),
  so any GetX route can reach providers via `context.read` / `context.watch`.
  Preserve that nesting.

## Design system (slate)
- Black / white / **slate `#536878`** is the whole UI. Slate is the single accent
  for ALL chrome (nav, tabs, toggles, calendar selection, links, search, AI).
- The ONLY chromatic colors are per-**sport** identity colors (`SportColors`),
  used accent-only: sport tag, icon-tile glyph, the in-context action button,
  sport status pill, calendar session dots. Never on chrome, max one per card.
- **Red `#EF4444` is DESTRUCTIVE ONLY** (Sign out, delete, cancel). Non-destructive
  "negative" states use muted `#647079`. No aqua / AI-blue / amber anywhere.
- Tokens live in `lib/core/theme/app_colors.dart` (+ `sport_colors.dart`); never
  hardcode hex outside the theme files.
- **Typography:** serif **headers** (Fraunces, ≥18px) + sans **body/labels/numbers**
  (Geist). All styles go through `lib/core/theme/app_typography.dart`.

## Config (public client keys — #17)
- All PUBLIC client config lives in **`env.json`** (gitignored), surfaced to Dart
  via `lib/core/config/env.dart` (`Env.supabaseUrl` / `Env.supabaseAnonKey` /
  `Env.hcaptchaSiteKey`, each a `String.fromEnvironment`). Commit
  `env.example.json` (placeholders) so others can copy it to `env.json`.
- Run / build with the env file:
  ```
  flutter run -d chrome --dart-define-from-file=env.json
  flutter build web --release --dart-define-from-file=env.json
  ```
- `SUPABASE_ANON_KEY` is the publishable/anon **client** key — public-safe; RLS
  protects the data. The hCaptcha **secret** lives ONLY in Supabase Attack
  Protection, and `service_role` is server-only — those (plus Stripe/Resend
  secrets) NEVER go in `env.json`.

## AI access (mandatory)
- **All AI features MUST call through the `ai-gateway` Edge Function.** No feature
  may hit the Anthropic Messages API (or any model API) directly — model routing,
  prompt caching, the per-call `max_tokens` ceiling, cost/latency capture, and the
  one-row-per-call `ai_audit_log` write all live in the gateway. New AI work calls
  `runAI({ task, system, messages, tools?, actorId, actorRole, feature })` and lets
  the gateway pick the model by `task`.
- **Never expose raw model access to the client.** `ANTHROPIC_API_KEY` (and any
  model/provider key) is a server secret that lives only in Edge Function secrets —
  never in `env.json`, Dart, or the web build. The Flutter app reaches AI only via
  `functions.invoke('ai-gateway', …)` (or a feature function that itself calls the
  gateway); it can't escalate the model (Opus is service-role-only).
- Embeddings follow the same rule: generate via `generate-embedding` server-side;
  never ship raw vectors or keys to the client. Never embed price, location,
  availability, certifications, or background-check status (queried deterministically).

## Known cleanups
- ~~Auth state split across `AuthController` + `AuthProvider`~~ — DONE. Auth is
  owned solely by **`AuthProvider`** (backed by `AuthService` → the Supabase
  session). `AuthController` and the mock token are gone; the vestigial repo
  auth methods (`isLoggedIn`/`setLoggedIn`/`getActiveRole`/`setActiveRole`) were
  removed (zero callers). Identity comes from one place — do not reintroduce a
  second auth surface on `AppRepository`.
