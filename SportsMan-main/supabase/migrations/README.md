# Supabase migrations

## Baseline is authoritative as of 2026-06-23

[`20260623_000000_baseline.sql`](20260623_000000_baseline.sql) is the **single
forward source of truth** for the database schema. It reproduces the current live
Supabase schema exactly — 11 public tables, 46 RLS policies, the hardened
`handle_new_user` / `enforce_booking_provider_update` functions + triggers, the
`rls_auto_enable` event trigger, and the PostgREST grants — and is idempotent
(create-if-not-exists, drop+create policies, create-or-replace functions).

The live database already matches this baseline, so **do not run it against
production**. Use it to reconstruct the schema from source on a fresh/local
Supabase project, and as the reference that stops schema drift.

### How the baseline was assembled

It consolidates the partial migrations that originally built the live DB (now in
[`_archive/`](_archive/)):

| Archived file | Folded into baseline as |
|---|---|
| `20260621164604_init.sql` | tables, indexes, RLS enable, all 46 policies, grants |
| `20260621193131_handle_new_user.sql` | `handle_new_user()` + `on_auth_user_created` (hardened: `search_path=''`, EXECUTE revoked) |
| `20260621231106_add_provider_stripe_charges.sql` | `providers.stripe_charges_enabled` |
| `20260621234116_add_booking_stripe_checkout.sql` | `bookings.stripe_checkout_session_id` |
| `20260623183245_athlete_consent.sql` | `athletes.parent_consent` / `consent_at` / `consent_version` |
| `20260622135352_team_athlete_name_DRAFT.sql` | **NOT folded in** — draft, never applied; `team_athletes.athlete_first_name` is not in the live schema |

### Notes / open verification

- `bookings.session_id` is **NULLABLE** with `ON DELETE SET NULL` in the baseline
  (the original init had it `NOT NULL` / `ON DELETE CASCADE`; the live table was
  tightened to survive session deletion).
- `rls_auto_enable()` (event trigger) is marked `// VERIFY` in the baseline — it
  is reconstructed from the schema spec because no archived migration contains its
  source. Confirm its exact live body before relying on the baseline for it.

### Archive

`_archive/` keeps the original migration files for history. They are **not**
applied anymore and are not deleted — the baseline supersedes them.
