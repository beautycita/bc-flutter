-- SECURITY DEFINER helper so admin direct writes (booking cancel from
-- booking_detail_panel.dart, salon verify toggle from salon_detail_panel.dart)
-- can append to public.audit_log without exposing the table to direct
-- authenticated INSERT (which would let non-admins forge entries).

CREATE OR REPLACE FUNCTION public.log_admin_action(
  p_action      text,
  p_target_type text,
  p_target_id   text,
  p_details     jsonb DEFAULT '{}'::jsonb
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_role text;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'AUTH_REQUIRED' USING ERRCODE = '42501';
  END IF;

  SELECT role INTO v_role FROM public.profiles WHERE id = auth.uid();
  IF v_role NOT IN ('admin', 'superadmin') THEN
    RAISE EXCEPTION 'ADMIN_REQUIRED' USING ERRCODE = '42501';
  END IF;

  INSERT INTO public.audit_log (admin_id, action, target_type, target_id, details)
  VALUES (auth.uid(), p_action, p_target_type, p_target_id, COALESCE(p_details, '{}'::jsonb));
END;
$$;

REVOKE ALL ON FUNCTION public.log_admin_action(text, text, text, jsonb) FROM public;
GRANT EXECUTE ON FUNCTION public.log_admin_action(text, text, text, jsonb) TO authenticated;

COMMENT ON FUNCTION public.log_admin_action(text, text, text, jsonb) IS
  'Append a single audit_log row attributed to the calling admin. Rejects if caller is not admin/superadmin.';
