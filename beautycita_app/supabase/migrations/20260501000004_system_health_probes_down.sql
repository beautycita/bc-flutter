SELECT cron.unschedule('system_health_probe') WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'system_health_probe');
SELECT cron.unschedule('system_health_probe_prune') WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'system_health_probe_prune');
DROP FUNCTION IF EXISTS public.write_system_health_probe();
DROP TABLE IF EXISTS public.system_health_probes;
