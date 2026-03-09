# V1 Launch Readiness — Complete Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Make BeautyCita production-ready for its first paying customers — every feature complete, every payment flow bulletproof, every failure recoverable, every metric visible to the CEO.

**Architecture:** Four phases executed in priority order. Phase 1 (emergency) secures the server and restores backups. Phase 2 (critical) fixes payment and data integrity bugs that would lose money. Phase 3 (operations) builds the CEO command center and financial systems. Phase 4 (completion) closes every remaining gap for a polished V1.

**Tech Stack:** Flutter (mobile + web), Supabase (self-hosted Postgres + Edge Functions), Stripe Connect, Prometheus/Grafana/Loki (monitoring), Cloudflare R2 (backups/media), Nginx, Docker Compose, UptimeRobot (external monitoring), Hetzner VPS (warm standby).

**Server:** IONOS VPS — 8 cores, 16GB RAM, 464GB disk (327GB free), Ubuntu 24.04 LTS, US West datacenter. SSH alias: `www-bc`.

---

## Phase 1: Emergency — Server Security & Backup Recovery

**Timeline:** Day 1. These are done before anything else.

The server has no firewall, 6+ monitoring ports exposed to the internet, broken backups for 41 days, and .env files in the webroot. This is a live production server handling Stripe keys and customer data.

---

### Task 1.1: Enable UFW Firewall

**Why:** Zero firewall rules active. Anyone can reach Prometheus (with admin API enabled — can delete metrics remotely), AlertManager, Node Exporter, Redis Exporter, Postgres Exporter. All expose internal system/database metrics.

**Files:**
- Server: `/etc/ufw/` (system config)

**Step 1: SSH in and enable UFW with safe defaults**

```bash
ssh www-bc
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 22/tcp comment 'SSH'
sudo ufw allow 80/tcp comment 'HTTP'
sudo ufw allow 443/tcp comment 'HTTPS'
sudo ufw allow 8333/tcp comment 'Bitcoin P2P'
sudo ufw allow 9735/tcp comment 'Lightning Network'
```

**Step 2: Verify rules before enabling**

```bash
sudo ufw show added
```

Expected: 5 ALLOW rules (22, 80, 443, 8333, 9735). Nothing else.

**Step 3: Enable firewall**

```bash
sudo ufw --force enable
sudo ufw status verbose
```

Expected: Status active, 5 rules. Ports 3030, 3202, 9090, 9093, 9094, 9100, 9113, 9121, 9187 now blocked from outside.

**Step 4: Verify services still work**

```bash
curl -s -o /dev/null -w '%{http_code}' https://beautycita.com
curl -s -o /dev/null -w '%{http_code}' https://beautycita.com/supabase/rest/v1/
```

Expected: 200 for both. If SSH drops, IONOS console is the recovery path.

**Step 5: Identify and investigate unknown public services**

```bash
# Port 3030 — likely mini-qr container
docker ps --format '{{.Names}} {{.Ports}}' | grep 3030
# Port 3202 — python3 process
ss -tlnp | grep 3202
ps aux | grep -E 'python.*3202|:3202'
```

Decide: if these are needed, add UFW rules. If not, stop them.

---

### Task 1.2: Remove .env Files from Webroot

**Why:** Two .env files sitting in the public web directory. Nginx blocks them, but defense-in-depth means they shouldn't exist.

**Step 1: Check contents and remove**

```bash
ssh www-bc
cat /var/www/beautycita.com/frontend/dist/.env
cat /var/www/beautycita.com/frontend/dist/assets/.env
```

If they contain secrets: remove immediately. If they're empty Flutter build artifacts: remove and add to .gitignore.

```bash
rm /var/www/beautycita.com/frontend/dist/.env
rm /var/www/beautycita.com/frontend/dist/assets/.env
```

**Step 2: Clean up stale .env backups**

```bash
rm /var/www/beautycita.com/.env.backup.20250923_192618
rm /var/www/beautycita.com/.env.backup.20251027_065618
rm /var/www/beautycita.com/.env.production.backup.20260110_070808
```

Old credential copies sitting on disk serve no purpose and increase exposure surface.

**Step 3: Verify Nginx blocks .env access**

```bash
curl -s -o /dev/null -w '%{http_code}' https://beautycita.com/.env
curl -s -o /dev/null -w '%{http_code}' https://beautycita.com/assets/.env
```

Expected: 403 or 404 for both.

---

### Task 1.3: Fix Backup Script — Restore Daily Backups

**Why:** `pg_dump: error: parallel backup only supported by the directory format` — every backup since Jan 26 has produced empty directories. The `--parallel 4` flag requires directory format, but the script uses custom format.

**Files:**
- Modify: `/var/www/beautycita.com/scripts/backup/backup-full-system.sh`

**Step 1: Read the current backup script and find the pg_dump command**

```bash
ssh www-bc "grep -n 'pg_dump' /var/www/beautycita.com/scripts/backup/backup-full-system.sh"
```

