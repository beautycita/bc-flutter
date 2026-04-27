-- Authoritative QR session revocation.
--
-- Today, marking qr_auth_sessions.status='revoked' is purely informational —
-- the web client's Supabase access_token + refresh_token remain valid until
-- their natural lifetime expires, even after a mobile-side revoke. This means
-- removing a device from the session manager doesn't actually kick that
-- device offline.
--
-- Fix: capture the canonical auth.sessions.id when the QR is consumed, and
-- on revoke DELETE that auth session row. Cascade to auth.refresh_tokens
-- kills token refresh server-side; the access_token still works until its
-- natural expiry (default ~60 min) but at that point the next refresh 401s
-- and the client is forced to re-auth. A Realtime broadcast (added in the
-- accompanying edge fn change) gives instant kick on top of that.

ALTER TABLE public.qr_auth_sessions
  ADD COLUMN IF NOT EXISTS auth_session_id uuid;

COMMENT ON COLUMN public.qr_auth_sessions.auth_session_id
  IS 'auth.sessions.id of the web client minted by this QR consumption. '
     'Used by revoke_auth_session() to invalidate the actual auth session, '
     'not just this row.';

-- Sparse index: only consumed rows carry an auth_session_id.
CREATE INDEX IF NOT EXISTS idx_qr_auth_sessions_auth_session_id
  ON public.qr_auth_sessions (auth_session_id)
  WHERE auth_session_id IS NOT NULL;

-- Authoritative revoke RPC. Caller must be the owner of the qr_auth_sessions
-- row (auth.uid() = user_id). DELETEs the captured auth.sessions row, which
-- cascades to auth.refresh_tokens.
CREATE OR REPLACE FUNCTION public.revoke_auth_session(
  p_qr_session_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_owner   uuid;
  v_auth_id uuid;
  v_caller  uuid := auth.uid();
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'authentication required' USING ERRCODE = '42501';
  END IF;

  SELECT user_id, auth_session_id
    INTO v_owner, v_auth_id
    FROM public.qr_auth_sessions
   WHERE id = p_qr_session_id;

  IF v_owner IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'not_found');
  END IF;

  IF v_owner <> v_caller THEN
    RAISE EXCEPTION 'not authorized to revoke this session'
      USING ERRCODE = '42501';
  END IF;

  -- Kill the actual auth session — cascades to auth.refresh_tokens.
  -- If auth_session_id is null (legacy row pre-migration), we still flip
  -- the status so the row drops out of the device manager; the web side
  -- will only be kicked at natural token expiry, but new revocations
  -- after this migration capture the id and revoke authoritatively.
  IF v_auth_id IS NOT NULL THEN
    DELETE FROM auth.sessions WHERE id = v_auth_id;
  END IF;

  UPDATE public.qr_auth_sessions
     SET status = 'revoked'
   WHERE id = p_qr_session_id;

  RETURN jsonb_build_object(
    'ok', true,
    'qr_session_id', p_qr_session_id,
    'auth_session_id', v_auth_id,
    'cascaded', v_auth_id IS NOT NULL
  );
END;
$$;

REVOKE ALL ON FUNCTION public.revoke_auth_session(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.revoke_auth_session(uuid)
  TO authenticated, service_role;
