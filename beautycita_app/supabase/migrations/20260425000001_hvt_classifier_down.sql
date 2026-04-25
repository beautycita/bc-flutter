DROP TRIGGER IF EXISTS tier_assignment_sync ON public.discovered_salon_tier_assignments;
DROP FUNCTION IF EXISTS public.sync_current_tier_assignment();
DROP FUNCTION IF EXISTS public.detect_same_owner_siblings(uuid);
DROP FUNCTION IF EXISTS public.count_salons_per_tier();

DROP INDEX IF EXISTS public.idx_tier_assignment_one_current_per_salon;
DROP INDEX IF EXISTS public.idx_tier_assignment_history;
DROP INDEX IF EXISTS public.idx_discovered_salons_tier;
DROP INDEX IF EXISTS public.idx_discovered_salons_hvt_score;

DROP POLICY IF EXISTS "tier_assignments: admin write" ON public.discovered_salon_tier_assignments;
DROP POLICY IF EXISTS "tier_assignments: admin read" ON public.discovered_salon_tier_assignments;
DROP POLICY IF EXISTS "tiers: superadmin all" ON public.discovered_salon_tiers;
DROP POLICY IF EXISTS "tiers: read by anyone authed" ON public.discovered_salon_tiers;

-- Drop the assignments table first (FKs to both other tables), then the
-- signal columns on discovered_salons (their tier_id FK references
-- discovered_salon_tiers), then the tiers table itself. Doing this in any
-- other order trips check_violation against a still-attached FK.
DROP TABLE IF EXISTS public.discovered_salon_tier_assignments;

ALTER TABLE public.discovered_salons
  DROP COLUMN IF EXISTS tier_classified_at,
  DROP COLUMN IF EXISTS tier_locked,
  DROP COLUMN IF EXISTS press_mentions,
  DROP COLUMN IF EXISTS social_followers,
  DROP COLUMN IF EXISTS reputation_score,
  DROP COLUMN IF EXISTS reputation_signal_count,
  DROP COLUMN IF EXISTS years_in_business,
  DROP COLUMN IF EXISTS owner_chain_size,
  DROP COLUMN IF EXISTS hvt_score,
  DROP COLUMN IF EXISTS tier_id;

DROP TABLE IF EXISTS public.discovered_salon_tiers;

DELETE FROM public.app_config WHERE key IN (
  'hvt_weight_chain','hvt_weight_years','hvt_weight_reputation',
  'hvt_weight_social','hvt_weight_press',
  'hvt_threshold_t1','hvt_threshold_t2','hvt_threshold_t3',
  'hvt_threshold_t4','hvt_threshold_t5','hvt_autolock_top_tiers'
);
