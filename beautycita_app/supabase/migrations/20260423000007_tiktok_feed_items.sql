-- =============================================================================
-- TikTok feed for beautycita.com /explorar
-- =============================================================================
-- Web /explorar previously served a database-backed portfolio/product gallery,
-- but prod has very few authored rows so the page looked empty. Mobile
-- /explorar wraps a WebView around YouTube-Shorts hashtag searches — works
-- but is a parallel architecture no one can curate. This table powers a
-- third option: curated TikTok embeds, LATAM-ranked, category-filterable.
--
-- Video IDs and metadata are populated by a beautypi scraper (davidteather/
-- TikTok-Api behind Surfshark wg netns) OR by admins pasting TikTok URLs
-- into an admin panel. The client only renders iframes to the official
-- TikTok embed player (https://www.tiktok.com/embed/v2/<id>) — no scraping
-- from the browser, no TikTok account required.
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.tiktok_feed_items (
  video_id          text PRIMARY KEY,
  category          text NOT NULL,
  creator_handle    text,
  creator_region    text,
  caption           text,
  thumb_url         text,
  duration_sec      int,
  view_count        int,
  hashtags          text[] DEFAULT '{}'::text[],
  is_visible        boolean NOT NULL DEFAULT true,
  curator_note      text,
  fetched_at        timestamptz NOT NULL DEFAULT now(),
  last_verified_at  timestamptz NOT NULL DEFAULT now(),
  created_at        timestamptz NOT NULL DEFAULT now(),
  CHECK (category IN (
    'cabello','unas','pestanas','cejas','maquillaje','facial',
    'corporal','novias','hombres'
  )),
  CHECK (length(video_id) BETWEEN 6 AND 64)
);

CREATE INDEX IF NOT EXISTS idx_tiktok_feed_category_fetched
  ON public.tiktok_feed_items (category, fetched_at DESC)
  WHERE is_visible = true;
CREATE INDEX IF NOT EXISTS idx_tiktok_feed_region
  ON public.tiktok_feed_items (creator_region)
  WHERE is_visible = true;

ALTER TABLE public.tiktok_feed_items ENABLE ROW LEVEL SECURITY;

CREATE POLICY "tiktok_feed: public read visible"
  ON public.tiktok_feed_items
  FOR SELECT
  USING (is_visible = true);

CREATE POLICY "tiktok_feed: admin full access"
  ON public.tiktok_feed_items
  FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = auth.uid()
        AND profiles.role = ANY (ARRAY['admin','superadmin'])
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = auth.uid()
        AND profiles.role = ANY (ARRAY['admin','superadmin'])
    )
  );

-- Paginated feed RPC with LATAM-first ordering.
-- LATAM country codes are the Spanish-speaking Americas + Spain + US-hispanic
-- weight, ranked by how likely our clientele is to identify with the creator.
CREATE OR REPLACE FUNCTION public.get_tiktok_feed(
  p_category text DEFAULT NULL,
  p_cursor   timestamptz DEFAULT NULL,
  p_limit    int DEFAULT 20
)
RETURNS SETOF public.tiktok_feed_items
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT *
  FROM public.tiktok_feed_items
  WHERE is_visible = true
    AND (p_category IS NULL OR category = p_category)
    AND (p_cursor IS NULL OR fetched_at < p_cursor)
  ORDER BY
    CASE WHEN creator_region IN (
      'MX','CO','AR','CL','PE','ES','VE','EC','GT','CR',
      'DO','UY','BO','PY','SV','HN','NI','PA','CU','PR'
    ) THEN 0 ELSE 1 END,
    fetched_at DESC
  LIMIT LEAST(p_limit, 100);
$$;

GRANT EXECUTE ON FUNCTION public.get_tiktok_feed(text, timestamptz, int)
  TO anon, authenticated;

COMMENT ON TABLE  public.tiktok_feed_items IS 'Curated TikTok video IDs rendered in the /explorar feed via the official TikTok embed player.';
COMMENT ON FUNCTION public.get_tiktok_feed(text, timestamptz, int) IS 'Paginated LATAM-first feed cursor; pass the oldest fetched_at you have to get the next page.';
