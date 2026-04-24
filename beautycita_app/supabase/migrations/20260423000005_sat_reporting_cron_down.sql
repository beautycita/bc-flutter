-- Rollback: remove the sat monthly reporting cron job.
DO $$
DECLARE
  v_jobid int;
BEGIN
  SELECT jobid INTO v_jobid FROM cron.job WHERE jobname = 'sat-monthly-reporting';
  IF v_jobid IS NOT NULL THEN
    PERFORM cron.unschedule(v_jobid);
  END IF;
END$$;
