-- =============================================================================
-- Allow admin/superadmin to INSERT and DELETE orders rows
-- =============================================================================
-- Customer orders normally land via Stripe webhook or future create-order
-- edge fn, and there's no authenticated INSERT policy — only service_role
-- can write. Admins need to be able to seed or reverse test orders (plus
-- any in-person manual entry tooling we might ship). Adds a role-gated
-- CRUD policy mirroring the gift_cards_owner pattern.
-- =============================================================================

CREATE POLICY "Orders: admin full access"
  ON public.orders
  FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = auth.uid()
        AND profiles.role = ANY (ARRAY['admin','superadmin'])
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = auth.uid()
        AND profiles.role = ANY (ARRAY['admin','superadmin'])
    )
  );
