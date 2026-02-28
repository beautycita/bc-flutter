-- Add breaks JSONB column to staff_schedules for per-employee break windows
-- Stores array of {start: "HH:MM", end: "HH:MM"} objects per day
alter table public.staff_schedules
  add column if not exists breaks jsonb not null default '[]'::jsonb;

comment on column public.staff_schedules.breaks is
  'Array of break windows [{start:"HH:MM",end:"HH:MM"}] for this day.';
