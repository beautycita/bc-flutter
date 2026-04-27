-- staff.upload_pin had no default, so any row inserted before the column
-- was wired up (or via a code path that didn't set it) ended up with a
-- NULL PIN. The business panel UI shows '----' when NULL, and the
-- portfolio-upload page rejects every PIN attempt because the staff row
-- it pulls back has upload_pin=NULL and the equality check fails.
--
-- Fix:
--   1. Give the column a default that generates a 4-digit string per row.
--   2. Backfill every NULL/empty existing row with a fresh random PIN so
--      stylists can use the QR + PIN flow without an admin tap.
--
-- Random PINs collide in theory (1 in 9000), but PINs are scoped per
-- staff_id (lookup is by upload_qr_token AND upload_pin) so cross-staff
-- collision is harmless. The owner can still rotate any individual PIN
-- from the staff detail sheet.

ALTER TABLE public.staff
  ALTER COLUMN upload_pin
  SET DEFAULT lpad(((random() * 9000)::int + 1000)::text, 4, '0');

UPDATE public.staff
   SET upload_pin = lpad(((random() * 9000)::int + 1000)::text, 4, '0')
 WHERE upload_pin IS NULL
    OR upload_pin = '';
