-- Phase 0: role-change two-step (request → superadmin approves).
-- Admin marks the request silently. Superadmin sees it in Operaciones → Cola → Cambios de rol.
-- No direct UPDATE path on profiles.role exists outside approve_role_change RPC.

CREATE TABLE IF NOT EXISTS public.role_change_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  target_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  requested_by uuid NOT NULL REFERENCES public.profiles(id),
  prior_role text NOT NULL,
  requested_role text NOT NULL,
  reason text,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected', 'cancelled')),
  approved_by uuid REFERENCES public.profiles(id),
  approval_note text,
  requested_at timestamptz NOT NULL DEFAULT now(),
  resolved_at timestamptz
);

CREATE INDEX IF NOT EXISTS idx_role_change_requests_pending
  ON public.role_change_requests(status, requested_at DESC)
  WHERE status = 'pending';

CREATE INDEX IF NOT EXISTS idx_role_change_requests_target
  ON public.role_change_requests(target_user_id, requested_at DESC);

ALTER TABLE public.role_change_requests ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "role_change_admin_read" ON public.role_change_requests;
CREATE POLICY "role_change_admin_read" ON public.role_change_requests
  FOR SELECT USING (public.is_admin());

-- No direct INSERT/UPDATE/DELETE policies — all writes go through the
-- two RPCs below (SECURITY DEFINER, with their own role + step-up checks).

-- mark_role_change_request: admin or superadmin marks a request.
-- Returns the new request id. Idempotent on (target_user_id, requested_role)
-- where status='pending' — clicking twice doesn't create duplicates.
CREATE OR REPLACE FUNCTION public.mark_role_change_request(
  p_target_user_id uuid,
  p_requested_role text,
  p_reason text DEFAULT NULL
)
  RETURNS uuid
  LANGUAGE plpgsql SECURITY DEFINER
  SET search_path TO 'public'
AS $$
DECLARE
  v_caller uuid := auth.uid();
  v_caller_role text;
  v_prior_role text;
  v_existing_id uuid;
  v_new_id uuid;
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'auth required';
  END IF;

  SELECT role INTO v_caller_role FROM public.profiles WHERE id = v_caller;
  IF v_caller_role NOT IN ('admin', 'superadmin') THEN
    RAISE EXCEPTION 'forbidden: requires admin or superadmin';
  END IF;

  IF p_requested_role NOT IN ('customer', 'stylist', 'rp', 'ops_admin', 'admin', 'superadmin') THEN
    RAISE EXCEPTION 'invalid requested role: %', p_requested_role;
  END IF;

  SELECT role INTO v_prior_role FROM public.profiles WHERE id = p_target_user_id;
  IF v_prior_role IS NULL THEN
    RAISE EXCEPTION 'target user not found';
  END IF;

  IF v_prior_role = p_requested_role THEN
    RAISE EXCEPTION 'target user already has role %', p_requested_role;
  END IF;

  -- Idempotency: existing pending request for same (target, requested_role)?
  SELECT id INTO v_existing_id
  FROM public.role_change_requests
  WHERE target_user_id = p_target_user_id
    AND requested_role = p_requested_role
    AND status = 'pending'
  LIMIT 1;

  IF v_existing_id IS NOT NULL THEN
    RETURN v_existing_id;
  END IF;

  INSERT INTO public.role_change_requests
    (target_user_id, requested_by, prior_role, requested_role, reason)
  VALUES
    (p_target_user_id, v_caller, v_prior_role, p_requested_role, p_reason)
  RETURNING id INTO v_new_id;

  RETURN v_new_id;
END;
$$;

-- approve_role_change: superadmin only, requires fresh auth (≤5min).
-- Performs the actual UPDATE on profiles.role and stamps the request.
CREATE OR REPLACE FUNCTION public.approve_role_change(
  p_request_id uuid,
  p_decision text,                  -- 'approved' or 'rejected'
  p_note text DEFAULT NULL
)
  RETURNS void
  LANGUAGE plpgsql SECURITY DEFINER
  SET search_path TO 'public'
AS $$
DECLARE
  v_caller uuid := auth.uid();
  v_req record;
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'auth required';
  END IF;

  IF NOT public.is_superadmin() THEN
    RAISE EXCEPTION 'forbidden: superadmin only';
  END IF;

  IF NOT public.requires_fresh_auth(300) THEN
    RAISE EXCEPTION 'step_up_required: re-authenticate within last 5 minutes';
  END IF;

  IF p_decision NOT IN ('approved', 'rejected') THEN
    RAISE EXCEPTION 'invalid decision: %', p_decision;
  END IF;

  SELECT * INTO v_req FROM public.role_change_requests WHERE id = p_request_id FOR UPDATE;
  IF v_req IS NULL THEN
    RAISE EXCEPTION 'request not found';
  END IF;
  IF v_req.status <> 'pending' THEN
    RAISE EXCEPTION 'request already %', v_req.status;
  END IF;

  -- Self-approval guard: superadmin can't approve a request they created
  IF v_req.requested_by = v_caller THEN
    RAISE EXCEPTION 'cannot approve own role-change request';
  END IF;

  UPDATE public.role_change_requests
  SET status = p_decision,
      approved_by = v_caller,
      approval_note = p_note,
      resolved_at = now()
  WHERE id = p_request_id;

  IF p_decision = 'approved' THEN
    UPDATE public.profiles SET role = v_req.requested_role WHERE id = v_req.target_user_id;
    -- The audit_table_changes trigger on profiles fires here automatically.
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.mark_role_change_request(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.approve_role_change(uuid, text, text) TO authenticated;

COMMENT ON TABLE public.role_change_requests IS
  'Two-step role change: admin marks → superadmin approves with step-up auth. No direct UPDATE on profiles.role outside approve_role_change RPC.';
