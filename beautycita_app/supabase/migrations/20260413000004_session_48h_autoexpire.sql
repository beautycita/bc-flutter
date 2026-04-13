-- Auto-expire consumed QR auth sessions after 48 hours.
-- Old behavior: deleted consumed sessions after 1 hour.
-- New behavior: revoke after 48h, delete after 7 days.
-- Cron: every 6 hours via qr-auth cleanup action.

CREATE OR REPLACE FUNCTION cleanup_expired_qr_sessions()
RETURNS void LANGUAGE sql SECURITY DEFINER AS $$
  -- 1. Expire pending/authorized sessions past their 5-min window
  UPDATE public.qr_auth_sessions SET status = 'expired'
  WHERE status IN ('pending', 'authorized') AND expires_at < now();

  -- 2. Auto-revoke consumed (active web) sessions after 48 hours
  UPDATE public.qr_auth_sessions SET status = 'revoked'
  WHERE status = 'consumed' AND consumed_at < now() - interval '48 hours';

  -- 3. Clean up old expired/revoked sessions after 7 days
  DELETE FROM public.qr_auth_sessions
  WHERE status IN ('expired', 'revoked') AND created_at < now() - interval '7 days';
$$;
