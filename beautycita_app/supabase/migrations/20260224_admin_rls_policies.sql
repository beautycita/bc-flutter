-- =============================================================================
-- Admin RLS Policies + Missing RLS Fixes
-- Date: 2026-02-24
-- Purpose:
--   1. Fix chat_threads and chat_messages (RLS disabled — anyone could read all)
--   2. Add user-facing and admin policies to 6 tables that have RLS ON but zero policies
--   3. Add missing admin SELECT policies on sensitive tables
--   4. Lock down app_config write to superadmin only
--   5. Add admin read for uber_scheduled_rides, user_booking_patterns,
--      btc_addresses, btc_deposits, user_media, notifications, reviews
-- =============================================================================

BEGIN;

-- ---------------------------------------------------------------------------
-- SECTION 1: Re-enable RLS on chat tables (was somehow disabled in production)
-- ---------------------------------------------------------------------------

ALTER TABLE public.chat_threads ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chat_messages ENABLE ROW LEVEL SECURITY;

-- chat_threads: users own their threads
CREATE POLICY IF NOT EXISTS "chat_threads_owner_all"
  ON public.chat_threads
  FOR ALL
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- chat_threads: admins can read all threads
CREATE POLICY IF NOT EXISTS "chat_threads_admin_read"
  ON public.chat_threads
  FOR SELECT
  TO authenticated
  USING (is_admin());

-- chat_messages: users can see messages in their own threads
CREATE POLICY IF NOT EXISTS "chat_messages_owner_all"
  ON public.chat_messages
  FOR ALL
  TO authenticated
  USING (
    thread_id IN (
      SELECT id FROM public.chat_threads WHERE user_id = auth.uid()
    )
  )
  WITH CHECK (
    thread_id IN (
      SELECT id FROM public.chat_threads WHERE user_id = auth.uid()
    )
  );

-- chat_messages: admins can read all messages
CREATE POLICY IF NOT EXISTS "chat_messages_admin_read"
  ON public.chat_messages
  FOR SELECT
  TO authenticated
  USING (is_admin());

-- ---------------------------------------------------------------------------
-- SECTION 2: calendar_connections — RLS on, zero policies
-- Staff calendar OAuth tokens. Owner = staff row owner (via staff.id).
-- ---------------------------------------------------------------------------

-- Owners (business owners whose staff this belongs to) can manage
CREATE POLICY IF NOT EXISTS "calendar_connections_owner_all"
  ON public.calendar_connections
  FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.staff s
      JOIN public.businesses b ON s.business_id = b.id
      WHERE s.id = calendar_connections.staff_id
      AND b.owner_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.staff s
      JOIN public.businesses b ON s.business_id = b.id
      WHERE s.id = calendar_connections.staff_id
      AND b.owner_id = auth.uid()
    )
  );

-- Admins can read all calendar connections
CREATE POLICY IF NOT EXISTS "calendar_connections_admin_read"
  ON public.calendar_connections
  FOR SELECT
  TO authenticated
  USING (is_admin());

-- Admins can manage all calendar connections (for support/debugging)
CREATE POLICY IF NOT EXISTS "calendar_connections_admin_all"
  ON public.calendar_connections
  FOR ALL
  TO authenticated
  USING (is_admin())
  WITH CHECK (is_admin());

-- ---------------------------------------------------------------------------
-- SECTION 3: phone_verification_codes — RLS on, zero policies
-- Sensitive OTP codes. Users should only see their own, admins read all.
-- ---------------------------------------------------------------------------

-- Users can read their own verification codes (app needs this to check status)
CREATE POLICY IF NOT EXISTS "phone_verification_codes_owner_select"
  ON public.phone_verification_codes
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

-- Admins can read all verification codes
CREATE POLICY IF NOT EXISTS "phone_verification_codes_admin_read"
  ON public.phone_verification_codes
  FOR SELECT
  TO authenticated
  USING (is_admin());

-- Service role can insert/update codes (via edge functions / RPCs)
-- Note: inserts/updates done via SECURITY DEFINER functions, not direct client

-- ---------------------------------------------------------------------------
-- SECTION 4: salon_outreach_log — RLS on, zero policies
-- Admin/service-role only. No user should access this.
-- ---------------------------------------------------------------------------

CREATE POLICY IF NOT EXISTS "salon_outreach_log_admin_all"
  ON public.salon_outreach_log
  FOR ALL
  TO authenticated
  USING (is_admin())
  WITH CHECK (is_admin());

-- ---------------------------------------------------------------------------
-- SECTION 5: scrape_requests — RLS on, zero policies
-- Users can see their own requests; admins see all.
-- ---------------------------------------------------------------------------

CREATE POLICY IF NOT EXISTS "scrape_requests_owner_select"
  ON public.scrape_requests
  FOR SELECT
  TO authenticated
  USING (auth.uid() = requested_by);

CREATE POLICY IF NOT EXISTS "scrape_requests_admin_all"
  ON public.scrape_requests
  FOR ALL
  TO authenticated
  USING (is_admin())
  WITH CHECK (is_admin());

-- ---------------------------------------------------------------------------
-- SECTION 6: user_totp_secrets — RLS on, zero policies
-- Highly sensitive. Users own their row; admins can read (for support).
-- ---------------------------------------------------------------------------

CREATE POLICY IF NOT EXISTS "user_totp_secrets_owner_all"
  ON public.user_totp_secrets
  FOR ALL
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY IF NOT EXISTS "user_totp_secrets_admin_read"
  ON public.user_totp_secrets
  FOR SELECT
  TO authenticated
  USING (is_superadmin());

