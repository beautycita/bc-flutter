-- Disable automatic loyalty-point awards.
--
-- Why: bughunter test flows complete-and-delete appointments to exercise
-- the booking lifecycle, and the AFTER UPDATE trigger
-- award_loyalty_points_on_completion fired on every flip to completed —
-- minting loyalty points against test users on the test salon. We want
-- loyalty to be an intentional feature later, not an unattributed cost
-- silently emitted by every completed appointment (test or otherwise).
--
-- Strategy: drop the trigger and the function so the auto-award path
-- doesn't run. Schema (loyalty_transactions table, business_clients
-- .loyalty_points column, RLS policy) stays intact so the feature can
-- be re-introduced cleanly when there's an explicit policy for it.
--
-- Also wipe accumulated test rows so business_clients reads come back
-- clean (test salon currently shows 150 phantom points).

DROP TRIGGER IF EXISTS trg_loyalty_points ON appointments;
DROP FUNCTION IF EXISTS award_loyalty_points_on_completion();

UPDATE business_clients SET loyalty_points = 0, updated_at = now()
  WHERE loyalty_points <> 0;

DELETE FROM loyalty_transactions;
