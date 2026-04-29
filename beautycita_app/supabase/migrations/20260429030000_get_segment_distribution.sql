-- Aggregate segment counts from user_behavior_summaries server-side so the
-- admin intel page doesn't pull every row of the table to the client.
-- Bounded result + same audit/RLS posture as the rest of the trait RPCs.

CREATE OR REPLACE FUNCTION public.get_segment_distribution()
RETURNS TABLE(segment text, n bigint)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM profiles
    WHERE id = auth.uid() AND role IN ('admin', 'superadmin')
  ) THEN
    RAISE EXCEPTION 'Forbidden: admin role required';
  END IF;

  RETURN QUERY
  SELECT
    COALESCE(s.segment, 'unknown')::text AS segment,
    COUNT(*)::bigint AS n
  FROM user_behavior_summaries s
  GROUP BY COALESCE(s.segment, 'unknown')
  ORDER BY 2 DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.get_segment_distribution() FROM public;
GRANT EXECUTE ON FUNCTION public.get_segment_distribution() TO authenticated;

COMMENT ON FUNCTION public.get_segment_distribution() IS
  'Admin-only segment count aggregation. Bounds the admin intel page so it never scrolls every behavior summary across the wire.';
