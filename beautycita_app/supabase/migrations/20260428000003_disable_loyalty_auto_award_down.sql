-- Restore the auto-award trigger if loyalty is reactivated.
-- Mirrors 20260329000001_loyalty_points.sql exactly so prior behaviour
-- is reproduced. Note: this does NOT replay historical appointments —
-- only future status flips earn points after this is run.

CREATE OR REPLACE FUNCTION award_loyalty_points_on_completion()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_points integer;
BEGIN
  IF NEW.status = 'completed' AND (OLD.status IS NULL OR OLD.status != 'completed')
     AND NEW.user_id IS NOT NULL AND COALESCE(NEW.price, 0) > 0 THEN
    v_points := FLOOR(NEW.price / 10);
    IF v_points > 0 THEN
      INSERT INTO loyalty_transactions (business_id, user_id, points, type, source, reference_id)
      VALUES (NEW.business_id, NEW.user_id, v_points, 'earned', 'appointment', NEW.id);

      UPDATE business_clients SET loyalty_points = loyalty_points + v_points, updated_at = NOW()
      WHERE business_id = NEW.business_id AND user_id = NEW.user_id;
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_loyalty_points ON appointments;
CREATE TRIGGER trg_loyalty_points
  AFTER UPDATE ON appointments FOR EACH ROW
  EXECUTE FUNCTION award_loyalty_points_on_completion();
