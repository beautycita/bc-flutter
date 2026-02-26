-- Add unique index on time_inference_corrections for upsert in curate-results
CREATE UNIQUE INDEX IF NOT EXISTS time_inference_corrections_unique
  ON time_inference_corrections (service_type, original_hour_range, original_day_range, correction_to);
