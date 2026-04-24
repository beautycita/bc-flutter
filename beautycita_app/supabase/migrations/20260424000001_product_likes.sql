-- =============================================================================
-- Product "likes" — distinct from feed_saves (personal bookmarks)
-- =============================================================================
-- The heart on product cards previously mapped to feed_saves, which semantics-
-- wise is a user's own save/bookmark list. Kriket wants it reframed as a
-- public like — every tap increments a counter visible to all viewers,
-- one like per user per product (toggleable).
--
-- Keeps feed_saves intact (portfolio photos still bookmark there), adds a
-- dedicated product_likes dedup table + products.likes_count counter that
-- the toggle_product_like RPC maintains atomically.
-- =============================================================================

ALTER TABLE public.products
  ADD COLUMN IF NOT EXISTS likes_count int NOT NULL DEFAULT 0
  CHECK (likes_count >= 0);

CREATE TABLE IF NOT EXISTS public.product_likes (
  user_id    uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  product_id uuid NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, product_id)
);

CREATE INDEX IF NOT EXISTS idx_product_likes_product
  ON public.product_likes (product_id, created_at DESC);

ALTER TABLE public.product_likes ENABLE ROW LEVEL SECURITY;

-- Anyone authenticated can see who liked what (for counting + own-state checks).
-- INSERT/DELETE only for the acting user (enforced via RPC + RLS both).
CREATE POLICY "product_likes: authenticated read"
  ON public.product_likes
  FOR SELECT
  USING (auth.uid() IS NOT NULL);

CREATE POLICY "product_likes: user toggles own"
  ON public.product_likes
  FOR ALL
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- Toggle RPC — atomic insert-or-delete + counter update. Returns the new
-- (liked, likes_count) so the client can settle optimistic UI state.
CREATE OR REPLACE FUNCTION public.toggle_product_like(
  p_product_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_user_id     uuid := auth.uid();
  v_now_liked   boolean;
  v_new_count   int;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'authentication required';
  END IF;

  -- Try inserting first; if dup, delete instead.
  INSERT INTO public.product_likes (user_id, product_id)
  VALUES (v_user_id, p_product_id)
  ON CONFLICT (user_id, product_id) DO NOTHING
  RETURNING true INTO v_now_liked;

  IF v_now_liked IS NULL THEN
    -- Row already existed → this tap is an un-like
    DELETE FROM public.product_likes
    WHERE user_id = v_user_id AND product_id = p_product_id;
    v_now_liked := false;
    UPDATE public.products
    SET likes_count = GREATEST(likes_count - 1, 0)
    WHERE id = p_product_id
    RETURNING likes_count INTO v_new_count;
  ELSE
    UPDATE public.products
    SET likes_count = likes_count + 1
    WHERE id = p_product_id
    RETURNING likes_count INTO v_new_count;
  END IF;

  RETURN jsonb_build_object(
    'liked', v_now_liked,
    'likes_count', COALESCE(v_new_count, 0)
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.toggle_product_like(uuid) TO authenticated;

COMMENT ON TABLE  public.product_likes IS 'Per-user like dedup for products. Counter cached on products.likes_count.';
COMMENT ON FUNCTION public.toggle_product_like(uuid) IS 'Atomic like/unlike toggle; returns {liked, likes_count}.';
