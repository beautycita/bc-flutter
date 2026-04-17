-- Enforce RFC format on WRITE only, without breaking UPDATEs on rows with legacy bad RFCs.
-- Mexican RFC formats (SAT):
--   Persona física:  4 letters + 6-digit date (YYMMDD) + 3 alphanumeric  → 13 chars
--   Persona moral:   3 letters + 6-digit date (YYMMDD) + 3 alphanumeric  → 12 chars
-- Letters: A-Z, Ñ, & (& is allowed in entity RFCs).
-- Uppercase only — trigger normalizes case.
--
-- NOTE: intentionally not using a table-level CHECK constraint. With CHECK + NOT VALID,
-- Postgres still re-checks the constraint on every UPDATE (of any column) against existing
-- rows. A trigger scoped to `of rfc` only fires when the RFC column itself is written,
-- so legacy malformed rows don't block unrelated updates.

create or replace function public.normalize_and_validate_rfc()
returns trigger language plpgsql as $$
begin
  if new.rfc is not null then
    new.rfc := upper(btrim(new.rfc));
    if new.rfc = '' then
      new.rfc := null;
    elsif new.rfc !~ '^[A-ZÑ&]{3,4}[0-9]{6}[A-Z0-9]{3}$' then
      raise exception 'RFC_INVALID_FORMAT: expected 12-13 chars (3-4 letters + YYMMDD + 3 alphanumeric), got: %', new.rfc
        using errcode = '23514';
    end if;
  end if;
  return new;
end $$;

drop trigger if exists businesses_normalize_rfc on public.businesses;
drop trigger if exists businesses_normalize_and_validate_rfc on public.businesses;

create trigger businesses_normalize_and_validate_rfc
  before insert or update of rfc on public.businesses
  for each row execute procedure public.normalize_and_validate_rfc();

-- If an earlier version of this migration (pre-fix) was partially applied and left a
-- table-level CHECK constraint behind, drop it idempotently.
alter table public.businesses
  drop constraint if exists businesses_rfc_format_check;

comment on function public.normalize_and_validate_rfc() is
  'Uppercase-normalize and validate Mexican RFC format on insert/update. '
  'Raises SQLSTATE 23514 (check_violation) with RFC_INVALID_FORMAT prefix on bad input. '
  'Legacy rows with malformed RFCs remain queryable and updatable (on other columns).';
