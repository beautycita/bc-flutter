-- RPC function to atomically increment time inference correction counters
CREATE OR REPLACE FUNCTION increment_time_correction(
  p_service_type text,
  p_original_hour_range text,
  p_original_day_range text,
  p_correction_to text
) RETURNS void AS $$
BEGIN
  INSERT INTO time_inference_corrections (
    service_type, original_hour_range, original_day_range, correction_to,
    correction_count, total_bookings, correction_rate
  ) VALUES (
    p_service_type, p_original_hour_range, p_original_day_range, p_correction_to,
    1, 1, 1.0
  )
  ON CONFLICT (service_type, original_hour_range, original_day_range, correction_to)
  DO UPDATE SET
    correction_count = time_inference_corrections.correction_count + 1,
    total_bookings = time_inference_corrections.total_bookings + 1,
    correction_rate = (time_inference_corrections.correction_count + 1)::numeric /
                      (time_inference_corrections.total_bookings + 1)::numeric,
    updated_at = now();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
