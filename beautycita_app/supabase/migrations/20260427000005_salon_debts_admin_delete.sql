-- salon_debts allowed admins to SELECT but not UPDATE/DELETE — only the
-- service_role could write. The hunter flow `salon-cancel-order-full`
-- relied on cleaning up its own debt row via pgDelete, but PostgREST
-- silently returned 204 because RLS hid the row from admin DELETE.
-- Result: every passing run still left an orphan salon_debts row, which
-- in turn FK-blocked the orders DELETE, leaking 250 MXN of "received"
-- revenue per run into the test partner business.
--
-- Admins legitimately need to be able to cancel/clear debts from the
-- admin panel (debt-collection workflow, error correction, test
-- residue). Add explicit DELETE + UPDATE policies for admin/superadmin.

CREATE POLICY salon_debts_admin_delete
  ON public.salon_debts
  FOR DELETE
  TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.profiles
             WHERE profiles.id = auth.uid()
               AND profiles.role IN ('admin','superadmin'))
  );

CREATE POLICY salon_debts_admin_update
  ON public.salon_debts
  FOR UPDATE
  TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.profiles
             WHERE profiles.id = auth.uid()
               AND profiles.role IN ('admin','superadmin'))
  )
  WITH CHECK (
    EXISTS (SELECT 1 FROM public.profiles
             WHERE profiles.id = auth.uid()
               AND profiles.role IN ('admin','superadmin'))
  );
