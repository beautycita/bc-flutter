-- Reverse 20260503000003 — restore the original cleanup order (appointments
-- first, dependents missing). NOTE: this re-introduces the FK violation;
-- only run if you intend to revert and rebuild.
-- For brevity, the down migration drops the function entirely; the previous
-- version was applied via 20260427000006 and would need to be reapplied by
-- replaying that migration if needed.

DROP FUNCTION IF EXISTS public.purge_hunter_test_residue();
