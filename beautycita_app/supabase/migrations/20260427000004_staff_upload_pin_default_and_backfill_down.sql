-- Reverse 20260427000004. Backfilled PINs cannot be unset without losing
-- whatever stylists have already memorized; only drop the default.

ALTER TABLE public.staff
  ALTER COLUMN upload_pin DROP DEFAULT;
