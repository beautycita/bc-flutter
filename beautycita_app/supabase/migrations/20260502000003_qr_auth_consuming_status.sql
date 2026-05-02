-- =============================================================================
-- 20260502000003 — allow 'consuming' status on qr_auth_sessions
-- =============================================================================
-- The qr-auth/verify CAS flips status from 'authorized' to a transient
-- 'consuming' before calling gotrue.verifyOtp (so a racing broadcast +
-- 3s poll handler can't both reach the single-use OTP). The CHECK
-- constraint hadn't been updated to include the transient value, so
-- every CAS attempt failed with code 23514 and the user saw a generic
-- "Error al iniciar sesion" — same surface as the original race bug
-- this CAS was meant to fix.
-- =============================================================================

ALTER TABLE public.qr_auth_sessions
  DROP CONSTRAINT qr_auth_sessions_status_check;

ALTER TABLE public.qr_auth_sessions
  ADD CONSTRAINT qr_auth_sessions_status_check
  CHECK (status = ANY (ARRAY[
    'pending'::text,
    'authorized'::text,
    'consuming'::text,
    'consumed'::text,
    'expired'::text,
    'revoked'::text
  ]));
