# BeautyCita On-Call Runbook
**Owner:** BC (sole oncall today; future: rotate when team grows)
**Last updated:** 2026-04-20
**Pages BC when:** anything in §0 fires
**Stays in alerts (Doc / Grafana) when:** anything in §1-§3

This runbook is written so a future on-call engineer with prod access can resolve incidents WITHOUT calling BC. Every section: detect → diagnose → fix → verify → escalate.

---

## §0 PAGES BC IMMEDIATELY (5-min response)

These conditions are unrecoverable without judgment calls.

### 0.1 Saldo invariant violation
**Detect:** `check_saldo_invariant()` returns false. Alert from monitoring stack.
**Diagnose:** Run on prod:
```sql
SELECT * FROM saldo_ledger
WHERE created_at > now() - interval '24 hours'
ORDER BY created_at DESC LIMIT 50;
```
Check for credits without offsetting debits or vice versa.
**Fix:** Do NOT auto-correct. Page BC. Ledger errors compound.
**Escalate:** Always.

### 0.2 Stripe Connect account suspended
**Detect:** `account.updated` webhook with `charges_enabled=false` for previously-verified salon. Or Stripe email to BC.
**Diagnose:** `docker exec supabase-db psql -U postgres -d postgres -c "SELECT id, name, stripe_account_id, stripe_onboarding_status FROM businesses WHERE stripe_charges_enabled = false AND is_verified = true"`
**Fix:** Suspend salon temporarily (`UPDATE businesses SET is_active = false ...`), notify owner, work with Stripe support to remediate.
**Escalate:** Always.

### 0.3 Mass chargeback wave (>3 in 1 hour)
**Detect:** `charge.refunded` events from Stripe at unusual rate.
**Diagnose:** `SELECT count(*), business_id FROM salon_debts WHERE source='chargeback' AND created_at > now() - interval '1 hour' GROUP BY business_id`
**Fix:** Halt payouts platform-wide via toggle. Investigate per-business.
**Escalate:** Always — likely fraud or product issue.

### 0.4 Money goes missing (reconciliation watchdog imbalance)
**Detect:** `run_reconciliation_all()` returns rows. Alert from cron.
**Diagnose:** Read the imbalance row(s); identify GMV-vs-saldo-vs-debt mismatch.
**Fix:** Do NOT auto-correct. Page BC. Investigate WHICH transaction drifted.
**Escalate:** Always.

---

## §1 DOC AUTO-REPAIR (no human needed; Doc handles)

These conditions Doc has been trained to repair. Verify the repair logged in `bash repairs` and move on.

### 1.1 Website down (`website-down|systemctl restart nginx`)
Most common, runs ~daily. Doc handles.

### 1.2 Edge function container stuck (`edge-function-restart|docker compose restart functions`)
Doc handles. If recurs > 3 times in 1 hour, escalate to §2.

### 1.3 Supabase function 502 burst
Doc restarts the container. Verify in `docker logs supabase-edge-functions`.

### 1.4 Backup cron miss
Doc re-runs the backup script. Verify R2 has fresh artifact.

### 1.5 Disk space watermark
Doc clears `/var/log` archives older than 30d.

---

## §2 OPERATOR FIXES (15-30 min response)

You can do these without paging BC. Document what you did in `audit_log`.

### 2.1 Single user can't book
**Symptoms:** support ticket "can't book"; user_id known.
**Diagnose:**
```sql
-- Check role + status
SELECT id, role, status, last_seen FROM profiles WHERE id = '<user_id>';
-- Check pending bookings stuck
SELECT id, status, payment_status, created_at FROM appointments WHERE user_id = '<user_id>' ORDER BY created_at DESC LIMIT 5;
```
**Fix:** If status is 'suspended', check `audit_log` for why. If pending booking is stuck, manually cancel: `UPDATE appointments SET status='cancelled_customer', payment_status='refunded_to_saldo' WHERE id = '<id>'` then call `increment_saldo` for the amount with idempotency key `manual:fix:<ticket_id>`.

### 2.2 Single salon not appearing in search
**Diagnose:**
```sql
SELECT id, name, is_active, is_verified, onboarding_complete, banking_complete,
       rfc IS NOT NULL AS has_rfc, id_verification_status
FROM businesses WHERE id = '<biz_id>';
```
**Fix:** Identify which gate fails. Most common: `rfc` is null (require salon to enter), `id_verification_status != 'verified'` (re-trigger verify-salon-id), `banking_complete = false` (push CLABE entry).

### 2.3 Stripe Connect onboarding stuck for one salon
**Diagnose:** Open Stripe Dashboard → Connect → Account → check `requirements.currently_due`.
**Fix:** Communicate to owner what's missing. Use `stripe-connect-onboard` action `get-onboard-link` to generate a fresh link.

