-- =============================================================================
-- Migration: 20260420000004_staff_unique_business_user.sql
-- Description: Prevent duplicate staff rows for the same (business, user) pair.
-- register-business retries (or any client retry of the staff-insert path)
-- would otherwise create N rows for the same person at the same salon, leading
-- to duplicated commission records, schedule blocks, and notifications.
--
-- Partial unique because user_id is nullable (some staff rows are unlinked
-- placeholder profiles created before the stylist signs up).
-- Verified zero current dupes on prod before applying.
-- =============================================================================

CREATE UNIQUE INDEX IF NOT EXISTS staff_business_user_unique
  ON public.staff(business_id, user_id)
  WHERE user_id IS NOT NULL;
