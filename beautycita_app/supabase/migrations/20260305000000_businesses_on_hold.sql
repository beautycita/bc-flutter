-- =============================================================================
-- Add on_hold column to businesses
-- Date: 2026-03-05
-- Purpose: Support "on hold" state — salon disappears from search results
--          but no client notifications are sent (lighter than suspension).
-- =============================================================================

ALTER TABLE public.businesses
  ADD COLUMN IF NOT EXISTS on_hold boolean NOT NULL DEFAULT false;

COMMENT ON COLUMN public.businesses.on_hold IS 'When true, salon is hidden from search but bookings are unaffected. Lighter than suspension (is_active=false).';

-- Update the existing RLS select policy to also exclude on_hold businesses
-- from public reads, while keeping them visible to admins and owners.
DROP POLICY IF EXISTS "Businesses: anyone can read active" ON public.businesses;

CREATE POLICY "Businesses: anyone can read active"
  ON public.businesses FOR SELECT
  USING (is_active = true AND on_hold = false);

-- Admin can still read all businesses (including suspended and on-hold)
CREATE POLICY IF NOT EXISTS "Businesses: admin can read all"
  ON public.businesses FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- Business owner can still read their own business even if suspended/on-hold
CREATE POLICY IF NOT EXISTS "Businesses: owner can read own"
  ON public.businesses FOR SELECT
  TO authenticated
  USING (owner_id = auth.uid());
