-- Listing type (Training | Camp | Clinic | Class | League | AAU | Private
-- Lesson | Tournament). Lets a coach categorize a program; defaults to
-- 'Training' so existing rows stay valid. Safe to re-run.
alter table public.programs
  add column if not exists program_type text not null default 'Training';
