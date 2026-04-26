-- Restore the wide-open atal_service + qr_sessions_select_pending policies.
DROP POLICY IF EXISTS atal_service ON public.admin_trait_access_log;
CREATE POLICY atal_service ON public.admin_trait_access_log
  FOR ALL USING (true);

DROP POLICY IF EXISTS qr_sessions_select_pending ON public.qr_auth_sessions;
CREATE POLICY qr_sessions_select_pending ON public.qr_auth_sessions
  FOR SELECT USING (status = 'pending' AND expires_at > now());
