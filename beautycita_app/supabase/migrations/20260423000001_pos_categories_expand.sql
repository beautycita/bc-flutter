-- =============================================================================
-- POS category expansion — 10 → 16 categories
-- =============================================================================
-- Audit doc: /home/bc/futureBeauty/docs/plans/2026-04-22-pos-audit.md Part 2
-- Keeps all 10 existing cosmetic categories, adds 6 beauty-adjacent:
-- hair_tools, nail_tools, hair_accessories, jewelry, bags, apparel.
-- Explicit prohibition text lives in ToS §4c (mobile + web).
-- =============================================================================

ALTER TABLE public.products DROP CONSTRAINT IF EXISTS products_category_check;

ALTER TABLE public.products ADD CONSTRAINT products_category_check CHECK (
  category IN (
    'perfume', 'lipstick', 'powder', 'serums', 'cleansers',
    'shampoo', 'scrubs', 'moisturisers', 'body_wash', 'foundation',
    'hair_tools', 'nail_tools', 'hair_accessories',
    'jewelry', 'bags', 'apparel'
  )
);
