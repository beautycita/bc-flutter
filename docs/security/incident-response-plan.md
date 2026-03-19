# Incident Response Plan — BeautyCita

**Last updated:** 2026-03-18
**Owner:** BC (CTO)
**Contact:** +52 (720) 677-7800 | beautycita.com@gmail.com

## Severity Levels

| Level | Description | Response Time | Example |
|-------|-------------|---------------|---------|
| P0 — Critical | Data breach, payment compromise, complete outage | Immediate (< 1 hour) | DB credentials leaked, Stripe key compromised |
| P1 — High | Service degradation, partial data exposure | < 4 hours | Edge functions down, WA API unreachable, RLS bypass |
| P2 — Medium | Minor vulnerability, no active exploitation | < 24 hours | Missing auth on non-critical endpoint, stale cert |
| P3 — Low | Cosmetic, informational | Next business day | Debug info exposed, minor config issue |

## Response Playbooks

### P0: Data Breach / Credential Compromise

1. **CONTAIN (0-15 min)**
   - Rotate compromised credentials immediately (see secret-rotation-policy.md)
   - If DB compromise: `docker compose down` the Supabase stack
   - If server compromise: contact Hetzner to isolate the VPS
   - Block attacker IP via `fail2ban-client set honeypot banip <IP>`

2. **ASSESS (15-60 min)**
   - Check Grafana dashboards for anomalous activity
   - Review nginx access logs: `tail -1000 /var/log/nginx/access.log | grep -i <indicator>`
   - Review edge function logs: `docker compose logs functions --since 1h`
   - Check Stripe Dashboard for unauthorized charges
   - Check Supabase audit log for unauthorized data access

3. **REMEDIATE (1-4 hours)**
   - Patch the vulnerability that was exploited
   - Deploy fix to production
   - Verify fix with targeted testing

4. **NOTIFY (within 72 hours — LFPDPPP requirement)**
   - If PII was exposed: notify INAI (Instituto Nacional de Transparencia)
   - Notify affected users via email + push notification
   - Prepare public statement if > 100 users affected
   - Document: what happened, what data, what we did, what we changed

5. **REVIEW (within 1 week)**
   - Post-mortem document
   - Update security policies
   - Implement additional monitoring

### P0: Complete Service Outage

1. **DIAGNOSE (0-5 min)**
   - Check UptimeRobot alerts (beautycita.com@gmail.com)
   - SSH to server: `ssh www-bc` — if unreachable, contact Hetzner
   - Check Docker: `docker ps` — are containers running?
   - Check nginx: `sudo nginx -t && sudo systemctl status nginx`
   - Check disk: `df -h` — is disk full?

2. **RESTORE (5-30 min)**
   - If Docker down: `cd /var/www/beautycita.com/bc-flutter/supabase-docker && docker compose up -d`
   - If nginx down: `sudo systemctl restart nginx`
   - If disk full: clear Docker logs `docker system prune -f`
   - If DB corrupted: restore from R2 backup (see backup recovery below)

3. **VERIFY**
   - Hit `https://beautycita.com` — does it load?
   - Hit health endpoint — does it return 200?
   - Test a booking flow end-to-end
   - Check Grafana for service metrics

### P0: Payment System Compromise

1. Immediately disable payments: set `enable_payments` toggle to false in app_config
2. Contact Stripe support: https://support.stripe.com
3. Review Stripe Dashboard > Events for unauthorized activity
4. Rotate Stripe keys (see secret-rotation-policy.md)
5. Audit all payments in the last 24 hours
6. If funds stolen: file police report + notify CONDUSEF

### Beautypi Compromise

1. SSH to beautypi via Tailscale: `ssh dmyl@100.93.1.103`
2. Stop all services: `sudo systemctl stop guestkey wa-api`
3. Rotate WA API token
4. Check for unauthorized WA messages sent
5. If Tailscale compromised: remove device from Tailscale admin panel
6. Re-image beautypi if rootkit suspected

## Backup Recovery

### Database
1. Latest backup on R2: `r2:beautycita-backups/`
2. Download: `aws s3 cp s3://beautycita-backups/latest.sql.gz /tmp/ --endpoint-url ...`
3. Restore: `gunzip -c /tmp/latest.sql.gz | docker exec -i supabase-db psql -U postgres`
4. Verify: `docker exec supabase-db psql -U postgres -c "SELECT count(*) FROM profiles;"`

### Full Server
1. Hetzner snapshots (if configured)
2. Manual rebuild from git repo + R2 backups
3. Estimated recovery time: 2-4 hours

## Communication Templates

### User Notification (Data Breach)
> Estimado usuario de BeautyCita,
>
> Detectamos un incidente de seguridad el [FECHA] que pudo haber afectado [DATOS]. Tomamos accion inmediata para contener el incidente y proteger tu informacion.
>
> **Que paso:** [DESCRIPCION BREVE]
> **Que datos:** [TIPO DE DATOS]
> **Que hicimos:** [ACCIONES TOMADAS]
> **Que debes hacer:** [RECOMENDACIONES - cambiar password, monitorear cuentas]
>
> Si tienes preguntas: legal@beautycita.com | +52 (720) 677-7800
>
> — Equipo BeautyCita

## Contacts

| Role | Name | Phone | Email |
|------|------|-------|-------|
| CTO / Owner | BC | +52 (720) 677-7800 | beautycita.com@gmail.com |
| Server hosting | Hetzner | support.hetzner.com | — |
| Payment processor | Stripe | support.stripe.com | — |
| Domain/DNS | Cloudflare | — | — |
| WA infrastructure | beautypi (local) | — | — |
| Legal | BeautyCita S.A. de C.V. | — | legal@beautycita.com |