### 2.4 WhatsApp OTP not arriving
**Diagnose:**
```bash
ssh www-bc "docker logs beautycita-wa-api --tail 50 2>&1 | grep ERROR"
```
Check phone number on bpi/qi7 instances if biz number is rate-limited.
**Fix:** Switch user to SMS fallback (manual: insert OTP record with channel='sms'). Re-link WA if biz number disconnected.

### 2.5 Salon dispute filed but no notification
**Diagnose:**
```sql
SELECT * FROM disputes WHERE id = '<dispute_id>';
SELECT id, fcm_token, fcm_updated_at FROM businesses WHERE id = '<biz_id>';
```
**Fix:** If `fcm_token` stale (`fcm_updated_at` > 7 days), send WA fallback. Use `send-push-notification` with `channel: 'wa'` body.

### 2.6 Order stuck in 'paid' past 14d (auto-refund didn't fire)
**Diagnose:**
```sql
SELECT * FROM orders WHERE status = 'paid' AND created_at < now() - interval '15 days';
```
**Fix:** Manually invoke `order-followup` edge function. Check its logs for the specific order.

### 2.7 Stripe webhook dedup table growth alert
**Symptom:** `stripe_webhook_events` row count growing by > 1k/hr.
**Diagnose:** Likely Stripe retrying same events repeatedly. Check edge function logs for errors causing 5xx.
**Fix:** Find the failing handler, fix the underlying error. Dedup table will retain entries (clean up if > 1M rows: keep last 30d).

### 2.8 Reconciliation watchdog "balance close but off by < 1 MXN"
Probably rounding error. Diagnose specific transaction. Document in `audit_log`. Do NOT page BC for sub-peso variance.

---

## §3 INFORMATIONAL (logs / dashboards)

Watch these but don't action unless user-impacting.

### 3.1 Slow query log (>500ms)
Surfaces in Grafana → Database & Cache dashboard. Common offenders: `curate_candidates` at high concurrency. Document, plan tuning, don't urgent.

### 3.2 Honeypot trap hits
Surfaces in Grafana → Honeypot. Interesting for awareness, fail2ban handles automatically. Review weekly.

### 3.3 Edge function cold-start spikes
Normal after deploy. Subsides within 5 min. If sustained > 30 min, escalate to §2.

### 3.4 Backup R2 upload size delta
If today's DB dump is significantly smaller (>20%) than yesterday, investigate. Possible data loss. Check `pg_database_size`.

---

## Useful Commands

```bash
# Quick prod health
ssh www-bc "docker ps --format '{{.Names}}\t{{.Status}}' | grep -E 'unhealthy|Restarting'"

# Recent errors across all functions
ssh www-bc "docker logs supabase-edge-functions --since 1h 2>&1 | grep -iE 'error|warn' | tail -50"

# Saldo balance for user
ssh www-bc "docker exec supabase-db psql -U postgres -d postgres -c \"SELECT user_id, sum(amount) FROM saldo_ledger WHERE user_id = '<id>' GROUP BY user_id\""

# Active payout holds
ssh www-bc "docker exec supabase-db psql -U postgres -d postgres -c \"SELECT * FROM payout_holds WHERE released_at IS NULL\""

# Today's bookings
ssh www-bc "docker exec supabase-db psql -U postgres -d postgres -c \"SELECT count(*), payment_status FROM appointments WHERE created_at::date = current_date GROUP BY payment_status\""

# Stripe webhook events processed today
ssh www-bc "docker exec supabase-db psql -U postgres -d postgres -c \"SELECT event_type, count(*) FROM stripe_webhook_events WHERE received_at > current_date GROUP BY event_type ORDER BY count(*) DESC\""

# Reconciliation watchdog manual run
ssh www-bc "docker exec supabase-db psql -U postgres -d postgres -c \"SELECT * FROM run_reconciliation_all()\""
```

## Escalation Matrix

| Severity | First responder | Time to BC | Channel |
|---|---|---|---|
| §0 (page) | self → BC | < 5 min | WA + call |
| §1 (Doc auto) | Doc | NA | Doc log |
| §2 (operator) | self | < 30 min if recurring | WA |
| §3 (info) | self | NA | weekly summary |

**BC contact:** primary phone (memory: WA business 5217206777800 routes to BC). Escalate via WA + voice call if §0 within 5 minutes.

## Post-Incident

After any §0 or recurring §2:
1. Write a 1-page postmortem in `docs/incidents/YYYY-MM-DD-summary.md`
2. Update this runbook if new failure mode
3. Add monitoring + automated test for the failure path
4. Add Doc-repair vocab if pattern repeats
