DROP POLICY IF EXISTS saldo_ledger_service ON public.saldo_ledger;
DROP POLICY IF EXISTS saldo_ledger_admin_read ON public.saldo_ledger;
DROP POLICY IF EXISTS saldo_ledger_self_read ON public.saldo_ledger;
ALTER TABLE public.saldo_ledger DISABLE ROW LEVEL SECURITY;