**Step 2: Fix the pg_dump format**

Two options:
- **Option A:** Change format to directory (`-Fd`) to keep parallel. Faster but outputs a directory, not a single file. Needs tar afterward.
- **Option B:** Remove `--jobs` flag and keep custom format (`-Fc`). Simpler, single file output, slightly slower (DB is 87MB — speed doesn't matter).

**Go with Option B** — at 87MB, parallel dump saves ~2 seconds. Not worth the complexity.

Find the pg_dump line and remove `--jobs $PARALLEL_JOBS` or `-j $PARALLEL_JOBS`. Keep `-Fc` (custom format).

Also fix the missing closing double-quote on the "Cleaning up old backups..." log line near the end of the script.

**Step 3: Test the fix manually**

```bash
ssh www-bc "sudo -u www-data /var/www/beautycita.com/scripts/backup/backup-full-system.sh daily"
```

Expected: Backup completes, `database.sql.gz` or `database.dump` appears in `/var/www/backups/daily/YYYYMMDD/`.

**Step 4: Verify backup is valid**

```bash
ssh www-bc "pg_restore --list /var/www/backups/daily/$(date +%Y%m%d)/database.dump | head -20"
```

Expected: Table of contents listing tables and data.

---

### Task 1.4: Configure R2 Off-site Backup Upload

**Why:** Backups only exist on the same server as the database. Server dies = backups die.

**Files:**
- Modify: server rclone config

**Step 1: Set up rclone with R2 credentials**

The setup script exists: `/var/www/beautycita.com/scripts/backup/setup-r2-backup.sh`. R2 credentials are in the main `.env` file. Run the setup.

```bash
ssh www-bc "source /var/www/beautycita.com/.env && R2_ACCESS_KEY_ID=\$R2_ACCESS_KEY_ID R2_SECRET_ACCESS_KEY=\$R2_SECRET_ACCESS_KEY CLOUDFLARE_ACCOUNT_ID=\$CLOUDFLARE_ACCOUNT_ID bash /var/www/beautycita.com/scripts/backup/setup-r2-backup.sh"
```

**Step 2: Verify R2 upload works**

```bash
ssh www-bc "rclone ls r2:beautycita-backups/ 2>/dev/null | head -5"
```

If bucket doesn't exist, create it via Cloudflare dashboard or rclone.

**Step 3: Run a full backup with R2 upload**

```bash
ssh www-bc "sudo -u www-data /var/www/beautycita.com/scripts/backup/backup-full-system.sh daily --r2"
```

**Step 4: Verify backup exists off-site**

```bash
ssh www-bc "rclone ls r2:beautycita-backups/ | tail -5"
```

Expected: Today's backup file listed in R2.

---

### Task 1.5: Set Up UptimeRobot External Monitoring

**Why:** If the server goes down, the monitoring on the server goes down too. We need external eyes.

**Step 1: Create UptimeRobot account (free tier)**

Monitors to create:
- `https://beautycita.com` — HTTP 200 check, 5 min interval
- `https://beautycita.com/supabase/rest/v1/` — Supabase API health
- `https://beautycita.com/health` — Backend health endpoint (create if missing)
- `beautycita.com:443` — SSL cert monitoring

Alert contacts: BC's email + phone (SMS alerts for downtime).

**Step 2: Verify alerts work**

Intentionally break a monitor (wrong URL) and confirm alert arrives.

---

## Phase 2: Critical — Payment & Data Integrity Fixes

**Timeline:** Days 2-4. Fix every bug that could lose money or corrupt data.

---

### Task 2.1: Fix Payment Race Condition — Booking Must Exist Before Charge

**Why:** If app crashes after Stripe payment but before booking creation, customer is charged with no appointment. No reconciliation path exists.

**Current flow (broken):**
1. Create PaymentIntent (edge function)
2. User pays via PaymentSheet
3. App creates booking in Supabase ← **if this fails, money is gone**
4. Send confirmation

**Fixed flow:**
1. Create booking with status `pending_payment` (new status)
2. Create PaymentIntent with `booking_id` in metadata
3. User pays via PaymentSheet
4. Stripe webhook confirms payment → updates booking to `confirmed` + `paid`
5. If payment fails → booking stays `pending_payment` → auto-cleanup after 30 min

**Files:**
- Modify: `beautycita_app/lib/providers/booking_flow_provider.dart` (~lines 316-430)
- Modify: `beautycita_app/supabase/functions/create-payment-intent/index.ts`
- Modify: `beautycita_app/supabase/functions/stripe-webhook/index.ts`
- Create: migration for `pending_payment` booking status

**Step 1: Create migration for pending_payment status**

```sql
-- If status is an enum, add the new value:
-- ALTER TYPE booking_status ADD VALUE IF NOT EXISTS 'pending_payment';
-- If status is text (check first), no migration needed.
```

Verify status column type first:
```bash
ssh www-bc "docker exec supabase-db psql -U postgres -d postgres -c \"SELECT column_name, data_type, udt_name FROM information_schema.columns WHERE table_name='appointments' AND column_name='status';\""
```

**Step 2: Modify booking_flow_provider.dart — create booking BEFORE payment**

In `_confirmStripe()`:
1. Create booking with `status: 'pending_payment'`, `payment_status: 'pending'`
2. Pass `booking_id` to create-payment-intent
3. On payment success: booking already exists, webhook updates it
4. On payment failure/cancel: mark booking `cancelled`
5. Wrap in try/catch that cancels the booking on any error

**Step 3: Modify create-payment-intent — accept and store booking_id**

Add `booking_id` to the request body validation.
Store `booking_id` in PaymentIntent metadata:
```typescript
metadata: {
  booking_id: body.booking_id,
  service_id: body.service_id,
  user_id: user.id,
}
```

**Step 4: Modify stripe-webhook — update booking on payment success**

In the `payment_intent.succeeded` handler:
```typescript
const bookingId = paymentIntent.metadata.booking_id;
if (bookingId) {
  await supabase.from('appointments')
    .update({ status: 'confirmed', payment_status: 'paid' })
    .eq('id', bookingId);
}
```

**Step 5: Add cleanup for stale pending_payment bookings**

Create a cron or scheduled function that cancels any booking in `pending_payment` status older than 30 minutes. This catches the edge case where the user closes the app during payment.

**Step 6: Test the full flow**

- Happy path: book → pay → booking confirmed
- Failure path: book → cancel payment → booking auto-cancelled
- Edge case: simulate crash (kill app after PaymentIntent creation) → booking stays pending_payment → cleanup removes it

---

### Task 2.2: Fix Product Stock Overselling

**Why:** Two users can buy the same last item. `create-product-payment` checks `in_stock` but never decrements. No locking.

**Files:**
- Modify: `beautycita_app/supabase/functions/create-product-payment/index.ts`
- Modify: `beautycita_app/supabase/functions/stripe-webhook/index.ts`
- Create: migration for stock management

**Step 1: Add stock locking to create-product-payment**

Since BeautyCita uses simple in_stock/out_of_stock (not quantity counting — per policies.md), the fix is:
- Use a Postgres advisory lock or SELECT FOR UPDATE to prevent concurrent purchases of the same product
- After successful payment confirmation (webhook), if needed, check if product should be marked out_of_stock

```typescript
// In create-product-payment, use a transaction:
const { data: product, error } = await supabase.rpc('lock_product_for_purchase', {
  p_product_id: body.product_id,
});
// RPC function uses SELECT ... FOR UPDATE and checks in_stock
```

**Step 2: Create the RPC function**

```sql
CREATE OR REPLACE FUNCTION lock_product_for_purchase(p_product_id uuid)
RETURNS products AS $$
DECLARE
  p products;
BEGIN
  SELECT * INTO p FROM products WHERE id = p_product_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Product not found';
  END IF;
  IF NOT p.in_stock THEN
    RAISE EXCEPTION 'Product out of stock';
  END IF;
  RETURN p;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

---

### Task 2.3: Stop Leaking Internal Errors to Clients

**Why:** 17+ edge functions return raw `(err as Error).message` in HTTP responses. Exposes DB errors, Stripe internals, stack traces.

**Files:**
- Modify: All 17 edge functions listed in audit (create-payment-intent, stripe-webhook, etc.)

**Step 1: Create a shared error response helper**

```typescript
// In a shared utils file or inline in each function:
function safeErrorResponse(error: unknown, status = 500): Response {
  const message = error instanceof Error ? error.message : 'Unknown error';
  // Log full error server-side
  console.error('[ERROR]', message, error);
  // Return generic message to client
  return new Response(
    JSON.stringify({ error: 'An internal error occurred. Please try again.' }),
    { status, headers: { 'Content-Type': 'application/json' } }
  );
}
```

For user-facing errors (validation, not found), keep specific messages. Only sanitize unexpected/internal errors.

**Step 2: Apply to each edge function's catch block**

Replace:
```typescript
return new Response(JSON.stringify({ error: (err as Error).message }), { status: 500 });
```
With:
```typescript
return safeErrorResponse(err);
```

**Step 3: For validation errors, keep specific messages**

```typescript
if (!body.service_id) {
  return new Response(JSON.stringify({ error: 'service_id is required' }), { status: 400 });
}
```

These are fine — they're intentional, client-actionable messages.

---

### Task 2.4: Lock Down CORS on Payment Endpoints

**Why:** Wildcard CORS (`*`) on payment endpoints. A malicious site could use a stolen JWT to create PaymentIntents.

**Files:**
- Modify: Payment edge functions (create-payment-intent, create-product-payment, stripe-connect-onboard, btcpay-invoice)

**Step 1: Create a shared CORS helper**

```typescript
const ALLOWED_ORIGINS = [
  'https://beautycita.com',
  'https://www.beautycita.com',
];

function corsHeaders(req: Request): Record<string, string> {
  const origin = req.headers.get('origin') ?? '';
  const allowed = ALLOWED_ORIGINS.includes(origin) ? origin : ALLOWED_ORIGINS[0];
  return {
    'Access-Control-Allow-Origin': allowed,
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
  };
}
```

**Step 2: Apply to all payment-related edge functions**

Replace wildcard CORS headers with the origin-checked version. Keep `*` on public read-only endpoints (feed-public, curate-results) since the mobile app doesn't send an Origin header and these are read-only.

---

### Task 2.5: Stripe Webhook Signature Verification

**Why:** Anyone who knows the webhook URL can send fake payment confirmations.

**Files:**
- Modify: `beautycita_app/supabase/functions/stripe-webhook/index.ts`

**Step 1: Verify if signature checking exists**

```bash
grep -n 'constructEvent\|webhook_secret\|STRIPE_WEBHOOK' beautycita_app/supabase/functions/stripe-webhook/index.ts
```

If missing, add:
```typescript
import Stripe from 'stripe';
const stripe = new Stripe(Deno.env.get('STRIPE_SECRET_KEY')!);
const sig = req.headers.get('stripe-signature')!;
const body = await req.text();
const event = stripe.webhooks.constructEvent(body, sig, Deno.env.get('STRIPE_WEBHOOK_SECRET')!);
```

**Step 2: Same for btcpay-webhook**

Check if BTCPay webhook signature verification exists. Apply equivalent check.

---

## Phase 3: Operations — CEO Command Center & Financial Systems

**Timeline:** Days 5-14. Build the visibility and financial infrastructure.

---

### Task 3.1: Configure Grafana Dashboards — Infrastructure

**Why:** Prometheus is collecting data. Grafana is running. Zero dashboards configured. Data going to waste.

**Files:**
- Create: Grafana dashboard JSON files
- Deploy to: `/var/www/beautycita.com/monitoring/grafana/dashboards/`

**Step 1: Build Server Health Dashboard**

Panels:
- CPU usage (gauge + 24hr graph)
- Memory usage (gauge + 24hr graph)
- Disk usage (gauge + trend)
- Network I/O (graph)
- Container status (table: name, status, uptime, CPU, memory)
- System load (1/5/15 min)

Data sources: node-exporter metrics, cAdvisor metrics.

**Step 2: Build Endpoint Health Dashboard**

Panels:
- Blackbox probe status (up/down for each monitored URL)
- Response time per endpoint (graph)
- SSL cert days remaining
- HTTP error rate (4xx, 5xx by endpoint)
- Nginx requests/sec (from nginx-exporter)
- Request latency percentiles (p50, p95, p99)

**Step 3: Build Database Dashboard**

Panels:
- Active connections / max connections
- Queries per second
- Slow queries (if postgres-exporter configured)
- Database size trend
- Table sizes (top 10)
- Replication lag (for future standby)

**Step 4: Build Backup Status Dashboard**

Panels:
- Last backup timestamp
- Last backup size
- Backup success/failure (from backup-metrics.prom)
- Days since last successful backup (ALERT if > 1)
- R2 upload status

**Step 5: Deploy dashboards**

Copy JSON files to the Grafana provisioning directory. Grafana auto-loads them (10s refresh configured).

```bash
scp dashboards/*.json www-bc:/var/www/beautycita.com/monitoring/grafana/dashboards/
docker restart beautycita-grafana
```

**Step 6: Set Grafana admin password to something secure**

```bash
ssh www-bc "docker exec beautycita-grafana grafana-cli admin reset-admin-password '<SECURE_PASSWORD>'"
```

Save the new password in BC's password manager.

---

### Task 3.2: Configure Grafana Dashboards — Security

**Why:** BC wants a security panel with logs, 24hr history, all stats visible.

**Step 1: Build Security Dashboard**

Panels:
- Failed SSH attempts (last 24hr, from Loki/auth.log)
- HTTP 4xx/5xx by source IP (from Nginx logs via Loki)
- Rate limit hits (from Nginx)
- Blocked requests (attack patterns: .env probes, PHP probes, etc.)
- Authentication failures (from Supabase auth logs)
- Top requesting IPs (table)
- Suspicious patterns (anomaly detection on request rate)

**Step 2: Add Loki as Grafana datasource**

```bash
# Loki is running at localhost:3100, need to add it as a datasource
curl -u admin:<password> -X POST http://127.0.0.1:3000/api/datasources \
  -H 'Content-Type: application/json' \
  -d '{"name":"Loki","type":"loki","url":"http://loki:3100","access":"proxy","isDefault":false}'
```

---

### Task 3.3: Un-park Tax Withholding System

**Why:** Mexican law requires ISR + IVA withholding on digital platform transactions. Without this, BeautyCita is non-compliant from the first peso.

**Current state:** Code written on `feature/tax-withholding` branch, uncommitted. Tables designed: `tax_withholdings` (immutable ledger), `sat_monthly_reports`, `sat_access_log`. Business fields: `rfc`, `tax_regime`, `tax_residency`.

**Tax rates:**
- WITH RFC: ISR 2.5% + IVA 8% = 10.5%
- WITHOUT RFC: ISR 20% + IVA 16% = 36%
- US salons in Mexico: same rates (platform operates in Mexico)
- US salons serving US clients: not subject to Mexican withholding (future, out of scope for V1)

**Step 1: Review and commit the tax-withholding code**

```bash
git stash list  # find the stashed tax-withholding code
# OR check the branch
git branch -a | grep tax
```

**Step 2: Verify the migration creates required tables**

- `tax_withholdings` — immutable ledger (business_id, transaction_id, isr_amount, iva_amount, rfc, period)
- `sat_monthly_reports` — aggregated monthly reports for SAT filing
- `sat_access_log` — audit trail
- Add `rfc`, `tax_regime`, `tax_residency` columns to `businesses`

**Step 3: Integrate withholding into payment flow**

When a booking payment succeeds:
1. Look up business RFC
2. Calculate ISR + IVA based on RFC presence
3. Insert row into `tax_withholdings`
4. Deduct withheld amount from payout to business
5. Platform retains withheld amount for SAT remittance

**Step 4: Add RFC collection to salon onboarding**

The `rfc` field exists in the businesses table design. Add it to:
- Salon registration flow (optional but incentivized — "provide RFC to reduce withholding from 36% to 10.5%")
- Business settings screen (can add/update later)

**Step 5: Contract language**

Add tax withholding disclosure to the service agreement. Clear, in Spanish:

> "De conformidad con los artículos 113-A de la LISR y 18-J de la LIVA, BeautyCita está obligado a retener y enterar al SAT el ISR e IVA correspondiente a los ingresos generados a través de la plataforma. Estas retenciones NO son comisiones de BeautyCita — son obligaciones fiscales que la ley nos requiere cobrar en su nombre. Con RFC: 2.5% ISR + 8% IVA. Sin RFC: 20% ISR + 16% IVA."

---

### Task 3.4: Financial Reconciliation System

**Why:** Every peso in must equal every peso out, traceable. BC needs this for his accountant, for investors, for SAT.

**Files:**
- Create: `beautycita_web/lib/pages/admin/finance_dashboard_page.dart`
- Create: Edge function or DB views for financial aggregation
- Create: Migration for financial views/materialized views

**Step 1: Create DB views for financial data**

```sql
-- Daily revenue summary
CREATE OR REPLACE VIEW financial_daily_summary AS
SELECT
  date_trunc('day', a.created_at) AS day,
  COUNT(*) AS total_bookings,
  SUM(a.price) AS gross_revenue,
  SUM(a.price * 0.03) AS booking_commission,
  SUM(COALESCE(tw.isr_amount, 0)) AS isr_withheld,
  SUM(COALESCE(tw.iva_amount, 0)) AS iva_withheld
FROM appointments a
LEFT JOIN tax_withholdings tw ON tw.transaction_id = a.id
WHERE a.payment_status = 'paid'
GROUP BY 1
ORDER BY 1 DESC;

-- Per-business payout summary
CREATE OR REPLACE VIEW business_payout_summary AS
SELECT
  b.id AS business_id,
  b.name AS business_name,
  b.rfc,
  COUNT(a.id) AS total_bookings,
  SUM(a.price) AS gross_earnings,
  SUM(a.price * 0.03) AS commission_deducted,
  SUM(COALESCE(tw.isr_amount, 0)) AS isr_withheld,
  SUM(COALESCE(tw.iva_amount, 0)) AS iva_withheld,
  SUM(a.price - a.price * 0.03 - COALESCE(tw.isr_amount, 0) - COALESCE(tw.iva_amount, 0)) AS net_payout
FROM businesses b
JOIN appointments a ON a.business_id = b.id
LEFT JOIN tax_withholdings tw ON tw.transaction_id = a.id AND tw.business_id = b.id
WHERE a.payment_status = 'paid'
GROUP BY b.id, b.name, b.rfc;

-- Product sales summary
CREATE OR REPLACE VIEW product_sales_summary AS
SELECT
  date_trunc('day', o.created_at) AS day,
  COUNT(*) AS total_orders,
  SUM(o.total_amount) AS gross_sales,
  SUM(o.commission_amount) AS product_commission
FROM orders o
WHERE o.status NOT IN ('cancelled', 'refunded')
GROUP BY 1
ORDER BY 1 DESC;
```

**Step 2: Build Financial Dashboard page in web admin**

Sections:
- **Revenue Overview**: KPI cards (today, this week, this month, all-time)
- **Commission Earned**: 3% bookings + 10% products, broken down
- **Tax Withholdings**: ISR + IVA totals by period
- **Reconciliation Table**: gross in, commission, tax withheld, net payable, discrepancies flagged
- **Per-Salon Breakdown**: table with search, sortable
- **Export Buttons**: CSV (for Excel), PDF (for accountant/SAT)

**Step 3: Implement CSV/PDF export**

- CSV: Generate client-side from data, download via browser
- PDF: Use `pdf` Flutter package for formatted reports with BeautyCita letterhead

---

### Task 3.5: CEO Operations Dashboard — Web Admin

**Why:** BC needs a single screen showing system health, recent activity, and business metrics. "If everything is visible to me, I'll know everything is visible to you."

**Files:**
- Create: `beautycita_web/lib/pages/admin/operations_dashboard_page.dart`
- Modify: `beautycita_web/lib/shells/admin_shell.dart` (add nav item)

**Step 1: Design the Operations Dashboard layout**

Desktop-first, 3-column grid:

**Left column — System Health:**
- Server status (CPU, RAM, disk) — green/yellow/red
- Last backup status + timestamp
- Database size + connection count
- Edge function error rate (last 24hr)
- Link to Grafana for deep dive

**Center column — Business Activity:**
- Bookings today (confirmed, pending, cancelled)
- Revenue today
- New salon signups (last 7 days)
- Active users (last 24hr)
- Pending disputes

**Right column — Alerts & Logs:**
- Recent system alerts (from Prometheus/AlertManager)
- Recent admin actions (from audit_log)
- Toggle change history
- Failed payment attempts
- Rate limit hits

**Step 2: Data sources**

- System metrics: Fetch from Prometheus API (`/prometheus/api/v1/query`)
- Business data: Supabase queries (appointments, businesses, orders)
- Logs: Supabase `audit_log` table + Loki API for system logs
- Alerts: AlertManager API (`/alertmanager/api/v2/alerts`)

**Step 3: Build the page**

Follow web app rules: desktop-first, NOT copied from mobile. Built fresh for the use case of a CEO reviewing their platform on a monitor.

**Step 4: Add to admin navigation**

Add "Operaciones" nav item in admin shell, superadmin-only (same as existing admin pages).

---

### Task 3.6: Warm Standby VPS (Hetzner)

**Why:** If IONOS server dies, BeautyCita dies. A $5/month Hetzner box receives real-time DB replication and can be promoted to primary in minutes.

**Step 1: Provision Hetzner CX22**

- Location: US East or US West (different from IONOS US West)
- OS: Ubuntu 24.04
- Specs: 2 vCPU, 4GB RAM, 40GB disk

**Step 2: Configure Postgres streaming replication**

On primary (www-bc):
- Enable WAL archiving
- Create replication user
- Add standby to `pg_hba.conf`

On standby (Hetzner):
- Install Postgres (same version as primary)
- Configure as standby with `primary_conninfo`
- Start streaming replication

**Step 3: Verify replication**

```sql
-- On primary:
SELECT * FROM pg_stat_replication;
-- On standby:
SELECT * FROM pg_stat_wal_receiver;
```

**Step 4: Document failover procedure**

Write a runbook: "Server is down. Here's how to promote the standby."

1. Promote standby: `pg_ctl promote`
2. Update DNS to point to Hetzner IP
3. Deploy edge functions + web app to Hetzner
4. Verify all services running

This runbook goes in `/var/www/beautycita.com/docs/runbooks/failover.md` and in memory.

---

## Phase 4: Completion — Close Every Gap

**Timeline:** Days 10-21. Polish V1 for real users.

---

### Task 4.1: Server-Side Toggle Enforcement

**Why:** 0/43 edge functions check toggles. Flipping a toggle hides UI but backend still accepts requests. Web app and API consumers bypass toggles entirely.

**Files:**
- Create: shared toggle-checking utility for edge functions
- Modify: 8 critical edge functions (payment, feed, chat, studio, uber)

**Step 1: Create toggle check utility**

```typescript
// shared/check-toggle.ts
import { createClient } from '@supabase/supabase-js';

export async function isFeatureEnabled(key: string): Promise<boolean> {
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  );
  const { data } = await supabase
    .from('app_config')
    .select('value')
    .eq('key', key)
    .single();
  return data?.value === 'true';
}

export async function requireFeature(key: string): Promise<Response | null> {
  if (!(await isFeatureEnabled(key))) {
    return new Response(
      JSON.stringify({ error: 'This feature is currently disabled' }),
      { status: 503, headers: { 'Content-Type': 'application/json' } }
    );
  }
  return null; // feature is enabled, proceed
}
```

**Step 2: Apply to critical edge functions**

| Edge Function | Toggle | Priority |
|---|---|---|
| create-payment-intent | enable_stripe_payments | Critical |
| btcpay-invoice | enable_btc_payments | Critical |
| feed-public | enable_feed | High |
| salon-chat | enable_salon_chat | High |
| aphrodite-chat (try_on) | enable_virtual_studio | Medium |
| curate-results | enable_time_inference | Medium |
| schedule-uber | enable_uber_integration | Medium |
| send-push-notification | enable_push_notifications | Medium |

Usage in each function:
```typescript
const blocked = await requireFeature('enable_stripe_payments');
if (blocked) return blocked;
```

---

### Task 4.2: Feed Algorithm — Global-First with Local Boost

**Why:** Feed currently says "inspirations from salons close to you." In a small town with few stylists, the feed is empty and boring. Feed must be entertaining first, local second.

**Files:**
- Modify: `beautycita_app/supabase/functions/feed-public/index.ts`
- Modify: `beautycita_app/lib/screens/feed_screen.dart` (remove "close to you" text)

**Step 1: Modify feed-public edge function**

Current: filters by geography first, then scores.
New: score ALL content globally, then apply local boost.

```
Score = (freshness_weight * freshness) +
        (quality_weight * quality) +
        (engagement_weight * engagement) +
        (local_boost * is_local)  // e.g., 1.5x multiplier if within user's city
```

This means:
- A great portfolio from across the country shows up
- A mediocre local portfolio still shows up but ranked by actual quality
- An empty feed is impossible as long as ANY content exists on the platform
- Local content gets a natural boost, not a hard filter

**Step 2: Update feed screen text**

Remove "inspirations from salons close to you" — replace with "Inspiración" or similar neutral header.

**Step 3: Seed the feed**

Until salons upload portfolios, the feed needs content. Options:
- Allow BC (superadmin) to post inspiration content directly
- Curate from public beauty content (with attribution)
- Use AI-generated beauty inspiration images

This is a content strategy decision for BC. The technical system should support all three.

---

### Task 4.3: Fix Empty Catch Blocks

**Why:** 7+ locations in mobile app, 1+ in web app where errors are silently swallowed. When these fail, nobody knows.

**Files:** All locations listed in audit

**Step 1: For each empty catch, decide: log, rethrow, or show error**

| Location | Fix |
|---|---|
| `splash_screen.dart:75` — auth check | Log + continue (fallback to unauthenticated is OK) |
| `booking_detail_screen.dart:205,227` — Uber ride | Log + show toast "No se pudo solicitar Uber" |
| `business_disputes_screen.dart:965` — refund price | Log + show error (do NOT proceed with $0 refund) |
| `business_payments_screen.dart:248` — navigator pop | Log only (cosmetic) |
| `business_calendar_screen.dart:2773` — popular names | Log only (non-critical) |
| `user_session.dart:170` — registration source | Log only (analytics, non-critical) |
| `biz_settings_page.dart:142` — hours parse | Log + show toast "Error loading hours" |

**Step 2: Apply fixes**

Replace `catch (_) {}` with appropriate handling per the table above.

---

### Task 4.4: Fix WhatsApp Contact Placeholder (Web)

**Why:** `mis_citas_page.dart` opens `wa.me/?text=...` without a phone number. Dead button.

**Files:**
- Modify: `beautycita_web/lib/pages/client/mis_citas_page.dart:490-497`

**Step 1: Fetch business phone from the appointment's business_id**

The appointment already has `business_id`. Query businesses table for `whatsapp` or `phone` field.

**Step 2: Open wa.me with actual number**

```dart
final phone = booking['business_phone'] ?? booking['business_whatsapp'];
if (phone != null) {
  launchUrl(Uri.parse('https://wa.me/$phone?text=Hola, tengo una cita...'));
}
```

---

### Task 4.5: Remove Debug Statements from Production

**Why:** 203 debugPrint statements in mobile app, 40+ in web app. They execute in release builds, add noise, and can leak info to device logs.

**Step 1: Wrap all debugPrint in assert blocks or remove**

```dart
// Option A: kDebugMode guard (recommended)
if (kDebugMode) debugPrint('[PAYMENT] Creating intent...');

// Option B: Remove entirely (for non-useful prints)
```

**Step 2: Prioritize payment/auth related prints**

Payment flow prints leak PaymentIntent IDs, booking IDs, user IDs to device logs. These go first.

**Step 3: Consider a logging service**

Replace ad-hoc debugPrint with a simple logger that:
- In debug: prints to console
- In release: silently drops (or sends to server for critical errors)

---

### Task 4.6: Remove Test HTTP Request from Media Upload

**Why:** Every image upload makes a test GET to storage endpoint before the real upload. Adds latency, leftover debug code.

**Files:**
- Modify: `beautycita_app/lib/services/media_service.dart:236-250`

Remove the test GET request. Keep only the actual upload.

---

### Task 4.7: Fix No-Op Buttons in Web Admin/Business Shells

**Why:** Notification bell and search icons render but do nothing. Clickable UI that is dead erodes trust.

**Files:**
- Modify: `beautycita_web/lib/shells/admin_shell.dart:297`
- Modify: `beautycita_web/lib/shells/business_shell.dart`

**Options:**
- Remove the buttons entirely (honest)
- Implement notification dropdown (full feature)
- Add tooltip "Próximamente" (compromise — but BC said no placeholders)

Recommendation: Remove them. Add back when notifications are actually implemented.

---

### Task 4.8: Legal Pages — Terms of Service & Privacy Policy

**Why:** Required for Google Play and Apple App Store. Required by Mexican law (LFPDPPP for privacy). Required for SAT compliance.

**Files:**
- Create: Terms of Service (hosted on beautycita.com/legal/terms)
- Create: Privacy Policy (hosted on beautycita.com/legal/privacy)

**Content to cover:**

Terms of Service:
- Platform description (intelligent booking agent, marketplace)
- User responsibilities
- Salon responsibilities
- Payment terms (3% commission, 10% products)
- Tax withholding disclosure (ISR + IVA)
- Cancellation and refund policy
- Dispute resolution
- Limitation of liability
- Governing law (Mexico)

Privacy Policy:
- Data collected (name, phone, email, location, payment info, booking history)
- How data is used
- Third-party sharing (Stripe, Google, BTCPay)
- Data retention
- User rights (access, correction, deletion — LFPDPPP Art. 22-26)
- ARCO rights (Acceso, Rectificación, Cancelación, Oposición)
- Contact for privacy inquiries
- Cookie policy (web app)

**Note:** These should be reviewed by a Mexican lawyer before launch. Draft them properly so the lawyer review is a quick check, not a rewrite.

---

### Task 4.9: App Store Preparation

**Why:** When BeautyCita S.A. de C.V. paperwork comes through, we need to submit immediately. Don't scramble then.

**Step 1: Prepare Google Play assets**

- App icon (512x512 PNG)
- Feature graphic (1024x500)
- Screenshots (phone): at least 4 showing booking flow, feed, profile, studio
- Short description (80 chars max)
- Full description (4000 chars max, Spanish + English)
- Privacy policy URL
- Category: Beauty
- Content rating questionnaire answers
- Target audience declaration

**Step 2: Prepare Apple App Store assets**

- Same screenshots in required dimensions (6.7", 6.5", 5.5")
- App preview video (optional but recommended)
- Description, keywords, support URL
- App privacy details (data collection disclosure)

**Step 3: Build release APK/AAB + IPA**

- Android: `flutter build appbundle --release` (AAB required for Play Store)
- iOS: requires Mac with Xcode (coordinate with BC on build machine)

**Step 4: Create store listings in draft**

Using BC's wife's developer account (temporary) or wait for company account.

---

### Task 4.10: Duplicate Table Constants Cleanup

**Why:** Two sources of truth for table names (`constants.dart` and `beautycita_core/tables.dart`). One will drift.

**Step 1: Determine which is authoritative**

`beautycita_core` is the shared package — it should be the single source. Check if both mobile and web import from core.

**Step 2: Remove duplicates from `constants.dart`**

If both apps import from core, delete the table name constants from `constants.dart` and update any imports.

---

## Execution Order Summary

| Day | Tasks | Focus |
|---|---|---|
| 1 | 1.1, 1.2, 1.3, 1.4, 1.5 | EMERGENCY: Firewall, .env cleanup, fix backups, R2, UptimeRobot |
| 2 | 2.1, 2.2 | CRITICAL: Payment race condition, stock overselling |
| 3 | 2.3, 2.4, 2.5 | CRITICAL: Error leaks, CORS, webhook signatures |
| 4-5 | 3.1, 3.2 | Grafana dashboards (infra + security) |
| 6-8 | 3.3, 3.4 | Tax withholding + financial reconciliation |
| 9-10 | 3.5, 3.6 | CEO dashboard + warm standby |
| 11-13 | 4.1, 4.2 | Toggle enforcement + feed algorithm |
| 14-16 | 4.3-4.7 | Bug fixes, cleanup, dead buttons |
| 17-19 | 4.8, 4.9 | Legal pages + app store prep |
| 20-21 | 4.10 + final QA | Cleanup + full end-to-end testing |

---

## Success Criteria

V1 is ready when ALL of the following are true:

- [ ] Firewall active, no exposed monitoring ports
- [ ] Backups running daily + uploading to R2, verified recoverable
- [ ] Payment flow is crash-safe (booking exists before charge)
- [ ] No internal errors leak to clients
- [ ] CORS restricted on payment endpoints
- [ ] Webhook signatures verified
- [ ] Tax withholding calculates correctly for RFC / no-RFC scenarios
- [ ] Financial reconciliation shows every peso traceable
- [ ] Grafana dashboards show server health, security, backups
- [ ] CEO Operations Dashboard live in web admin
- [ ] UptimeRobot alerts configured and tested
- [ ] Warm standby receiving replication
- [ ] Edge functions respect feature toggles
- [ ] Feed shows global content (not empty in small towns)
- [ ] Zero empty catch blocks in payment/auth paths
- [ ] Zero debugPrint in payment/auth paths
- [ ] Terms of Service + Privacy Policy published
- [ ] App store assets prepared, listing in draft
- [ ] No dead buttons in UI
- [ ] Failover runbook documented and tested
