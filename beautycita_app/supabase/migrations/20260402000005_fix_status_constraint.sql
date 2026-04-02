-- =============================================================================
-- Fix discovered_salons status constraint — canonical lifecycle
-- =============================================================================
--
-- Status lifecycle for discovered_salons:
--   discovered → selected → outreach_sent → registered (success)
--                                         → declined (rejected)
--                                         → unreachable (no contact)
--   (any) → duplicate (merged by dedup pipeline)
--
-- "discovered" is the default for all new salons (scraped, DENUE, etc.)
-- "selected" = chosen for outreach
-- "outreach_sent" = WhatsApp/call made
-- "registered" = salon signed up on BeautyCita
-- "declined" = salon said no
-- "unreachable" = can't contact
-- "duplicate" = merged into another record
--

ALTER TABLE discovered_salons DROP CONSTRAINT IF EXISTS discovered_salons_status_check;
ALTER TABLE discovered_salons ADD CONSTRAINT discovered_salons_status_check
  CHECK (status IN ('discovered', 'selected', 'outreach_sent', 'registered', 'declined', 'unreachable', 'duplicate'));

-- Also fix source constraint to include all sources
ALTER TABLE discovered_salons DROP CONSTRAINT IF EXISTS discovered_salons_source_check;
ALTER TABLE discovered_salons ADD CONSTRAINT discovered_salons_source_check
  CHECK (source IN ('google_maps', 'facebook', 'bing', 'foursquare', 'seccion_amarilla', 'denue', 'manual', 'scraper'));
