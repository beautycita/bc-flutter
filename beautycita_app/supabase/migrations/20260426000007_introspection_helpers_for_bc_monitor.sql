-- =============================================================================
-- Introspection helpers for BC Monitor diagnostics
-- =============================================================================
-- BC Monitor's snapshot tests need read-only access to cron.job,
-- information_schema.triggers, and pg_constraint. These are not exposed to
-- PostgREST normally; we add SECURITY DEFINER wrappers that admin/superadmin
-- can call to assert structural invariants.
--
-- All helpers are read-only and return public data only (no row-level
-- secrets). Caller must be admin or superadmin (or service_role).
-- =============================================================================

-- ── list_active_cron_jobs ────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.list_active_cron_jobs()
RETURNS TABLE(jobid bigint, jobname text, schedule text, active boolean)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = cron, public, pg_temp
AS $$
BEGIN
  IF NOT (
    auth.role() = 'service_role'
    OR EXISTS (SELECT 1 FROM public.profiles
                WHERE id = auth.uid() AND role IN ('admin','superadmin'))
  ) THEN
    RAISE EXCEPTION 'admin or superadmin required';
  END IF;
  RETURN QUERY
    SELECT j.jobid, j.jobname::text, j.schedule::text, j.active
      FROM cron.job j;
END;
$$;
GRANT EXECUTE ON FUNCTION public.list_active_cron_jobs() TO authenticated;

-- ── list_cron_run_health ─────────────────────────────────────────────────────
-- Returns last successful run age for each cron job. Used to catch silent
-- cron stalls (job is scheduled but never fires successfully).
CREATE OR REPLACE FUNCTION public.list_cron_run_health()
RETURNS TABLE(
  jobname text,
  schedule text,
  last_succeeded_at timestamptz,
  last_attempted_at timestamptz,
  failures_24h bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = cron, public, pg_temp
AS $$
BEGIN
  IF NOT (
    auth.role() = 'service_role'
    OR EXISTS (SELECT 1 FROM public.profiles
                WHERE id = auth.uid() AND role IN ('admin','superadmin'))
  ) THEN
    RAISE EXCEPTION 'admin or superadmin required';
  END IF;
  RETURN QUERY
    SELECT
      j.jobname::text,
      j.schedule::text,
      MAX(d.start_time) FILTER (WHERE d.status = 'succeeded') AS last_succeeded_at,
      MAX(d.start_time) AS last_attempted_at,
      COUNT(*) FILTER (WHERE d.status != 'succeeded'
                        AND d.start_time > now() - interval '24 hours') AS failures_24h
    FROM cron.job j
    LEFT JOIN cron.job_run_details d ON d.jobid = j.jobid
    GROUP BY j.jobid, j.jobname, j.schedule;
END;
$$;
GRANT EXECUTE ON FUNCTION public.list_cron_run_health() TO authenticated;

-- ── list_active_triggers ─────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.list_active_triggers(p_tables text[])
RETURNS TABLE(
  event_object_table text,
  trigger_name text,
  enabled boolean,
  action_timing text,
  event_manipulation text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT (
    auth.role() = 'service_role'
    OR EXISTS (SELECT 1 FROM public.profiles
                WHERE id = auth.uid() AND role IN ('admin','superadmin'))
  ) THEN
    RAISE EXCEPTION 'admin or superadmin required';
  END IF;
  RETURN QUERY
    SELECT
      t.event_object_table::text,
      t.trigger_name::text,
      -- pg_trigger.tgenabled: 'O' = enabled, 'D' = disabled
      (pgt.tgenabled <> 'D') AS enabled,
      t.action_timing::text,
      t.event_manipulation::text
    FROM information_schema.triggers t
    JOIN pg_trigger pgt ON pgt.tgname = t.trigger_name
    JOIN pg_class c ON c.oid = pgt.tgrelid AND c.relname = t.event_object_table
    WHERE t.event_object_schema = 'public'
      AND t.event_object_table = ANY(p_tables)
      AND NOT pgt.tgisinternal;
END;
$$;
GRANT EXECUTE ON FUNCTION public.list_active_triggers(text[]) TO authenticated;

-- ── list_check_constraints ──────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.list_check_constraints(p_constraint_names text[])
RETURNS TABLE(
  table_name text,
  constraint_name text,
  check_clause text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT (
    auth.role() = 'service_role'
    OR EXISTS (SELECT 1 FROM public.profiles
                WHERE id = auth.uid() AND role IN ('admin','superadmin'))
  ) THEN
    RAISE EXCEPTION 'admin or superadmin required';
  END IF;
  RETURN QUERY
    SELECT
      cc.table_name::text,
      cc.constraint_name::text,
      ccu.check_clause::text
    FROM information_schema.constraint_column_usage cc
    JOIN information_schema.check_constraints ccu
      ON ccu.constraint_name = cc.constraint_name
     AND ccu.constraint_schema = cc.constraint_schema
    WHERE cc.constraint_schema = 'public'
      AND cc.constraint_name = ANY(p_constraint_names);
END;
$$;
GRANT EXECUTE ON FUNCTION public.list_check_constraints(text[]) TO authenticated;

-- ── list_ledger_columns ──────────────────────────────────────────────────────
-- Returns column type info for ledger tables so BC Monitor can detect type drift.
CREATE OR REPLACE FUNCTION public.list_ledger_columns(p_tables text[])
RETURNS TABLE(
  table_name text,
  column_name text,
  data_type text,
  is_nullable text,
  column_default text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT (
    auth.role() = 'service_role'
    OR EXISTS (SELECT 1 FROM public.profiles
                WHERE id = auth.uid() AND role IN ('admin','superadmin'))
  ) THEN
    RAISE EXCEPTION 'admin or superadmin required';
  END IF;
  RETURN QUERY
    SELECT
      c.table_name::text,
      c.column_name::text,
      c.data_type::text,
      c.is_nullable::text,
      c.column_default::text
    FROM information_schema.columns c
    WHERE c.table_schema = 'public'
      AND c.table_name = ANY(p_tables)
    ORDER BY c.table_name, c.ordinal_position;
END;
$$;
GRANT EXECUTE ON FUNCTION public.list_ledger_columns(text[]) TO authenticated;

-- ── list_rls_policies ────────────────────────────────────────────────────────
-- Returns RLS policy names for given tables. BC Monitor uses this to detect
-- silent policy removal that would open up a sensitive table.
CREATE OR REPLACE FUNCTION public.list_rls_policies(p_tables text[])
RETURNS TABLE(
  table_name text,
  policy_name text,
  roles text[],
  cmd text,
  permissive text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT (
    auth.role() = 'service_role'
    OR EXISTS (SELECT 1 FROM public.profiles
                WHERE id = auth.uid() AND role IN ('admin','superadmin'))
  ) THEN
    RAISE EXCEPTION 'admin or superadmin required';
  END IF;
  RETURN QUERY
    SELECT
      tablename::text,
      policyname::text,
      pg_policies.roles,
      cmd::text,
      permissive::text
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = ANY(p_tables);
END;
$$;
GRANT EXECUTE ON FUNCTION public.list_rls_policies(text[]) TO authenticated;
