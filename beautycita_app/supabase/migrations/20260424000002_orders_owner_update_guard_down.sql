DROP TRIGGER IF EXISTS orders_owner_update_guard_tg ON public.orders;
DROP FUNCTION IF EXISTS public.orders_owner_update_guard();
