# Payout Beneficiary Lock — Policy, Legalese & Engineering Spec

**Status:** Draft — pending Mexican attorney review before publication
**Decision ref:** Doc decision #13 (2026-04-17)
**Finding ref:** Doc finding #186 (sidebar orphan)
**Queue ref:** Doc queue #27

---

## 1. Legal note before publication

This document drafts (a) a ToS amendment clause and (b) an inline banking-page disclosure intended to be legally binding on salon operators (merchants) under Mexican commercial law. I am not a Mexican attorney. Before publishing this text:

- **Have a Mexican commercial attorney review the arbitration clause.** Commercial arbitration between merchants is enforceable under Art. 1415–1480 of the Código de Comercio, but the clause must clearly designate arbitrators or the appointment mechanism, the seat, the procedure, and the language. The draft below follows these conventions, but an attorney should confirm.
- **Existing ToS already contains a unilateral-modification clause.** Art. 18 of the current `terminos_page.dart` reserves the right to modify terms with notification. Adding this clause is therefore permitted, provided the notification mechanism (in-app banner + email + WhatsApp) is executed before enforcement.
- **This clause is for merchant (salon) accounts only.** It should be placed in a section scoped to businesses / establecimientos and should not apply to consumer bookings.

---

## 2. ToS Amendment — Spanish Formal Register

Add as a new clause in `beautycita_web/lib/pages/public/terminos_page.dart` after the existing section on business obligations. The mobile app equivalent in `beautycita_app/lib/screens/about_screen.dart` (or wherever the ToS is rendered) must also be updated.

**Title:** *CLÁUSULA — CUENTA BANCARIA DE BENEFICIARIO, PAGOS Y RESOLUCIÓN DE CONTROVERSIAS*

> **§ 1. Identificación del Beneficiario.** Al momento de registrar un negocio en la Plataforma, el Establecimiento proporciona los siguientes datos fiscales y bancarios que en lo sucesivo constituirán la *Identidad del Beneficiario*: (i) el nombre completo del titular de la cuenta bancaria designada para recibir los pagos ("Nombre del Beneficiario"); y (ii) el Registro Federal de Contribuyentes ("RFC") del mismo titular. El Establecimiento declara, bajo protesta de decir verdad, que el Nombre del Beneficiario y el RFC proporcionados corresponden de manera inequívoca a la persona física o moral titular de la cuenta bancaria designada.
>
> **§ 2. Correspondencia Obligatoria en los Pagos.** BeautyCita S.A. de C.V. (en lo sucesivo "la Plataforma") únicamente realizará dispersiones, liquidaciones, transferencias o retiros de fondos ("Pagos") a cuentas bancarias cuyo titular coincida con la Identidad del Beneficiario registrada. La Plataforma se reserva el derecho de verificar, por los medios que estime pertinentes, incluyendo cotejo directo con la institución bancaria receptora o con el Servicio de Administración Tributaria (SAT), que el Nombre del Beneficiario y el RFC declarados correspondan a la cuenta bancaria designada antes de ejecutar cualquier Pago.
>
> **§ 3. Suspensión Automática por Modificación de Datos.** Cualquier modificación del Nombre del Beneficiario o del RFC en el perfil del Establecimiento suspenderá automática e inmediatamente todos los Pagos pendientes y programados, sin necesidad de notificación adicional. La suspensión permanecerá vigente hasta que el administrador designado por la Plataforma verifique y autorice expresamente la nueva Identidad del Beneficiario mediante resolución formal. La Plataforma no será responsable por retrasos en los Pagos derivados de dicha suspensión.
>
> **§ 4. Quejas de Terceros y Facultad de Cancelación.** En caso de que cualquier tercero, incluyendo pero no limitado a clientes, autoridades, instituciones financieras o titulares originales de la cuenta bancaria, presente una queja formal que alegue que un Pago fue realizado a una cuenta cuyo titular no corresponde a la Identidad del Beneficiario declarada, la Plataforma, a su entera y única discreción, y sin necesidad de demostrar la veracidad de la queja, podrá cancelar la cuenta del Establecimiento en cualquier momento y por cualquier motivo. El Establecimiento renuncia expresamente a cualquier derecho de acción derivado de dicha cancelación, salvo el derecho de apelación establecido en la cláusula § 5 siguiente.
>
> **§ 5. Arbitraje — Panel de Apelación.** El Establecimiento podrá apelar la cancelación prevista en la cláusula § 4 anterior mediante solicitud por escrito dirigida a *apelaciones@beautycita.com* dentro de los **diez (10) días naturales** siguientes a la notificación de la cancelación. La apelación será resuelta por un **Panel Arbitral** integrado por tres (3) personas designadas por la Plataforma en el momento de presentarse la controversia, ninguna de las cuales podrá ser empleado en activo de la Plataforma directamente involucrado en la transacción o queja objeto de la apelación. El Panel resolverá conforme a los principios de buena fe mercantil, las disposiciones aplicables del Código de Comercio de los Estados Unidos Mexicanos, y la sana crítica. El procedimiento se sustanciará por escrito, en idioma español, con sede en la Ciudad de México. **La resolución del Panel será final, inapelable, y vinculante para ambas partes**, en términos del artículo 1423 y demás aplicables del Código de Comercio. Las partes renuncian expresamente a cualquier recurso judicial ordinario o extraordinario en contra de dicha resolución, salvo la acción de nulidad prevista en el artículo 1457 del Código de Comercio.
>
> **§ 6. Consecuencias de la Cancelación.** Cancelada la cuenta del Establecimiento conforme a la cláusula § 4, ya sea sin apelación o con apelación resuelta en favor de la Plataforma, procederá lo siguiente, sin necesidad de ulterior declaración: (a) cualquier saldo positivo a favor del Establecimiento mantenido en la Plataforma, en cualquier denominación ("Saldo"), será remitido en su totalidad a la Plataforma como compensación por los gastos administrativos, de verificación y de resolución de controversias derivados de la cancelación, y por los posibles daños reputacionales ocasionados; y (b) cualquier adeudo pendiente del Establecimiento frente a la Plataforma ("Deuda") quedará extinguido en su totalidad, quedando la Plataforma impedida de reclamar dicha Deuda por cualquier vía posterior a la cancelación. Las partes reconocen que el remate del Saldo y la extinción de la Deuda constituyen una compensación íntegra y final de todas las obligaciones recíprocas nacidas del presente contrato en relación con dichos rubros.
>
> **§ 7. Naturaleza y Validez.** El Establecimiento reconoce haber leído, comprendido y aceptado las disposiciones de la presente cláusula, así como su carácter de condición esencial del contrato con la Plataforma. La nulidad o inaplicabilidad de cualquier disposición contenida en esta cláusula no afectará la validez del resto del contrato ni de las demás disposiciones de la presente cláusula, las cuales permanecerán en pleno vigor y efecto.

