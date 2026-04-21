#!/usr/bin/env bash
# 04-cutover.sh — Swap DNS from IONOS → Vultr after dual-write window.
#
# This script is intentionally manual / interactive. DNS cutover is a one-way
# door even with rollback — readers will see stale records for TTL-of-old-record
# minutes after the change. Don't automate this end-to-end.
#
# Pre-cutover checklist:
#   [ ] 03-replicate.sh ran successfully
#   [ ] curl https://${VULTR_INSTANCE_IP}/healthz returns 200
#   [ ] Edge functions respond on new host
#   [ ] DB row counts match between IONOS and Vultr (sanity)
#   [ ] DNS TTL on beautycita.com A record dropped to 60s 24h ago
#   [ ] WA tunnel re-attached (autossh from beautypi to new host:3201)
#   [ ] Stripe webhook URL updated to new host (or DNS-based)
#   [ ] R2 bucket access from new host verified
#   [ ] Cron jobs scheduled on new host
#
# Cutover steps (run manually, in order):
#   1. Drop DNS TTL to 60s if not already (do this 24h+ in advance)
#   2. Stop accepting new bookings on IONOS (set toggle enable_booking=false briefly)
#   3. Final DB dump+restore (catch-up since 03-replicate.sh)
#   4. Update DNS A record beautycita.com → ${VULTR_INSTANCE_IP}
#   5. Wait 60s for propagation
#   6. Re-enable booking toggle
#   7. Monitor Doc + Grafana for 1h
#   8. Keep IONOS hot for 7 days as rollback target
#
# Rollback (if Vultr blows up post-cutover):
#   - Update DNS A record back to IONOS IP (74.208.218.18)
#   - DB writes during the broken window may need manual reconciliation
#
# This script just shows the checklist. Doing it for you is a foot-gun.
set -euo pipefail

source ~/.config/vultr/instance.env 2>/dev/null || { echo "Run 02-provision.sh first"; exit 1; }

cat <<EOF
DNS Cutover — Manual Steps
═══════════════════════════════════════════════════════════════
Source (current prod):  IONOS  74.208.218.18
Target (new prod):      Vultr MX  ${VULTR_INSTANCE_IP}

Pre-flight (run yourself):
  ssh root@${VULTR_INSTANCE_IP} 'docker ps --format "{{.Names}}\t{{.Status}}" | grep -v healthy && echo OK'
  curl -k -m 5 https://${VULTR_INSTANCE_IP}/healthz
  ssh root@${VULTR_INSTANCE_IP} 'docker exec supabase-db psql -U postgres -d postgres -c "SELECT count(*) FROM appointments"'

Then update DNS at your registrar (or Cloudflare):
  beautycita.com  A  ${VULTR_INSTANCE_IP}  TTL=60

Watch propagation:
  watch -n 5 dig +short beautycita.com

Once DNS flips, monitor 1h:
  ssh root@${VULTR_INSTANCE_IP} 'docker logs -f supabase-edge-functions 2>&1 | grep -iE "error|warn"'
  Doc dashboard: https://debug.beautycita.com/grafana/

Rollback if needed:
  Revert DNS to 74.208.218.18 (IONOS). TTL=60 means recovery in ~1 minute.

Keep IONOS running for 7 days post-cutover before tearing down.
═══════════════════════════════════════════════════════════════
EOF
