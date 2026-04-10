# Doc Holiday v2 — Strict Build Plan

**Date:** 2026-04-10
**Executor:** bc box Claude session
**Prerequisite:** Django v1 MCP server + overlay already running on bc box
**Architecture doc:** /home/bc/futureBeauty/docs/plans/2026-04-09-django-v2-architecture.md

---

## Rules

1. Each task has a DONE condition. Do not mark done until the condition passes.
2. Build in order. Do not skip ahead.
3. If a task takes SSH access to www-bc, test the SSH connection first.
4. All new code goes in `/home/bc/django/src/` following the directory structure in the architecture doc.
5. After each phase: `npm run build` must succeed, existing MCP tools must still work.
6. Commit after each phase with message format: `Doc Holiday v2: Phase X — <description>`

---

## Phase 1: Daemon Mode

**Goal:** Django runs as a systemd service 24/7, serving both MCP (stdio) and HTTP (port 3101).

### Task 1.1: Create daemon entry point
- **File:** `src/daemon/daemon.ts`
- **What:** HTTP server on port 3101 with `/health`, `/webhook/sentry`, `/webhook/uptime` endpoints
- **Health endpoint returns:** `{ status: "ok", uptime: <seconds>, version: "2.0.0", findings: <count> }`
- **DONE when:** `curl http://localhost:3101/health` returns 200 with valid JSON

### Task 1.2: Create systemd service
- **File:** `/etc/systemd/system/doc-holiday.service`
- **Content:** Use the service definition from the architecture doc (User=bc, WorkingDirectory=/home/bc/django, ExecStart=node dist/daemon.js)
- **DONE when:** `systemctl status doc-holiday` shows active (running) AND survives `systemctl restart doc-holiday`

### Task 1.3: Verify MCP still works
- **Test:** Open Claude Code, run `django_brief` — must return valid response
- **DONE when:** All 40 existing MCP tools respond correctly

### Task 1.4: Add repair_log table to SQLite
- **Schema:**
```sql
CREATE TABLE IF NOT EXISTS repair_log (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  timestamp TEXT NOT NULL DEFAULT (datetime('now')),
  source TEXT NOT NULL,          -- 'sentry' | 'uptime' | 'cron' | 'manual'
  pattern TEXT,                  -- matched pattern name or NULL
  description TEXT NOT NULL,
  action_taken TEXT,
  result TEXT,                   -- 'success' | 'failed' | 'escalated'
  details TEXT                   -- JSON blob with before/after state
);
```
- **DONE when:** Table exists and INSERT/SELECT works

---

## Phase 2: Production Monitor

### Task 2.1: Sentry webhook receiver
- **File:** `src/monitor/sentry.ts`
- **Endpoint:** POST `/webhook/sentry`
- **Logic:**
  1. Parse Sentry webhook payload (verify `sentry-hook-signature` header if secret configured)
  2. Extract: error message, stack trace, file paths, event ID
  3. Cross-reference file paths with findings DB — if existing finding matches, link them
  4. If no match → create new finding (priority P1, lens "production", status "open")
  5. Log to repair_log
- **DONE when:** A test POST to `/webhook/sentry` with a mock payload creates a finding in the DB

### Task 2.2: Uptime Kuma webhook receiver
- **File:** `src/monitor/uptime.ts`
- **Endpoint:** POST `/webhook/uptime`
- **Logic:**
  1. Parse Uptime Kuma heartbeat payload
  2. If status=down → SSH to www-bc, check `docker ps` for the service
  3. If container not running → `docker compose restart <service>`
  4. Log all actions to repair_log
  5. Send WA alert to BC (POST to beautypi WA API at 100.93.1.103:3200)
- **DONE when:** A test POST with `{"monitor":{"name":"supabase"},"heartbeat":{"status":0}}` triggers SSH check and logs to repair_log

### Task 2.3: SSH utility module
- **File:** `src/monitor/ssh.ts`
- **What:** Wrapper around ssh2 for executing commands on www-bc
- **Config:** Read SSH key from `~/.ssh/id_ed25519`, host from env `WWW_BC_HOST` (default: www-bc)
- **Methods:**
  - `exec(command: string): Promise<{ stdout: string, stderr: string, code: number }>`
  - `checkContainer(name: string): Promise<boolean>`
  - `restartContainer(name: string): Promise<boolean>`
- **DONE when:** `ssh.exec("uptime")` returns valid output from www-bc

### Task 2.4: WA alert utility
- **File:** `src/monitor/alert.ts`
- **What:** Send WhatsApp message to BC's phone via beautypi WA API
- **Endpoint:** POST `http://100.93.1.103:3200/api/wa/send`
- **Format:** `{ phone: "+521XXXXXXXXXX", message: "🤠 Doc Holiday: <alert>" }`
- **Fallback:** If WA fails, log to repair_log with result "escalated"
- **DONE when:** Test alert sends a WA message to BC's phone (or logs failure gracefully)

