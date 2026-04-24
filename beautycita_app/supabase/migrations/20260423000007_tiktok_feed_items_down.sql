-- Rollback TikTok feed table + RPC.
DROP FUNCTION IF EXISTS public.get_tiktok_feed(text, timestamptz, int);
DROP TABLE IF EXISTS public.tiktok_feed_items;
