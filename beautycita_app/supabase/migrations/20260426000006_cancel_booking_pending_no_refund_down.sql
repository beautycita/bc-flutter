-- Down: revert cancel_booking to refund pending bookings as if paid (the bug).
-- Not auto-restoring — caller must re-apply the prior body manually if rollback needed.
SELECT 'noop: reverting this migration restores a money-loss bug; do not run blindly'::text;
