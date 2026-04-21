-- =============================================================================
-- Migration: 20260420000001_rfc_removal_revalidation.sql
-- Description: If RFC is removed (or banking_complete flipped off, or ID
-- verification unwound) on a verified business, force is_verified back to
-- false so the row drops out of curate_candidates and any other gated query.
--
-- Paired with auto_approve_business() which SETS is_verified = true only when
-- all requirements are met. That trigger didn't cover the reverse direction:
-- an admin editing a row to null the RFC would leave is_verified = true and
-- the salon would continue appearing in search without a valid tax ID.
-- =============================================================================

CREATE OR REPLACE FUNCTION public.revoke_verification_on_requirement_loss()
RETURNS TRIGGER AS $$
BEGIN
  -- Only act when the row is currently verified
  IF NEW.is_verified = false THEN
    RETURN NEW;
  END IF;

  -- Any one of these going false / null means verification must be revoked.
  -- Mirrors the AND-gate in auto_approve_business().
  IF (NEW.rfc IS NULL OR NEW.rfc = '')
     OR NEW.onboarding_complete = false
     OR NEW.banking_complete = false
     OR NEW.id_verification_status <> 'verified'
  THEN
    NEW.is_verified := false;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS businesses_revoke_verification ON public.businesses;

CREATE TRIGGER businesses_revoke_verification
  BEFORE UPDATE OF rfc, onboarding_complete, banking_complete, id_verification_status
  ON public.businesses
  FOR EACH ROW EXECUTE PROCEDURE public.revoke_verification_on_requirement_loss();

COMMENT ON FUNCTION public.revoke_verification_on_requirement_loss() IS
  'Flips is_verified=false when any verification requirement (rfc, onboarding_complete, banking_complete, id_verification_status) is unwound. Pairs with auto_approve_business() which handles the positive direction.';
