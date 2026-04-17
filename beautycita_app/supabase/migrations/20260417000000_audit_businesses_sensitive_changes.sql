-- Audit trail for sensitive business field changes.
-- Writes to existing audit_log table when any of these columns change:
--   beneficiary_name, rfc, clabe, bank_name, stripe_account_id, owner_id
-- Closes forensics gap: previously there was no history of who changed what on businesses.

create or replace function public.audit_businesses_sensitive_changes()
returns trigger language plpgsql security definer as $$
declare
  v_changes jsonb := '{}'::jsonb;
begin
  if new.beneficiary_name is distinct from old.beneficiary_name then
    v_changes := v_changes || jsonb_build_object(
      'beneficiary_name', jsonb_build_object('old', old.beneficiary_name, 'new', new.beneficiary_name)
    );
  end if;

  if new.rfc is distinct from old.rfc then
    v_changes := v_changes || jsonb_build_object(
      'rfc', jsonb_build_object('old', old.rfc, 'new', new.rfc)
    );
  end if;

  if new.clabe is distinct from old.clabe then
    v_changes := v_changes || jsonb_build_object(
      'clabe', jsonb_build_object('old', old.clabe, 'new', new.clabe)
    );
  end if;

  if new.bank_name is distinct from old.bank_name then
    v_changes := v_changes || jsonb_build_object(
      'bank_name', jsonb_build_object('old', old.bank_name, 'new', new.bank_name)
    );
  end if;

  if new.stripe_account_id is distinct from old.stripe_account_id then
    v_changes := v_changes || jsonb_build_object(
      'stripe_account_id', jsonb_build_object('old', old.stripe_account_id, 'new', new.stripe_account_id)
    );
  end if;

  if new.owner_id is distinct from old.owner_id then
    v_changes := v_changes || jsonb_build_object(
      'owner_id', jsonb_build_object('old', old.owner_id, 'new', new.owner_id)
    );
  end if;

  if v_changes <> '{}'::jsonb then
    insert into public.audit_log (admin_id, action, target_type, target_id, details)
    values (
      coalesce(auth.uid(), '00000000-0000-0000-0000-000000000000'::uuid),
      'business_sensitive_update',
      'business',
      new.id::text,
      v_changes
    );
  end if;

  return new;
end $$;

drop trigger if exists businesses_audit_sensitive on public.businesses;

create trigger businesses_audit_sensitive
  after update of beneficiary_name, rfc, clabe, bank_name, stripe_account_id, owner_id
  on public.businesses
  for each row execute procedure public.audit_businesses_sensitive_changes();
