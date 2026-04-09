-- Auto-verification trigger: replaces manual admin approval.
-- When all conditions are met, business is automatically verified.
-- When any condition fails, verification is revoked.

-- Add license_url column for business license uploads
ALTER TABLE businesses ADD COLUMN IF NOT EXISTS license_url text;

-- Function to evaluate verification conditions
CREATE OR REPLACE FUNCTION evaluate_business_verification()
RETURNS trigger AS $$
DECLARE
  _has_services boolean;
  _has_schedule boolean;
  _stripe_charges boolean;
  _stripe_payouts boolean;
  _has_rfc boolean;
  _has_clabe boolean;
  _all_met boolean;
  _biz_id uuid;
BEGIN
  -- Determine which business to evaluate
  IF TG_TABLE_NAME = 'services' THEN
    _biz_id := COALESCE(NEW.business_id, OLD.business_id);
  ELSE
    _biz_id := COALESCE(NEW.id, OLD.id);
  END IF;

  IF _biz_id IS NULL THEN
    RETURN COALESCE(NEW, OLD);
  END IF;

  -- Check: has at least one active service
  SELECT EXISTS(
    SELECT 1 FROM services WHERE business_id = _biz_id AND is_active = true
  ) INTO _has_services;

  -- Check: hours column is not null and not empty
  SELECT
    hours IS NOT NULL AND hours::text != '' AND hours::text != '{}' AND hours::text != 'null'
  INTO _has_schedule
  FROM businesses WHERE id = _biz_id;

  -- Check: stripe charges + payouts enabled
  SELECT
    COALESCE(stripe_charges_enabled, false),
    COALESCE(stripe_payouts_enabled, false),
    COALESCE(rfc, '') != '',
    clabe IS NOT NULL
  INTO _stripe_charges, _stripe_payouts, _has_rfc, _has_clabe
  FROM businesses WHERE id = _biz_id;

  _all_met := _has_services
    AND COALESCE(_has_schedule, false)
    AND _stripe_charges
    AND _stripe_payouts
    AND _has_rfc
    AND _has_clabe;

  -- Update verification status
  IF _all_met THEN
    UPDATE businesses
    SET is_verified = true, onboarding_complete = true
    WHERE id = _biz_id AND (is_verified = false OR onboarding_complete = false);
  ELSE
    UPDATE businesses
    SET is_verified = false
    WHERE id = _biz_id AND is_verified = true;
  END IF;

  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger on businesses table (fires on relevant column changes)
DROP TRIGGER IF EXISTS trg_auto_verify_business ON businesses;
CREATE TRIGGER trg_auto_verify_business
  AFTER INSERT OR UPDATE OF hours, stripe_charges_enabled, stripe_payouts_enabled, rfc, clabe
  ON businesses
  FOR EACH ROW
  EXECUTE FUNCTION evaluate_business_verification();

-- Trigger on services table (fires when services are added/removed/toggled)
DROP TRIGGER IF EXISTS trg_auto_verify_services ON services;
CREATE TRIGGER trg_auto_verify_services
  AFTER INSERT OR UPDATE OF is_active OR DELETE
  ON services
  FOR EACH ROW
  EXECUTE FUNCTION evaluate_business_verification();
