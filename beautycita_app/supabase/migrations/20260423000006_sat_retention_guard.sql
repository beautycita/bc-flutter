-- =============================================================================
-- SAT table retention guard — CFF Art. 30 ≥5yr minimum
-- =============================================================================
-- Escrito libre §IV commits "Los registros se conservaran por un minimo de 5
-- anos conforme al Articulo 30 del CFF." Today no cron purges these tables
-- but nothing prevents an accidental DELETE either (e.g. a dev running a bad
-- cleanup script, or a bughunter flow misbehaving).
--
-- This migration adds BEFORE DELETE triggers on the four SAT-facing tables.
-- DELETE is allowed only when a session-local flag `app.sat_unlock` is set to
-- 'yes-i-really-do'. That flag cannot be set via SQL from an app session (GUC
-- permission denied) — it must be SET LOCAL by a superuser in a direct psql
-- connection. Net effect: DELETE via PostgREST or any edge function is
-- impossible; only a human with DB shell access can remove SAT data.
-- =============================================================================

CREATE OR REPLACE FUNCTION public.sat_retention_guard()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF current_setting('app.sat_unlock', true) IS DISTINCT FROM 'yes-i-really-do' THEN
    RAISE EXCEPTION
      'SAT retention guard: DELETE on % blocked. Records must be retained ≥5 years per CFF Art. 30. '
      'If you are a superadmin intending to remove a specific row, open a psql session and '
      'run: BEGIN; SET LOCAL app.sat_unlock = ''yes-i-really-do''; DELETE ...; COMMIT;',
      TG_TABLE_NAME
      USING ERRCODE = '42501';
  END IF;
  RETURN OLD;
END;
$$;

DROP TRIGGER IF EXISTS sat_retention_guard ON public.tax_withholdings;
CREATE TRIGGER sat_retention_guard
  BEFORE DELETE ON public.tax_withholdings
  FOR EACH ROW EXECUTE FUNCTION public.sat_retention_guard();

DROP TRIGGER IF EXISTS sat_retention_guard ON public.sat_access_log;
CREATE TRIGGER sat_retention_guard
  BEFORE DELETE ON public.sat_access_log
  FOR EACH ROW EXECUTE FUNCTION public.sat_retention_guard();

DROP TRIGGER IF EXISTS sat_retention_guard ON public.sat_monthly_reports;
CREATE TRIGGER sat_retention_guard
  BEFORE DELETE ON public.sat_monthly_reports
  FOR EACH ROW EXECUTE FUNCTION public.sat_retention_guard();

DROP TRIGGER IF EXISTS sat_retention_guard ON public.platform_sat_declarations;
CREATE TRIGGER sat_retention_guard
  BEFORE DELETE ON public.platform_sat_declarations
  FOR EACH ROW EXECUTE FUNCTION public.sat_retention_guard();

COMMENT ON FUNCTION public.sat_retention_guard() IS
  'CFF Art. 30 ≥5yr retention enforcement. Blocks DELETE on SAT-facing tables '
  'unless the session has explicitly set app.sat_unlock=yes-i-really-do '
  '(only possible via direct superuser psql, not app sessions).';
