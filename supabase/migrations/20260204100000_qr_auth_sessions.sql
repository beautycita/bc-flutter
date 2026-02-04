-- =============================================================================
-- QR Auth Sessions - Cross-device authentication via QR code scan
-- =============================================================================

CREATE TABLE public.qr_auth_sessions (
  id            uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  code          text        NOT NULL UNIQUE,
  status        text        NOT NULL DEFAULT 'pending'
                            CHECK (status IN ('pending', 'authorized', 'consumed', 'expired')),
  user_id       uuid        REFERENCES auth.users(id),
  email         text,
  email_otp     text,
  created_at    timestamptz NOT NULL DEFAULT now(),
  expires_at    timestamptz NOT NULL DEFAULT (now() + interval '5 minutes'),
  authorized_at timestamptz,
  consumed_at   timestamptz
);

CREATE INDEX idx_qr_auth_code ON public.qr_auth_sessions(code) WHERE status = 'pending';
CREATE INDEX idx_qr_auth_expires ON public.qr_auth_sessions(expires_at) WHERE status IN ('pending', 'authorized');

ALTER TABLE public.qr_auth_sessions ENABLE ROW LEVEL SECURITY;

-- Anon can read (web needs to subscribe before auth)
CREATE POLICY "qr_sessions_select" ON public.qr_auth_sessions FOR SELECT USING (true);

-- Enable Realtime
ALTER PUBLICATION supabase_realtime ADD TABLE public.qr_auth_sessions;

-- Cleanup expired sessions
CREATE OR REPLACE FUNCTION public.cleanup_expired_qr_sessions() RETURNS void
LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
  UPDATE public.qr_auth_sessions SET status = 'expired'
  WHERE status IN ('pending', 'authorized') AND expires_at < now();
  DELETE FROM public.qr_auth_sessions
  WHERE status IN ('expired', 'consumed') AND created_at < now() - interval '1 hour';
$$;
