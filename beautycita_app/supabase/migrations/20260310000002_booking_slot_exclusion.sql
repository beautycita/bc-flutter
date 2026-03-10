-- Migration: Prevent double-booking at the database level
--
-- Problem: Two concurrent inserts can book the same staff member for
-- overlapping time slots because find_available_slots only checks at
-- query time — there is no DB-level guard against race conditions.
--
-- Solution: A GiST exclusion constraint that rejects any INSERT or UPDATE
-- that would create overlapping active appointments for the same staff member.
-- Only active bookings are considered (cancelled / no-show rows are ignored).
--
-- Requires PostgreSQL 15+ for the WHERE clause on EXCLUDE constraints.
-- Server runs PostgreSQL 16, so this is safe.

-- 1. Enable btree_gist — needed to combine equality (=) and range (&&)
--    operators in a single GiST exclusion constraint.
create extension if not exists btree_gist;

-- 2. Add the exclusion constraint on active appointments.
--    Two rows conflict when they share the same staff_id AND their
--    [starts_at, ends_at) ranges overlap.
alter table public.appointments
  add constraint appointments_no_double_booking
  exclude using gist (
    staff_id with =,
    tstzrange(starts_at, ends_at) with &&
  )
  where (status not in ('cancelled_customer', 'cancelled_business', 'no_show'));

comment on constraint appointments_no_double_booking on public.appointments is
  'Prevents overlapping active appointments for the same staff member. '
  'Cancelled and no-show appointments are excluded from the check.';
