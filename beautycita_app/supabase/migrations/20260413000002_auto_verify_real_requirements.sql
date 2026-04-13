-- =============================================================================
-- Migration: 20260413000002_auto_verify_real_requirements.sql
-- Description: Replace auto_approve_business trigger with real verification:
--   1. onboarding_complete (services + schedule + Stripe)
--   2. RFC provided
--   3. banking_complete (CLABE + beneficiary ID verified)
-- Old trigger: checked email + phone confirmed (temporary for test salons)
-- =============================================================================

CREATE OR REPLACE FUNCTION auto_approve_business()
RETURNS TRIGGER AS $$
BEGIN
  -- Skip if already verified
  IF NEW.is_verified = true THEN
    RETURN NEW;
  END IF;

  -- Auto-verify when ALL requirements are met:
  -- 1. Onboarding complete (services + schedule + Stripe connected)
  -- 2. RFC provided
  -- 3. Banking complete (CLABE + beneficiary ID verified)
  IF NEW.onboarding_complete = true
    AND NEW.rfc IS NOT NULL AND NEW.rfc != ''
    AND NEW.banking_complete = true
    AND NEW.id_verification_status = 'verified'
  THEN
    NEW.is_verified := true;

    -- Promote owner to stylist (don't demote admins)
    UPDATE public.profiles
    SET role = 'stylist'
    WHERE id = NEW.owner_id
      AND role NOT IN ('admin', 'superadmin', 'stylist');
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;
