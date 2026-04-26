-- =============================================================================
-- Close RLS leaks caught by BC Monitor's attack-surface sweep
-- =============================================================================
-- Two leaks found:
--   1. admin_trait_access_log — `atal_service` policy used USING true with no
--      role filter, so anon could SELECT the entire admin audit log.
--   2. qr_auth_sessions — `qr_sessions_select_pending` allowed any anon to
--      enumerate pending QR sessions. The qr-auth edge function uses service
--      role anyway, so direct PostgREST access from anon is not needed.
-- =============================================================================

-- ── 1. admin_trait_access_log: tighten service policy to require service_role ──
DROP POLICY IF EXISTS atal_service ON public.admin_trait_access_log;
CREATE POLICY atal_service ON public.admin_trait_access_log
  FOR ALL USING (auth.role() = 'service_role')
  WITH CHECK (auth.role() = 'service_role');

-- ── 2. qr_auth_sessions: drop the public-pending policy ──────────────────────
-- All session reads go through the qr-auth edge function (service role).
-- Direct anon SELECT is no longer needed.
DROP POLICY IF EXISTS qr_sessions_select_pending ON public.qr_auth_sessions;

-- Keep self-read for authenticated users (who own a session) — that's
-- already gated by user_id = auth.uid() and is fine.

COMMENT ON TABLE public.qr_auth_sessions IS
  'QR auth pairing sessions. Read access only via qr-auth edge function (service role) or by authenticated owner. Anon enumeration of pending sessions removed 2026-04-26.';
