-- =============================================================================
-- Migration: 20260420000003_drop_duplicate_user_fks.sql
-- Description: Four tables have duplicate FKs on the same column referencing
-- BOTH public.profiles(id) AND auth.users(id). PostgREST embeds become
-- ambiguous in this state and either return errors or silently pick the
-- wrong join target. Same failure mode as portfolio_photos.business_id.
--
-- profiles.id is itself FK'd to auth.users.id, so the auth.users FK on each
-- of these columns is redundant — dropping it preserves referential
-- integrity (profiles is the chain) and resolves the ambiguity.
--
-- Tables affected:
--   appointments.user_id  drop appointments_user_id_fkey  keep appointments_user_id_profiles_fkey
--   audit_log.admin_id    drop audit_log_admin_id_fkey    keep fk_audit_log_admin
--   businesses.owner_id   drop businesses_owner_id_fkey   keep fk_businesses_owner
--   disputes.user_id      drop disputes_user_id_fkey      keep disputes_user_id_profiles_fkey
-- =============================================================================

ALTER TABLE public.appointments DROP CONSTRAINT IF EXISTS appointments_user_id_fkey;
ALTER TABLE public.audit_log    DROP CONSTRAINT IF EXISTS audit_log_admin_id_fkey;
ALTER TABLE public.businesses   DROP CONSTRAINT IF EXISTS businesses_owner_id_fkey;
ALTER TABLE public.disputes     DROP CONSTRAINT IF EXISTS disputes_user_id_fkey;

NOTIFY pgrst, 'reload schema';
