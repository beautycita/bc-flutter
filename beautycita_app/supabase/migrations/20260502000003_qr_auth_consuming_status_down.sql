-- Reverse 20260502000003. NOTE: any rows in 'consuming' (a stuck verify
-- in flight) will block this; the safe down sequence is to first clear
-- those rows: UPDATE qr_auth_sessions SET status='expired' WHERE status='consuming';
ALTER TABLE public.qr_auth_sessions
  DROP CONSTRAINT qr_auth_sessions_status_check;

ALTER TABLE public.qr_auth_sessions
  ADD CONSTRAINT qr_auth_sessions_status_check
  CHECK (status = ANY (ARRAY[
    'pending'::text,
    'authorized'::text,
    'consumed'::text,
    'expired'::text,
    'revoked'::text
  ]));
