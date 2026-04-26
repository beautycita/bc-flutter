DO $$
BEGIN
  PERFORM cron.unschedule(jobid)
    FROM cron.job
   WHERE jobname = 'classify-discovered-salons-nightly';
END $$;
