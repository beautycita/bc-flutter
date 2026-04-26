DO $$
DECLARE
  v_existing_jobid int;
BEGIN
  SELECT jobid INTO v_existing_jobid FROM cron.job WHERE jobname = 'wa-global-drain';
  IF v_existing_jobid IS NOT NULL THEN
    PERFORM cron.unschedule(v_existing_jobid);
  END IF;
END$$;
