# SOC 2 Controls Documentation Trail — BeautyCita

**Started:** 2026-03-20
**Owner:** BC (CTO)
**Purpose:** Document security controls for future SOC 2 Type II readiness

## Trust Service Criteria Coverage

### CC1 — Control Environment
- [x] Security policies documented (secret-rotation-policy.md, incident-response-plan.md)
- [x] Roles defined (superadmin, admin, rp, stylist, customer) with RLS enforcement
- [x] Code review process (Claude Code + manual review)
- [ ] Formal security training program (not yet — small team)

### CC2 — Communication and Information
- [x] Privacy policy (LFPDPPP compliant, 16 sections, updated 2026-03-19)
- [x] Terms of service (POS terms, commission structure, cancellation policies)
- [x] Cookie/storage disclosure (in-app Datos tab)
- [x] Incident response communication templates
- [x] User notification process documented

### CC3 — Risk Assessment
- [x] Security audit completed 2026-03-18 (4 CRITICAL, 5 HIGH, 11 MEDIUM — all fixed)
- [x] Pen test audit completed 2026-03-18
- [x] Ongoing monitoring via Grafana + UptimeRobot + honeypot
- [x] Fail2ban active (honeypot + SSH + nginx jails)

### CC4 — Monitoring Activities
- [x] System health endpoint (10 services monitored)
- [x] Smoke test diagnostics (superadmin, 10 live checks)
- [x] Grafana dashboards (5 dashboards, accessible from admin panel)
- [x] UptimeRobot (4 monitors, email alerts)
- [x] Honeypot (13 trap categories, fail2ban auto-ban on first hit)
- [x] Edge function logs (Docker compose logs)
- [x] Backup verification (automated, WA alert on failure)
- [ ] E2E automated monitoring cron (planned)

### CC5 — Control Activities
- [x] Authentication: JWT + biometric + role-based access
- [x] Authorization: RLS on all 65 tables, edge function auth checks
- [x] Encryption in transit: TLS 1.2+ with modern ciphers
- [x] Encryption at rest: Backup encryption (AES-256 via GPG)
- [x] Secret rotation policy documented
- [x] Firewall: UFW + fail2ban + nginx rate limiting
- [x] Input validation: PostgREST parameterized queries
- [x] debugPrint guards (kDebugMode, 51 files cleaned)
- [x] CI security scan (GitHub Actions: SAST + secret detection + dependency audit)

### CC6 — Logical and Physical Access Controls
- [x] SSH key-only authentication
- [x] Supabase Docker .env permissions (600)
- [x] Grafana behind nginx basic auth
- [x] Admin panel role-gated
- [x] Edge functions auth (JWT + role verification)
- [x] WA API token-authenticated
- [x] Server behind UFW (only 22, 80, 443 open)

### CC7 — System Operations
- [x] Automated daily backups (2 AM, encrypted, R2 offsite)
- [x] Automated weekly backups (Sunday 3 AM, with pg_restore verification)
- [x] Backup integrity verification (7-point check, WA alert)
- [x] Docker container auto-restart (restart: unless-stopped)
- [x] Systemd services for critical processes (WA API, wa-proxy)

### CC8 — Change Management
- [x] Git version control (main branch, PR workflow available)
- [x] Flutter analyzer (zero errors enforced before build)
- [x] CI security scan on push
- [x] Version tracking (pubspec.yaml + R2 version.json)
- [x] Feature toggles (20 toggles, admin-controlled)

### CC9 — Risk Mitigation
- [x] Payment processing delegated to Stripe (PCI-DSS Level 1)
- [x] No credit card data stored locally
- [x] Tax withholding calculations follow SAT regulations
- [x] Data scraper validation gate (only beauty businesses accepted)

## Evidence Log

| Date | Control | Evidence |
|------|---------|----------|
| 2026-03-10 | Security audit | 8 CRITICAL + 11 HIGH fixed |
| 2026-03-14 | Monitoring | Grafana + Prometheus operational |
| 2026-03-17 | Legal compliance | Privacy policy updated (LFPDPPP) |
| 2026-03-18 | Pen test | All CRITICAL/HIGH/MEDIUM fixed |
| 2026-03-18 | Hardening | TLS 1.2+, ssl_ciphers, server_tokens, Grafana auth |
| 2026-03-19 | Secret rotation | Policy documented |
| 2026-03-19 | Incident response | Plan documented with playbooks |
| 2026-03-19 | Backup encryption | AES-256 GPG enabled |
| 2026-03-19 | debugPrint cleanup | 51 files, kDebugMode guards |
| 2026-03-19 | CI pipeline | security-scan.yml workflow |
| 2026-03-20 | Backup verification | Automated 7-point check + WA alert |
| 2026-03-20 | WA infrastructure | 3 WA instances, rate-limited validation |
| 2026-03-20 | Data quality | Validation gate in scraper pipeline |
