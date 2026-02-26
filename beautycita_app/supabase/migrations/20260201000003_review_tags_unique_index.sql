-- Add unique index on review_tags.review_id to support upsert in tag-review function
CREATE UNIQUE INDEX IF NOT EXISTS review_tags_review_id_unique
  ON review_tags (review_id);
