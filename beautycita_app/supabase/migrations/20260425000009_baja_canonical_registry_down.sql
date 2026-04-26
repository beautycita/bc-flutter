-- Down: backfill is data-only; deleting the backfilled rows would lose
-- historical opt-out records. Intentional no-op.
SELECT 'noop'::text AS down_action;
