-- =============================================================================
-- Migration: 20260420000007_arco_requests.sql
-- Description: LFPDPPP ARCO rights tracking table.
-- LFPDPPP 2025 Art. 22-25: Acceso, Rectificación, Cancelación, Oposición.
-- 20-business-day response window from receipt. Universal opt-out.
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.arco_requests (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  request_type    text NOT NULL CHECK (request_type IN (
                    'access',           -- Acceso: full data export
                    'rectification',    -- Rectificación: correct specific field
                    'cancellation',     -- Cancelación: delete data
                    'opposition'        -- Oposición: stop specific processing
                  )),
  status          text NOT NULL DEFAULT 'pending' CHECK (status IN (
                    'pending', 'processing', 'completed', 'denied', 'expired'
                  )),
  details         jsonb NOT NULL DEFAULT '{}'::jsonb,    -- field to rectify, what to oppose, etc.
  user_email      text,                                  -- for response delivery
  response_notes  text,
  submitted_at    timestamptz NOT NULL DEFAULT now(),
  acknowledged_at timestamptz,
  responded_at    timestamptz,
  resolved_at     timestamptz,
  resolved_by     uuid REFERENCES public.profiles(id),

  -- LFPDPPP statutory window: 20 business days. Tracked column for SLA dashboards.
  due_at          timestamptz NOT NULL DEFAULT (now() + interval '28 days')  -- 20 biz days ≈ 28 cal
);

CREATE INDEX IF NOT EXISTS arco_requests_user_idx ON public.arco_requests(user_id);
CREATE INDEX IF NOT EXISTS arco_requests_pending_idx
  ON public.arco_requests(status, due_at)
  WHERE status IN ('pending', 'processing');

ALTER TABLE public.arco_requests ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS arco_requests_owner_read ON public.arco_requests;
CREATE POLICY arco_requests_owner_read ON public.arco_requests
  FOR SELECT
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS arco_requests_admin_all ON public.arco_requests;
CREATE POLICY arco_requests_admin_all ON public.arco_requests
  FOR ALL
  USING (
    auth.role() = 'service_role'
    OR EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND role IN ('admin', 'superadmin')
    )
  );

DROP POLICY IF EXISTS arco_requests_owner_insert ON public.arco_requests;
CREATE POLICY arco_requests_owner_insert ON public.arco_requests
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

COMMENT ON TABLE public.arco_requests IS
  'LFPDPPP ARCO rights request tracking. 20-business-day SLA per Art 32. '
  'Linked to LFPDPPP 2025 reform; SABG enforces.';
