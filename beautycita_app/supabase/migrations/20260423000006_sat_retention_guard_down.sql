-- Rollback: remove the SAT retention-guard triggers + function.
DROP TRIGGER IF EXISTS sat_retention_guard ON public.tax_withholdings;
DROP TRIGGER IF EXISTS sat_retention_guard ON public.sat_access_log;
DROP TRIGGER IF EXISTS sat_retention_guard ON public.sat_monthly_reports;
DROP TRIGGER IF EXISTS sat_retention_guard ON public.platform_sat_declarations;
DROP FUNCTION IF EXISTS public.sat_retention_guard();
