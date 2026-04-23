-- =============================================================================
-- Migration: 20260422000003_portfolio_overlays.sql
-- Description: Brand overlay support for portfolio photos/videos.
-- Stylists pick one of ~6 brand PNG stickers on the upload page, drag it
-- onto the media, and the {sticker_id, x_ratio, y_ratio, scale, rotation}
-- is persisted. Overlays are rendered at display time (CSS-positioned over
-- the image/video on the public salon page) — they are NOT burned into the
-- media. Keeps upload fast and avoids client-side ffmpeg.wasm.
-- =============================================================================

ALTER TABLE public.portfolio_photos
  ADD COLUMN IF NOT EXISTS overlays jsonb NOT NULL DEFAULT '[]'::jsonb;

COMMENT ON COLUMN public.portfolio_photos.overlays IS
  'Array of brand overlay stickers positioned on the media. Each entry: '
  '{sticker_id: string, x: number (0-1 ratio), y: number (0-1 ratio), '
  'scale: number (0.1-1.5, default 0.3), rotation?: number (degrees)}. '
  'Rendered as CSS-positioned <img> layers over the photo/video on the '
  'public salon page. Not burned into the media so the stylist can ship '
  'the portfolio entry fast without server-side encoding.';

-- Index only rows that actually have overlays (most won't early on)
CREATE INDEX IF NOT EXISTS idx_portfolio_photos_has_overlays
  ON public.portfolio_photos ((jsonb_array_length(overlays)))
  WHERE jsonb_array_length(overlays) > 0;

NOTIFY pgrst, 'reload schema';
