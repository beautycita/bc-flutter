SELECT cron.schedule('cleanup-orphaned-bookings', '*/10 * * * *',
  $$UPDATE appointments SET status = 'cancelled_system'
    WHERE status = 'pending' AND payment_status = 'pending'
    AND created_at < now() - interval '30 minutes'$$
);
