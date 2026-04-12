# Test Findings Fix Plan — 2026-04-12

Generated from Doc queue items #3–#7 (findings #117–#122).
Priority: critical fixes first, then hardening.

---

## Phase 1: Critical Runtime Bugs (fix before any deploy)

### 1.1 stripe-webhook calculate_payout_with_debt arg mismatch
**Finding #117 | Queue #3 | Priority: 20 | CRITICAL**

**Problem:** `stripe-webhook/index.ts:418` calls `calculate_payout_with_debt` with 5 args:
```ts
{ p_business_id, p_gross_amount, p_commission, p_iva_withheld, p_isr_withheld }
```
But the RPC in `20260410000001_missing_financial_tables.sql:78` only accepts 2:
```sql
calculate_payout_with_debt(p_business_id uuid, p_gross_payout numeric)
```

**Impact:** Every Stripe payment that triggers debt collection will throw a PostgreSQL error. The booking payment itself succeeds (it's a separate step), but debt recovery silently fails.

**Fix:**
1. Verify which signature exists on production DB:
   ```bash
   ssh www-bc "docker exec supabase-db psql -U postgres -d postgres -c \"\\df calculate_payout_with_debt\""
   ```
2. If 2-arg version is deployed (likely): Change stripe-webhook to compute `gross_payout` client-side and pass only 2 args:
   ```ts
   const grossPayout = grossAmount - commission - ivaWithheld - isrWithheld;
   const { data: debtResult } = await supabase.rpc("calculate_payout_with_debt", {
     p_business_id: businessId,
     p_gross_payout: grossPayout,
   });
   ```
3. If neither is deployed: Run the migration first, then fix the edge function.
4. **Test:** Add a contract test in `tax_withholding_contract_test.dart` that verifies `grossPayout = grossAmount - commission - ivaWithheld - isrWithheld` for known inputs.
5. Redeploy edge functions after fix.

**Files:**
- `supabase/functions/stripe-webhook/index.ts` (lines 418–423)
- `supabase/migrations/20260410000001_missing_financial_tables.sql` (line 78)

---

### 1.2 tax_mx.ts negative providerNet — no guard
**Finding #119 | Queue #5 | Priority: 20 | CRITICAL**

**Problem:** `calculateWithholding()` in `_shared/tax_mx.ts:95`:
```ts
const providerNet = round2(grossAmount - platformFee - isrWithheld - ivaWithheld);
```
If `platformFee + isrWithheld + ivaWithheld > grossAmount`, providerNet goes negative. No guard exists. A negative transfer via Stripe Connect would fail or worse, charge the salon.

**When this happens:** Small amounts without RFC. Example: $10 MXN, no RFC:
- ISR 20% = $2.00, IVA 16% of $1.38 = $0.22, commission 3% = $0.30
- providerNet = 10 - 0.30 - 2.00 - 0.22 = $7.48 (safe)
  
Actually for very small amounts AND high commission scenarios (e.g. if rates change), this is still a latent risk.

**Fix:**
1. In `_shared/tax_mx.ts`, add guard after line 95:
   ```ts
   const providerNet = Math.max(round2(grossAmount - platformFee - isrWithheld - ivaWithheld), 0);
   ```
2. In `create_booking_with_financials` SQL (line 117):
   ```sql
   v_provider_net := GREATEST(ROUND(p_price - v_isr_withheld - v_iva_withheld, 2), 0);
   ```
3. Add contract test for boundary case (e.g., $1 MXN booking, no RFC).
4. Log an alert when providerNet would have gone negative (don't silently clamp).

**Files:**
- `supabase/functions/_shared/tax_mx.ts` (line 95)
- `supabase/migrations/20260407000002_booking_with_financials_rpc.sql` (line 117)

---

### 1.3 cancel_booking double-refund via missing idempotency
**Finding #121 | Queue #6 | Priority: 15 | MAJOR**

**Problem:** `cancel_booking` RPC checks if status is already cancelled and returns early (lines 44–52). **This guard exists.** However, there's a race window: two concurrent calls could both pass the status check before either commits. The `FOR UPDATE` lock on line 37 prevents this at the row level — but only if both calls hit the same row simultaneously.

**Actual risk:** Low. The `FOR UPDATE` lock serializes concurrent cancellations. The existing `already_cancelled` check handles the idempotent path correctly. The finding may be overstated.

**Verify:**
1. Confirm the `FOR UPDATE` on line 37 of cancel_booking locks the row:
   ```sql
   SELECT ... FROM appointments WHERE id = p_booking_id FOR UPDATE;
   ```
2. If `FOR UPDATE` is present (it is): This is already idempotent. Second caller will block until first commits, then see `cancelled_customer` status, and return the no-op response.
3. Add a commission_records `ON CONFLICT DO NOTHING` (already there at line 166).

**Fix (belt-and-suspenders):**
- Add `refund_idempotency_key` column to appointments, set on first refund. Check before `increment_saldo`. This prevents any theoretical edge case.
- Or: Accept current `FOR UPDATE` + status check as sufficient (it is for PostgreSQL's MVCC).

**Recommendation:** Mark as low-risk, monitor. The `FOR UPDATE` lock is correct.

**Files:**
- `supabase/migrations/20260407000003_cancel_booking_rpc.sql` (lines 37, 44–52, 166)

---

## Phase 2: Test Coverage Hardening

### 2.1 pgTAP integration tests for financial RPCs
**Finding #118 | Queue #4 | Priority: 20 | CRITICAL (downgraded to major after contract tests)**

**Status:** Dart-side golden-value contract tests now exist (29 tests). These catch formula drift but not DB-level bugs (wrong column types, missing constraints, trigger side effects).

**What's still needed:**
1. Create `supabase/tests/` directory with pgTAP test files
2. Install pgTAP extension on production DB (or a test DB clone)
3. Write tests that call RPCs directly and assert:
   - `create_booking_with_financials`: appointment row has correct financial fields, tax_withholdings row created, commission_records row created, saldo deducted (for saldo path)
   - `cancel_booking`: refund_amount correct, saldo credited, status updated, idempotent on second call
   - `purchase_product_with_saldo`: order created, saldo deducted, commission recorded, idempotent
   - `calculate_payout_with_debt`: FIFO debt deduction, 50% cap, correct net payout

**Alternative (faster):** Run SQL test scripts via `psql` that INSERT test data, call RPCs, and SELECT/assert results. No pgTAP needed — plain SQL with `DO $$ BEGIN ... ASSERT ... END $$` blocks.

**Files to create:**
- `supabase/tests/test_booking_financials.sql`
- `supabase/tests/test_cancel_booking.sql`
- `supabase/tests/test_product_purchase.sql`
- `supabase/tests/test_debt_collection.sql`

---

### 2.2 Integration test bridge (mock→real parity)
**Finding #122 | Queue #7 | Priority: 15 | MAJOR**

**Problem:** All 515 Flutter tests use mocks/fakes. No test verifies that FakePostgrestBuilder behavior matches real Supabase responses. Mock drift is a real risk.

**Fix (pragmatic):**
1. Create `test/integration/` directory (gitignored from CI, run manually)
2. Write 5 integration tests that hit a local Supabase instance:
   - Book with saldo → verify saldo deducted
   - Book with card → verify pending status
   - Cancel free → verify refund credited
   - Purchase product → verify commission
   - Gift card redeem → verify saldo credited
3. These tests use `SupabaseClientService.testClient` pointed at a local Supabase URL
4. Add `test/integration/README.md` with setup instructions

**Prerequisite:** Local Supabase instance (already available via Docker on dev machine).

---

## Execution Order

| Step | Finding | Est. Time | Depends On |
|------|---------|-----------|------------|
| 1 | #117 stripe-webhook arg fix | 15 min | Verify prod DB signature |
| 2 | #119 negative providerNet guard | 10 min | None |
| 3 | #121 cancel_booking verify | 10 min | Read production code |
| 4 | #118 pgTAP/SQL integration tests | 2 hrs | Steps 1–3 deployed |
| 5 | #122 Flutter integration bridge | 2 hrs | Local Supabase running |

Steps 1–3 are quick fixes that should be done and deployed together.
Steps 4–5 are hardening work that can follow.
