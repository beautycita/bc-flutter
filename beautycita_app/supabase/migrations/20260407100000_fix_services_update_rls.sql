-- =============================================================================
-- RQ-014: Fix services UPDATE policy to allow deactivation
-- =============================================================================
-- The existing policy may have is_active = true in its USING clause,
-- preventing salon owners from deactivating their own services.
-- Drop and recreate with ownership-only check.
-- =============================================================================

-- Drop the existing policy (safe: IF EXISTS)
DROP POLICY IF EXISTS "Services: owners can update" ON public.services;

-- Recreate with ownership-only check (no is_active filter)
CREATE POLICY "Services: owners can update"
  ON public.services FOR UPDATE
  USING (
    business_id IN (
      SELECT id FROM public.businesses WHERE owner_id = auth.uid()
    )
  )
  WITH CHECK (
    business_id IN (
      SELECT id FROM public.businesses WHERE owner_id = auth.uid()
    )
  );
