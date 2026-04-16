-- Sync trigger functions to match prod (Decision #12: cold-start verification)
-- Previous migrations had stricter requirements (Stripe, RFC, banking).
-- Prod was updated directly. This migration brings the repo in line.

-- 1. update_onboarding_complete: services + schedule only (no Stripe)
CREATE OR REPLACE FUNCTION update_onboarding_complete()
RETURNS TRIGGER AS $$
BEGIN
  -- Onboarding is complete when salon has services + schedule.
  -- This is the minimum for Tier 1 (discovery) — salon appears in search.
  -- Stripe is required for Tier 2+ (accepting payments), not for visibility.
  IF NEW.has_services = true AND NEW.has_schedule = true THEN
    NEW.onboarding_complete := true;
    NEW.onboarding_step := 'complete';
  ELSE
    NEW.onboarding_complete := false;
    IF NOT NEW.has_services THEN
      NEW.onboarding_step := 'services';
    ELSIF NOT NEW.has_schedule THEN
      NEW.onboarding_step := 'schedule';
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 2. auto_approve_business: onboarding_complete only (no RFC/banking/ID)
CREATE OR REPLACE FUNCTION auto_approve_business()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.is_verified = true THEN
    RETURN NEW;
  END IF;

  -- Auto-verify when onboarding is complete (services + schedule).
  -- Tier 1 (discovery): salon appears in search. Minimum bar.
  -- Tier 3 (payouts): RFC + banking + ID enforced in payout flow, not here.
  IF NEW.onboarding_complete = true THEN
    NEW.is_verified := true;

    UPDATE public.profiles
    SET role = 'stylist'
    WHERE id = NEW.owner_id
      AND role NOT IN ('admin', 'superadmin', 'stylist');
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 3. Ensure trigger exists (idempotent)
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger WHERE tgname = 'trg_auto_approve_business'
  ) THEN
    CREATE TRIGGER trg_auto_approve_business
      BEFORE UPDATE ON public.businesses
      FOR EACH ROW
      EXECUTE FUNCTION public.auto_approve_business();
  END IF;
END $$;