### Task 2.5: Health check cron
- **File:** `src/monitor/health-cron.ts`
- **What:** node-cron job running every 5 minutes
- **Checks:**
  1. SSH to www-bc → `docker ps --format '{{.Names}} {{.Status}}'` → flag any unhealthy/exited containers
  2. SSH to www-bc → `df -h /` → alert if disk > 90%
  3. Query Supabase pg_cron via SSH → `psql -c "SELECT * FROM cron.job_run_details WHERE status='failed' ORDER BY end_time DESC LIMIT 5"` → flag consecutive failures
- **DONE when:** Cron runs, produces a health snapshot, logs to DB

---

## Phase 3: Deploy Guardian

### Task 3.1: Pre-push hook script
- **File:** `/home/bc/futureBeauty/.git/hooks/pre-push`
- **Checks (in order, fail-fast):**
  1. Build number in pubspec.yaml > last pushed build number (read from `.last_pushed_build`)
  2. `git diff --cached --diff-filter=ACMR` has no secrets (scan for patterns: `sk_live_`, `pk_live_`, `SUPABASE_SERVICE_ROLE_KEY=`, passwords, API tokens)
  3. No `Colors.white` or `Colors.black` in new/modified Dart lines
  4. No `--no-tree-shake-icons` in any script
  5. `flutter analyze` exits 0 (from beautycita_app/ AND beautycita_web/)
- **On pass:** Write current build number to `.last_pushed_build`
- **On fail:** Print clear error with the failing check name and how to fix
- **DONE when:** A push without bumping the build number is BLOCKED with a clear message

### Task 3.2: Post-deploy verification
- **File:** `src/guardian/post-deploy.ts`
- **Triggered by:** HTTP POST `/webhook/deploy` (called from deploy script)
- **Checks:**
  1. Fetch `https://beautycita.com/version.json` → verify buildNumber matches expected
  2. Fetch `https://beautycita.com/apk/version.json` → same check
  3. HEAD request to APK URL → verify 200 + content-type application/vnd.android.package-archive
  4. POST to 3 critical edge functions with test payloads → verify non-500
- **On fail:** WA alert to BC with which check failed
- **DONE when:** Running verification after a deploy returns all-pass, and a deliberate version mismatch triggers WA alert

---

## Phase 4: Enhanced MCP Tools

### Task 4.1: Add new tools to MCP server
- **File:** `src/mcp/tools.ts` (extend existing)
- **New tools:**

| Tool | Returns |
|------|---------|
| `django_health` | Full production health: containers, disk, DB size, last errors, cron status |
| `django_repair_log` | Last N repairs from repair_log table |
| `django_deploy_check` | Run pre-push checklist manually, return results |
| `django_sentry_recent` | Last 10 Sentry errors (from findings DB, source=sentry) |
| `django_uptime` | Service uptime from last 24h of health checks |
| `django_cron_status` | pg_cron job health from last check |

- **DONE when:** Each tool is callable from Claude Code and returns meaningful data

---

## Phase 5: Autonomous Repair

### Task 5.1: Known pattern database
- **File:** `src/repair/patterns.ts`
- **What:** Array of pattern objects:
```typescript
interface RepairPattern {
  name: string;
  match: (event: MonitorEvent) => boolean;  // detection function
  fix: (ssh: SSHClient) => Promise<RepairResult>;  // repair action
  verify: (ssh: SSHClient) => Promise<boolean>;  // post-fix verification
}
```
- **Initial patterns:** All 7 from the architecture doc (container crash, pg_cron permission, missing app_config, RLS recursion, edge function boot, SSL cert, disk space)
- **DONE when:** Each pattern has match + fix + verify functions that compile

### Task 5.2: Repair executor
- **File:** `src/repair/executor.ts`
- **Flow:** Event → pattern match → execute fix → verify → log to repair_log → alert if failed
- **Safety:** Max 3 repair attempts per pattern per hour (prevent repair loops)
- **DONE when:** Simulated container-down event triggers restart → verify → log chain

### Task 5.3: Wire monitors to repair engine
- **What:** Sentry webhook, Uptime Kuma webhook, and health cron all route events through the repair executor
- **DONE when:** End-to-end test: kill a test container → Uptime Kuma fires webhook → Doc Holiday restarts it → logs repair → sends WA alert

---

## Verification Checklist (run after all phases)

- [ ] `systemctl status doc-holiday` → active
- [ ] `curl localhost:3101/health` → 200 with uptime > 0
- [ ] Claude Code: `django_brief` → works
- [ ] Claude Code: `django_health` → shows real production data
- [ ] Claude Code: `django_repair_log` → shows test repairs
- [ ] Pre-push hook blocks bad push
- [ ] Post-deploy verification catches version mismatch
- [ ] Sentry webhook creates finding
- [ ] Uptime webhook triggers container check
- [ ] Health cron runs every 5 minutes
- [ ] WA alerts reach BC's phone

---

## Dependencies to Install

```bash
cd /home/bc/django
npm install ssh2 node-cron
npm install -D @types/ssh2
```

---

## Environment Variables (add to systemd service or .env)

```
WWW_BC_HOST=www-bc
SENTRY_WEBHOOK_SECRET=<generate>
WA_API_URL=http://100.93.1.103:3200
WA_API_TOKEN=<from beautypi>
BC_PHONE=+521XXXXXXXXXX
```
