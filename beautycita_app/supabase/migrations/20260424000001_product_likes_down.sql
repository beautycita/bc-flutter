DROP FUNCTION IF EXISTS public.toggle_product_like(uuid);
DROP TABLE IF EXISTS public.product_likes;
ALTER TABLE public.products DROP COLUMN IF EXISTS likes_count;
