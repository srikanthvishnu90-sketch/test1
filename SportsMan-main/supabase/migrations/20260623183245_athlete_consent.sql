-- ============================================================================
-- Athletes: parental-consent columns (COPPA). Apply before shipping the
-- add-a-child flow. Idempotent.
-- ============================================================================
-- parent_consent: parent/guardian explicitly consented to storing the child's
-- data (un-prechecked gate in the UI). consent_at: UTC timestamp of consent.
-- consent_version: which consent text version was shown (currently 'v1').
-- ============================================================================
alter table public.athletes
  add column if not exists parent_consent  boolean not null default false,
  add column if not exists consent_at       timestamptz,
  add column if not exists consent_version  text;
