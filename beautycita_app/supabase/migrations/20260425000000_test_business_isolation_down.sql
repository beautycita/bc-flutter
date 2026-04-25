DROP TRIGGER IF EXISTS businesses_auto_mark_test ON public.businesses;
DROP FUNCTION IF EXISTS public.auto_mark_test_business();
DROP TRIGGER IF EXISTS commission_records_reject_test_business ON public.commission_records;
DROP TRIGGER IF EXISTS tax_withholdings_reject_test_business ON public.tax_withholdings;
DROP FUNCTION IF EXISTS public.reject_test_business_ledger_writes();
DROP INDEX IF EXISTS public.idx_businesses_is_test;
ALTER TABLE public.businesses DROP COLUMN IF EXISTS is_test;
