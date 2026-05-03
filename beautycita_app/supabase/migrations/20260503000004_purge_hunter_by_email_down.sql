-- Reverse 20260503000004 — drop the email-based + orphan-sweep version.
-- Re-replay 20260503000003 if you need the previous version restored.
DROP FUNCTION IF EXISTS public.purge_hunter_test_residue();
