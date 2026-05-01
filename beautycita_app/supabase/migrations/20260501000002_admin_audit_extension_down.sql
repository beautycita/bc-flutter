DROP TRIGGER IF EXISTS trg_audit_profiles ON public.profiles;
DROP TRIGGER IF EXISTS trg_audit_profiles_upd ON public.profiles;
DROP TRIGGER IF EXISTS trg_audit_businesses ON public.businesses;
DROP TRIGGER IF EXISTS trg_audit_businesses_upd ON public.businesses;
DROP TRIGGER IF EXISTS trg_audit_disputes ON public.disputes;
DROP TRIGGER IF EXISTS trg_audit_disputes_upd ON public.disputes;
DROP TRIGGER IF EXISTS trg_audit_appointments ON public.appointments;
DROP TRIGGER IF EXISTS trg_audit_discovered_salons ON public.discovered_salons;
DROP TRIGGER IF EXISTS trg_audit_app_config ON public.app_config;
DROP TRIGGER IF EXISTS trg_audit_notification_templates ON public.notification_templates;
DROP TRIGGER IF EXISTS trg_audit_service_profiles ON public.service_profiles;
DROP TRIGGER IF EXISTS trg_audit_engine_settings ON public.engine_settings;

DROP FUNCTION IF EXISTS public.audit_table_changes();
DROP FUNCTION IF EXISTS public.redact_audit_payload(text, jsonb);

DROP TABLE IF EXISTS public.audit_column_allowlist;
DROP TABLE IF EXISTS public.audit_log_failures;

ALTER TABLE public.audit_log
  DROP COLUMN IF EXISTS regulatory_hold,
  DROP COLUMN IF EXISTS after_data,
  DROP COLUMN IF EXISTS before_data,
  DROP COLUMN IF EXISTS actor_role;

DELETE FROM public.profiles WHERE id = '00000000-0000-0000-0000-000000000001'::uuid;
