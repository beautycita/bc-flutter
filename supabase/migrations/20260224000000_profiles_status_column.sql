-- Add status column to profiles for user management (active, suspended, archived)
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS status text NOT NULL DEFAULT 'active';

ALTER TABLE public.profiles
  DROP CONSTRAINT IF EXISTS profiles_status_check;

ALTER TABLE public.profiles
  ADD CONSTRAINT profiles_status_check CHECK (
    status IN ('active', 'suspended', 'archived')
  );

COMMENT ON COLUMN public.profiles.status IS 'Account status: active (default), suspended (temp ban), archived (soft delete)';