---

## 3. Banking Page Inline Disclosure — Spanish Plain

Displayed as a modal dialog in `beautycita_web/lib/pages/business/biz_banking_page.dart` whenever the user attempts to edit `beneficiary_name` or (in a future field) `rfc`. Mandatory acknowledgment checkbox; save blocked until checked.

**Modal title:** *Confirmar cambio en datos de pago*

**Modal body:**

> **Importante.** Estás a punto de modificar el **Nombre del Beneficiario** o el **RFC** asociado a tu cuenta bancaria para recibir pagos de BeautyCita.
>
> Al confirmar este cambio:
>
> 1. **Se suspenderán inmediatamente todos los pagos** pendientes y programados hacia tu cuenta hasta que un administrador verifique y autorice la nueva información. Este proceso puede tardar entre 24 y 72 horas hábiles.
> 2. **La nueva cuenta bancaria debe pertenecer a la misma persona o empresa** cuyo nombre y RFC declares en este formulario. BeautyCita únicamente transferirá fondos a cuentas cuyo titular coincida con los datos que tengamos registrados.
> 3. **Si alguien reclama posteriormente** que enviaste pagos a una cuenta que no corresponde al titular original, BeautyCita puede cancelar tu cuenta por cualquier motivo, a nuestra entera discreción.
> 4. **En caso de cancelación**, cualquier saldo a tu favor en la Plataforma se retiene como compensación, y cualquier deuda que tengas con BeautyCita queda extinguida. La decisión puede apelarse ante un Panel Arbitral de tres personas designadas por BeautyCita; su resolución es final.
>
> [ ] **He leído y acepto** estas condiciones y los [Términos y Condiciones completos](/terminos#cuenta-bancaria).
>
> **[Cancelar]**   **[Confirmar cambio]** *(deshabilitado hasta marcar la casilla)*

---

## 4. Engineering Spec

### 4.1 Database

**New table:** `payout_holds`

```sql
create table public.payout_holds (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  reason text not null check (reason in (
    'beneficiary_name_changed',
    'rfc_changed',
    'identity_mismatch',
    'third_party_complaint',
    'manual_admin'
  )),
  old_value text,
  new_value text,
  started_at timestamptz not null default now(),
  released_at timestamptz,
  released_by uuid references public.profiles(id),
  release_note text,
  created_at timestamptz not null default now()
);

create index payout_holds_business_active_idx
  on public.payout_holds (business_id)
  where released_at is null;

alter table public.payout_holds enable row level security;
create policy "admin read payout_holds" on public.payout_holds
  for select using (auth.role_is('admin') or auth.role_is('superadmin'));
create policy "business read own payout_holds" on public.payout_holds
  for select using (business_id in (select id from public.businesses where owner_id = auth.uid()));
```

**Trigger:** freeze on identity change

```sql
create or replace function public.freeze_payouts_on_identity_change()
returns trigger language plpgsql security definer as $$
begin
  if (new.beneficiary_name is distinct from old.beneficiary_name) then
    insert into public.payout_holds (business_id, reason, old_value, new_value)
    values (new.id, 'beneficiary_name_changed', old.beneficiary_name, new.beneficiary_name);
  end if;
  if (new.rfc is distinct from old.rfc) then
    insert into public.payout_holds (business_id, reason, old_value, new_value)
    values (new.id, 'rfc_changed', old.rfc, new.rfc);
  end if;
  return new;
end $$;

create trigger businesses_freeze_payouts_on_identity_change
  after update of beneficiary_name, rfc on public.businesses
  for each row execute procedure public.freeze_payouts_on_identity_change();
```

**Helper function:** check if business has active hold

```sql
create or replace function public.has_active_payout_hold(p_business_id uuid)
returns boolean language sql stable as $$
  select exists (
    select 1 from public.payout_holds
    where business_id = p_business_id and released_at is null
  )
$$;
```

### 4.2 Edge function — `payout-identity-check`

New function at `beautycita_app/supabase/functions/payout-identity-check/index.ts`. Invoked before any payout is scheduled (Stripe payout, saldo withdrawal, refund reversal). Returns `{ ok: boolean, reason?: string }`.

Behavior:
1. Load business record: `beneficiary_name`, `rfc`, `clabe`.
2. Check `has_active_payout_hold(business_id)` — if true, return `{ ok: false, reason: 'active_hold' }`.
3. Retrieve destination account holder name from CLABE lookup (STP API or bank-side verification, TBD with BBVA meeting).
4. Compare RFC: **exact match required**. If mismatch → insert `payout_holds` row with `reason='identity_mismatch'`, return `{ ok: false }`.
5. Compare Nombre del Beneficiario:
   - Normalize: uppercase, strip accents, strip "S.A. de C.V." and similar corporate suffixes (compare with + without).
   - Compute Jaro-Winkler similarity.
   - **If ≥ 0.90 → pass automatically.**
   - **If 0.80–0.90 → insert hold with `reason='identity_mismatch'`, require admin review.**
   - **If < 0.80 → hard fail, insert hold.**
6. Log result to `payout_identity_checks` (new table: business_id, checked_at, rfc_match, name_score, result).

### 4.3 Admin action — release payout hold

New admin UI at `/admin/operations/payout-holds` (or in `/admin/finance`). Lists all active holds with business name, reason, old/new values, duration. Action: **Liberar** → requires note field → sets `released_at` + `released_by` + `release_note`.

RPC: `release_payout_hold(p_hold_id uuid, p_note text)` — admin-only, updates row, writes to `admin_audit_log`.

### 4.4 Business sidebar — resolve finding #186

In `beautycita_web/lib/widgets/business_sidebar.dart`, add `_NavItem` between **Ordenes** and **Portafolio** (logical placement — financial flow):

```dart
_NavItem(label: 'Banco', icon: Icons.account_balance_outlined, route: WebRoutes.negocioBanking),
```

Badge should display when `has_active_payout_hold(business_id) == true` — red dot or warning icon — so owners immediately see their payouts are frozen.

### 4.5 Onboarding flow — banking as required step

Update `beautycita_app/lib/providers/onboarding_step_provider.dart` (or equivalent) to append `'banking'` to the step sequence: `profile → services → schedule → stripe → banking → complete`.

Update role-based router redirect in `beautycita_web/lib/config/router.dart` at line 199 to check: if role is business/stylist AND `banking_complete = false` AND destination is a payout-gated route, redirect to `/negocio/banking`.

Add guard in payout scheduling RPCs (`process_commission_payout`, `release_escrow`, saldo-withdrawal flow): reject with `P0001` error if `has_active_payout_hold(business_id)` returns true.

### 4.6 Debt categorization — SAT reporting of extinguished and pursued debt

The ToS § 6 extinguishes the salon's "Deuda" on cancellation. For SAT reporting this event must be properly categorized, and separately, when operational debt is actively pursued but unlikely to be collected, it must be trackable to support the Art. 27 LISR fracción XV incobrable deduction procedure.

Verify `salon_debts` has a `debt_type` column; add if missing:

```sql
alter table public.salon_debts
  add column if not exists debt_type text not null default 'operational_commission'
  check (debt_type in (
    'operational_commission',      -- commission owed
    'operational_refund_pos',      -- POS return shortfall
    'operational_saldo_overdraft', -- saldo went negative
    'pursued_doubtful'             -- being pursued but unlikely to collect; Art. 27 XV candidate
  ));

create index if not exists salon_debts_business_type_status_idx
  on public.salon_debts (business_id, debt_type, status);
```

**Cancellation trigger:** `cancel_business_account` (or its admin RPC equivalent) extinguishes outstanding debt per ToS § 6(b):

```sql
update public.salon_debts
set status = 'extinguished_on_cancellation',
    extinguished_at = now(),
    extinguished_reason = 'account_cancelled_per_tos_clause_6b'
where business_id = p_business_id
  and status = 'outstanding';
```

**SAT reporter:** extend `supabase/functions/sat-reporting/index.ts` to emit two categorized sub-reports:

1. **Saldo remitido (ToS § 6a):** business_id, amount, cancelled_at, rfc. Reported as extraordinary income to BeautyCita (ingreso por cancelación contractual).
2. **Deuda extinguida (ToS § 6b):** business_id, total extinguished, cancelled_at. Fiscal characterization (waiver / bonification / Art. 27 LISR XV incobrable) needs accountant sign-off — drives the CFDI type + the fraction of LISR Art. 27 cited.
3. **Pursued doubtful (operational):** rows tagged `debt_type='pursued_doubtful'` that meet Art. 27 LISR XV criteria (≥ 1 year past due + documented collection pursuit) can be claimed as incobrable deductions. Reporter emits a separate section listing candidates; accountant confirms before filing.

### 4.7 Migration of existing businesses

Existing salons accepted the older ToS. One-time migration:

1. Add column `businesses.payout_lock_clause_accepted_at timestamptz`.
2. On first login after deploy, show a blocking modal to business-role users: "Hemos actualizado nuestros términos" → shows the new clause → requires acceptance checkbox → sets timestamp.
3. Block payout scheduling for any business with `payout_lock_clause_accepted_at is null` AND `created_at < deploy_date`.
4. Email + WhatsApp notification 7 days before enforcement date.

---

## 5. Build sequence (recommended order)

1. DB migration — `payout_holds` + trigger + helper function.
2. Edge function `payout-identity-check` (returns deterministic response based on stored data; CLABE-side lookup can be stubbed until BBVA meeting).
3. Banking page update — inline disclosure modal + RFC field (if not already editable there).
4. Business sidebar — add Banco nav item with hold-indicator badge.
5. Admin hold-management page.
6. Onboarding flow — append banking step, router guard.
7. Payout RPC guards — reject on active hold.
8. ToS page update — add the new clause.
9. Existing-salon migration modal + notification campaign.
10. Backfill: for any `businesses` row where `beneficiary_name is null or rfc is null`, enqueue a payout_hold with `reason='manual_admin'` until data is supplied.

---

## 6. Open items before deploy

- [ ] Mexican attorney review of § 1–7 ToS clause.
- [ ] Confirm CLABE-based destination-holder lookup feasibility (STP API vs. SAT? Part of BBVA meeting.)
- [ ] Decide if mobile app must also render the inline disclosure modal (likely yes, same copy).
- [ ] Notification copy for the 7-day pre-enforcement campaign (email + WhatsApp templates — reuse `notification-templates` infra).
- [ ] Privacy page update: RFC + beneficiary_name are personal data under LFPDPPP; disclose that we store + verify them for payout identity matching (should already be covered by existing fiscal-data disclosure — confirm).
- [ ] **Accountant sign-off on SAT treatment** of extinguished Deuda (waiver vs. incobrable vs. bonification) — drives which CFDI type + which fraction of LISR Art. 27 we cite in the reporter.

---

*End of policy document.*
