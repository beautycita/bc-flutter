-- Rollback: restore unconditional tax_withholdings insert in
-- create_booking_with_financials. Does NOT recreate the deleted off-network
-- rows (they were stale test data and should stay gone).
-- Restore by running the pre-2026-04-23 RPC body. The safest path is to
-- re-apply a known-good earlier migration that declared the full function.
-- Minimal inline rollback:
CREATE OR REPLACE FUNCTION public.create_booking_with_financials()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  RAISE EXCEPTION 'rollback stub — re-apply the intended prior migration manually';
END;
$$;
-- In practice, rolling back means re-running the newest pre-gate migration
-- which is not a single-file artifact; do not rely on this down script for
-- real rollback. Prefer fixing forward.
