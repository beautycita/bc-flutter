-- =============================================================================
-- FIX CRITICAL RLS POLICY HOLES: app_config + time_inference_rules
-- Date: 2026-03-10
--
-- PROBLEM:
--   Migration 20260222100000_app_config_and_time_rules_rls.sql created
--   permissive USING(true) policies for authenticated users on both tables:
--
--     1. "app_config: authenticated update"           — any user can flip feature toggles
--     2. "time_inference_rules: authenticated read all" — any user can read engine tuning
--     3. "time_inference_rules: authenticated update"   — any user can modify engine tuning
--
--   Two later migrations attempted to clean these up but used WRONG NAMES:
--
--     - 20260224_admin_rls_policies.sql dropped "app_config_update"
--       (actual name: "app_config: authenticated update")
--
--     - 20260228100000_time_inference_rules_rls.sql dropped "Allow all access",
--       "Allow anon read", "Allow authenticated read"
--       (actual names: "time_inference_rules: authenticated read all",
--        "time_inference_rules: authenticated update")
--
--   Because DROP POLICY IF EXISTS silently succeeds on non-existent names,
--   the permissive policies survived. This is a live security hole.
--
-- FIX:
--   Drop the three policies using their ACTUAL names.
--   Admin-only policies already exist from the later migrations:
--     - app_config: "app_config_superadmin_update/insert/delete" (20260224)
--     - time_inference_rules: "Admin read/write time_inference_rules" (20260228100000)
--   So admin access is unaffected.
-- =============================================================================

-- 1. app_config: remove the wide-open authenticated UPDATE policy
--    (superadmin-only policy "app_config_superadmin_update" remains)
DROP POLICY IF EXISTS "app_config: authenticated update" ON public.app_config;

-- 2. time_inference_rules: remove the wide-open authenticated SELECT policy
--    (admin-only policy "Admin read time_inference_rules" remains)
DROP POLICY IF EXISTS "time_inference_rules: authenticated read all" ON public.time_inference_rules;

-- 3. time_inference_rules: remove the wide-open authenticated UPDATE policy
--    (admin-only policy "Admin write time_inference_rules" remains)
DROP POLICY IF EXISTS "time_inference_rules: authenticated update" ON public.time_inference_rules;
