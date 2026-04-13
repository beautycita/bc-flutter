-- Enable RLS on automated_message_log
-- Policies already existed but RLS was not enabled, making them dead code.
ALTER TABLE automated_message_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE automated_message_log FORCE ROW LEVEL SECURITY;
