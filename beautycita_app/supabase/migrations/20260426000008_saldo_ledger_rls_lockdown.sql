-- =============================================================================
-- SECURITY: saldo_ledger had RLS DISABLED — anon could read every user's
-- saldo history with just the anon key. Caught by BC Monitor's RLS sweep.
-- =============================================================================
-- Required policies:
--   - service_role: full access (RPCs use this)
--   - admin/superadmin: SELECT all
--   - user: SELECT own rows (user_id = auth.uid())
--   - NO public/anon access at all
-- =============================================================================

ALTER TABLE public.saldo_ledger ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS saldo_ledger_service ON public.saldo_ledger;
CREATE POLICY saldo_ledger_service ON public.saldo_ledger
  FOR ALL USING (auth.role() = 'service_role')
  WITH CHECK (auth.role() = 'service_role');

DROP POLICY IF EXISTS saldo_ledger_admin_read ON public.saldo_ledger;
CREATE POLICY saldo_ledger_admin_read ON public.saldo_ledger
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM public.profiles
              WHERE profiles.id = auth.uid()
                AND profiles.role IN ('admin','superadmin'))
  );

DROP POLICY IF EXISTS saldo_ledger_self_read ON public.saldo_ledger;
CREATE POLICY saldo_ledger_self_read ON public.saldo_ledger
  FOR SELECT USING (user_id = auth.uid());

COMMENT ON TABLE public.saldo_ledger IS
  'User saldo movement history. RLS-locked: service_role full, admins read all, users read own. Mutations only via increment_saldo() RPC (SECURITY DEFINER).';
