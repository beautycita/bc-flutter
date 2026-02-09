-- =============================================================================
-- Security Lockdown: RLS fixes for profiles and qr_auth_sessions
-- Migration: 20260207000000_rls_security_lockdown.sql
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. Profiles: Replace "anyone can read" with "own row only"
--    Prevents any user from reading another user's uber tokens
-- ---------------------------------------------------------------------------
DROP POLICY IF EXISTS "Profiles: anyone can read" ON public.profiles;

CREATE POLICY "Profiles: users can read own"
  ON public.profiles FOR SELECT
  USING (auth.uid() = id);

-- ---------------------------------------------------------------------------
-- 2. QR Auth Sessions: Hide email_otp via column-level grants
--    Web needs to subscribe via Realtime before auth, so anon still needs
--    SELECT — but only on safe columns. email_otp stays server-side only.
-- ---------------------------------------------------------------------------
DROP POLICY IF EXISTS "qr_sessions_select" ON public.qr_auth_sessions;

-- Revoke blanket access, then grant only safe columns
REVOKE ALL ON public.qr_auth_sessions FROM anon, authenticated;

GRANT SELECT (id, code, status, user_id, email, created_at, expires_at, authorized_at, consumed_at)
  ON public.qr_auth_sessions TO anon, authenticated;

-- Re-create SELECT policy (RLS still required even with column grants)
CREATE POLICY "qr_sessions_select"
  ON public.qr_auth_sessions FOR SELECT
  USING (true);

-- ---------------------------------------------------------------------------
-- 3. Fix CHECK constraint to include 'revoked' status
-- ---------------------------------------------------------------------------
ALTER TABLE public.qr_auth_sessions DROP CONSTRAINT IF EXISTS qr_auth_sessions_status_check;
ALTER TABLE public.qr_auth_sessions
  ADD CONSTRAINT qr_auth_sessions_status_check
  CHECK (status IN ('pending', 'authorized', 'consumed', 'expired', 'revoked'));