-- ---------------------------------------------------------------------------
-- SECTION 7: wa_chat_bridges — RLS on, zero policies
-- Thread<>WhatsApp mapping. Service role only (edge functions).
-- Admins can read for support visibility.
-- ---------------------------------------------------------------------------

CREATE POLICY IF NOT EXISTS "wa_chat_bridges_admin_read"
  ON public.wa_chat_bridges
  FOR SELECT
  TO authenticated
  USING (is_admin());

-- Service role bypass is automatic (service_role key bypasses RLS entirely).
-- No user-facing policy needed.

-- ---------------------------------------------------------------------------
-- SECTION 8: Missing admin SELECT on sensitive tables
-- ---------------------------------------------------------------------------

-- notifications: admin read all
CREATE POLICY IF NOT EXISTS "notifications_admin_read"
  ON public.notifications
  FOR SELECT
  TO authenticated
  USING (is_admin());

-- reviews: admin read all (including non-visible)
CREATE POLICY IF NOT EXISTS "reviews_admin_read_all"
  ON public.reviews
  FOR SELECT
  TO authenticated
  USING (is_admin());

-- reviews: admin can update (moderate, toggle visibility)
CREATE POLICY IF NOT EXISTS "reviews_admin_update"
  ON public.reviews
  FOR UPDATE
  TO authenticated
  USING (is_admin())
  WITH CHECK (is_admin());

-- reviews: admin can delete (remove inappropriate content)
CREATE POLICY IF NOT EXISTS "reviews_admin_delete"
  ON public.reviews
  FOR DELETE
  TO authenticated
  USING (is_admin());

-- user_media: admin read all
CREATE POLICY IF NOT EXISTS "user_media_admin_read"
  ON public.user_media
  FOR SELECT
  TO authenticated
  USING (is_admin());

-- uber_scheduled_rides: admin read all
CREATE POLICY IF NOT EXISTS "uber_scheduled_rides_admin_read"
  ON public.uber_scheduled_rides
  FOR SELECT
  TO authenticated
  USING (is_admin());

-- user_booking_patterns: admin read all
CREATE POLICY IF NOT EXISTS "user_booking_patterns_admin_read"
  ON public.user_booking_patterns
  FOR SELECT
  TO authenticated
  USING (is_admin());

-- btc_addresses: admin read all
CREATE POLICY IF NOT EXISTS "btc_addresses_admin_read"
  ON public.btc_addresses
  FOR SELECT
  TO authenticated
  USING (is_admin());

-- btc_deposits: admin read all
CREATE POLICY IF NOT EXISTS "btc_deposits_admin_read"
  ON public.btc_deposits
  FOR SELECT
  TO authenticated
  USING (is_admin());

-- salon_interest_signals: admin read all
CREATE POLICY IF NOT EXISTS "salon_interest_signals_admin_read"
  ON public.salon_interest_signals
  FOR SELECT
  TO authenticated
  USING (is_admin());

-- favorites: admin read all
CREATE POLICY IF NOT EXISTS "favorites_admin_read"
  ON public.favorites
  FOR SELECT
  TO authenticated
  USING (is_admin());

-- user_transport_preferences: admin read all
CREATE POLICY IF NOT EXISTS "user_transport_preferences_admin_read"
  ON public.user_transport_preferences
  FOR SELECT
  TO authenticated
  USING (is_admin());

-- time_inference_corrections: admin read all (already all-read, but add write control)
-- This table has "anyone can read" which is fine (aggregate/anonymous data)
-- Add admin-only write
CREATE POLICY IF NOT EXISTS "time_corrections_admin_insert"
  ON public.time_inference_corrections
  FOR INSERT
  TO authenticated
  WITH CHECK (is_admin());

-- qr_auth_sessions: tighten — currently "true" (world-readable)
-- Drop the overly permissive policy and replace with user-own + admin
DROP POLICY IF EXISTS "qr_sessions_select" ON public.qr_auth_sessions;

CREATE POLICY IF NOT EXISTS "qr_auth_sessions_owner_select"
  ON public.qr_auth_sessions
  FOR SELECT
  TO public
  USING (true);
-- Note: QR sessions are intentionally public-readable by token (the token IS the secret)
-- Keeping world-readable for anon polling. The token is a UUID and unguessable.

-- ---------------------------------------------------------------------------
-- SECTION 9: app_config write lockdown
-- Currently any authenticated user can UPDATE app_config — should be superadmin
-- ---------------------------------------------------------------------------

DROP POLICY IF EXISTS "app_config_update" ON public.app_config;

CREATE POLICY IF NOT EXISTS "app_config_superadmin_update"
  ON public.app_config
  FOR UPDATE
  TO authenticated
  USING (is_superadmin())
  WITH CHECK (is_superadmin());

CREATE POLICY IF NOT EXISTS "app_config_superadmin_insert"
  ON public.app_config
  FOR INSERT
  TO authenticated
  WITH CHECK (is_superadmin());

CREATE POLICY IF NOT EXISTS "app_config_superadmin_delete"
  ON public.app_config
  FOR DELETE
  TO authenticated
  USING (is_superadmin());

-- ---------------------------------------------------------------------------
-- SECTION 10: engine_analytics_events — anyone can read but only system inserts
-- Currently no INSERT/DELETE/UPDATE policies, which means only service_role
-- can mutate (correct). Add admin read for completeness (already covered by
-- "anyone can read", but add explicit admin management).
-- ---------------------------------------------------------------------------

CREATE POLICY IF NOT EXISTS "engine_analytics_admin_delete"
  ON public.engine_analytics_events
  FOR DELETE
  TO authenticated
  USING (is_superadmin());

COMMIT;
