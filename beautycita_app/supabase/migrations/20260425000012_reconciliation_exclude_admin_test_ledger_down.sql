-- Down: scrubbed test ledger rows are not restored. Function bodies revert
-- when 20260425000011 is re-applied (which restores the prior is_test-aware
-- versions). Running this without 011 would leave the prior 20260420000001
-- bodies live.
SELECT 'noop'::text;
