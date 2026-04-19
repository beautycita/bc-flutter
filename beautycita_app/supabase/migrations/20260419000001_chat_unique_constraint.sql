-- Chat unique constraint (2026-04-19, follow-up to ..._business_access)
--
-- PostgREST's `on_conflict=...` upsert flow needs a proper UNIQUE
-- constraint, not a partial index. The partial index added in the prior
-- migration was correct for data integrity but PostgREST can't infer
-- it. Replacing with `UNIQUE NULLS NOT DISTINCT` (Postgres 15+) so that:
--   • salon threads keyed on (user, 'salon', businessId::text) are unique
--   • AI threads keyed on (user, 'aphrodite'|'eros'|'support', NULL) are
--     also unique — NULLS NOT DISTINCT treats NULLs as equal, so each
--     user can have at most one aphrodite/eros/support thread.

BEGIN;

DROP INDEX IF EXISTS chat_threads_user_contact_uniq;

ALTER TABLE chat_threads
  ADD CONSTRAINT chat_threads_user_contact_uniq
  UNIQUE NULLS NOT DISTINCT (user_id, contact_type, contact_id);

COMMIT;
