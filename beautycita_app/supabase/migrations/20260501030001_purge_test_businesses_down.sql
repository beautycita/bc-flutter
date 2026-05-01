-- Down migration for the test-business purge.
-- Restores the original purge_hunter_test_residue (without the test-biz
-- sweep) and drops the helper.

DROP FUNCTION IF EXISTS public.purge_test_business(uuid);
-- Note: purge_hunter_test_residue is left in place — re-run the original
-- migration 20260427000006 to restore the prior signature if needed.
