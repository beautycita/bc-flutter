-- Soft-delete support for chat threads (archive instead of hard delete)
ALTER TABLE chat_threads ADD COLUMN IF NOT EXISTS archived_at timestamptz;
