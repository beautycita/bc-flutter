-- Auto-link new businesses back to their discovered_salons row.
--
-- Context: salon-registro/index.ts already updates the discovered_salons
-- row to status='registered' WHEN the user enters via a deep-link with
-- ref=<discovered_salons.id>. But users who reach /registrar through
-- other channels (homepage CTA, banner, "Crear mi salon", etc.) skip
-- that flow, the refId is null, and the discovered row stays at
-- status='selected' forever — even though the same phone is now in
-- businesses. That makes the salon keep showing up in admin's invite
-- list as if it never registered. (BC caught this on 2026-04-19 with
-- "De Mar y Luna" — Bertha registered via direct flow on 2026-04-15
-- and the row was still showing up in the invite list 4 days later.)
--
-- Fix: on every businesses INSERT, match the last 10 digits of the
-- new business phone (or whatsapp) against discovered_salons. If a
-- non-registered row matches, mark it registered and link the IDs.
-- Idempotent: only updates rows that aren't already registered/declined.

CREATE OR REPLACE FUNCTION link_business_to_discovered_salon()
RETURNS TRIGGER AS $$
DECLARE
  v_new_last10 text;
  v_matched_id uuid;
BEGIN
  -- Normalize new business phone(s) to last 10 digits
  v_new_last10 := RIGHT(regexp_replace(COALESCE(NEW.phone, ''), '[^0-9]', '', 'g'), 10);

  -- Skip if phone too short to be meaningful
  IF LENGTH(v_new_last10) < 10 THEN
    -- Try whatsapp as fallback
    v_new_last10 := RIGHT(regexp_replace(COALESCE(NEW.whatsapp, ''), '[^0-9]', '', 'g'), 10);
    IF LENGTH(v_new_last10) < 10 THEN
      RETURN NEW;
    END IF;
  END IF;

  -- Find an unregistered discovered_salons row matching the new business
  SELECT id INTO v_matched_id
  FROM discovered_salons
  WHERE status NOT IN ('registered', 'declined')
    AND RIGHT(regexp_replace(COALESCE(phone, ''), '[^0-9]', '', 'g'), 10) = v_new_last10
    AND LENGTH(regexp_replace(COALESCE(phone, ''), '[^0-9]', '', 'g')) >= 10
  ORDER BY
    -- Prefer 'selected' (has been touched by RP) over plain 'discovered'
    CASE status WHEN 'selected' THEN 0 ELSE 1 END,
    created_at DESC
  LIMIT 1;

  IF v_matched_id IS NOT NULL THEN
    UPDATE discovered_salons
    SET status = 'registered',
        registered_business_id = NEW.id,
        registered_at = NEW.created_at
    WHERE id = v_matched_id
      AND status NOT IN ('registered', 'declined');
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_link_business_to_discovered ON businesses;
CREATE TRIGGER trg_link_business_to_discovered
AFTER INSERT ON businesses
FOR EACH ROW
EXECUTE FUNCTION link_business_to_discovered_salon();
