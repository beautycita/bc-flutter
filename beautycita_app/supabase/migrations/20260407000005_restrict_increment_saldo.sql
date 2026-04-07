-- =============================================================================
-- Restrict increment_saldo: only callable by other SECURITY DEFINER functions
-- or by the user on their own account. Prevents arbitrary saldo manipulation.
-- =============================================================================

CREATE OR REPLACE FUNCTION public.increment_saldo(
  p_user_id uuid,
  p_amount  numeric
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Only allow: (1) calls from other SECURITY DEFINER functions (auth.uid() is null)
  -- or (2) user adjusting their own saldo, or (3) admin
  IF auth.uid() IS NOT NULL
     AND auth.uid() != p_user_id
     AND NOT is_admin() THEN
    RAISE EXCEPTION 'No autorizado para modificar saldo de otro usuario';
  END IF;

  UPDATE public.profiles
  SET saldo = COALESCE(saldo, 0) + p_amount,
      updated_at = now()
  WHERE id = p_user_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Usuario no encontrado: %', p_user_id;
  END IF;
END;
$$;
