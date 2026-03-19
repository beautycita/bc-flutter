# Secret Rotation Policy — BeautyCita

**Last updated:** 2026-03-18
**Owner:** BC (CTO)

## Rotation Schedule

| Secret | Location | Rotation Period | Last Rotated | Next Due |
|--------|----------|----------------|-------------|----------|
| Supabase JWT Secret | supabase-docker/.env | 6 months | 2026-02-01 | 2026-08-01 |
| Supabase Service Role Key | supabase-docker/.env | 6 months | 2026-02-01 | 2026-08-01 |
| Supabase Anon Key | supabase-docker/.env + app .env | 6 months | 2026-02-01 | 2026-08-01 |
| Stripe Secret Key | supabase-docker/.env | 12 months | 2026-01-15 | 2027-01-15 |
| Stripe Publishable Key | app .env | 12 months (rotates with secret) | 2026-01-15 | 2027-01-15 |
| Stripe Webhook Secret | supabase-docker/.env | 12 months | 2026-01-15 | 2027-01-15 |
| OpenAI API Key | supabase-docker/.env | 12 months | 2026-02-01 | 2027-02-01 |
| Beautypi WA API Token | supabase-docker/.env + guestkey/.env | 6 months | 2026-03-12 | 2026-09-12 |
| CRON_SECRET | supabase-docker/.env | 6 months | 2026-02-01 | 2026-08-01 |
| SMTP Password (IONOS) | supabase-docker/.env | 12 months | 2026-01-01 | 2027-01-01 |
| Google OAuth Client Secret | supabase-docker/.env | 12 months | 2026-01-15 | 2027-01-15 |
| R2 Access Key | local ~/.envnew.backup | 12 months | 2026-02-01 | 2027-02-01 |
| Grafana Admin Password | server config | 6 months | 2026-03-14 | 2026-09-14 |
| nginx .htpasswd_monitoring | /etc/nginx/ | 6 months | 2026-03-18 | 2026-09-18 |

## Rotation Procedure

### Supabase Keys (JWT, Service Role, Anon)
1. Generate new keys in `supabase-docker/.env`
2. Restart Supabase stack: `docker compose down && docker compose up -d`
3. Update app `.env` with new anon key
4. Build + deploy new APK
5. Update web app environment
6. Verify all edge functions work

### Stripe Keys
1. Roll keys in Stripe Dashboard (Settings > API Keys > Roll key)
2. Stripe provides 24h overlap for migration
3. Update `supabase-docker/.env`
4. Restart edge functions
5. Update webhook endpoint signing secret
6. Verify payment flow end-to-end

### WA API Token
1. Generate new token on beautypi WA API
2. Update `supabase-docker/.env` (BEAUTYPI_WA_TOKEN)
3. Update `guestkey/.env` (WA_API_TOKEN)
4. Restart edge functions
5. Restart guestkey service on beautypi
6. Verify phone verification + notifications

## Emergency Rotation (Compromise)
1. Immediately rotate the compromised secret
2. Check audit logs for unauthorized access
3. If Supabase JWT compromised: all active sessions are invalidated
4. If Stripe key compromised: contact Stripe support, rotate immediately
5. Document incident in incident log
6. Notify affected users if PII was exposed (LFPDPPP requirement: 72 hours)
