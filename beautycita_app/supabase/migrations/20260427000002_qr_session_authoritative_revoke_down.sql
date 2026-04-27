-- Reverse 20260427000002_qr_session_authoritative_revoke.sql.

DROP FUNCTION IF EXISTS public.revoke_auth_session(uuid);

DROP INDEX IF EXISTS public.idx_qr_auth_sessions_auth_session_id;

ALTER TABLE public.qr_auth_sessions
  DROP COLUMN IF EXISTS auth_session_id;
