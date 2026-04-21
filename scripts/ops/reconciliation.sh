#!/usr/bin/env bash
# reconciliation.sh — manual run + view of accounting invariants
#
# Pulls anon key + cron secret from /var/www/.../supabase-docker/.env on prod
# (no secrets in this script). Requires ssh access to www-bc.
#
# Usage:
#   ./reconciliation.sh             — run all invariants now, print result
#   ./reconciliation.sh history     — last 20 reconciliation_log rows
#   ./reconciliation.sh offenders   — list current per-user/per-business drift
#   ./reconciliation.sh tail        — tail prod cron log
set -euo pipefail

CMD="${1:-run}"
ENV_FILE="/var/www/beautycita.com/bc-flutter/supabase-docker/.env"

run_watchdog() {
  ssh www-bc "
    ANON_KEY=\$(grep '^ANON_KEY=' ${ENV_FILE} | head -1 | cut -d= -f2-)
    CRON_SECRET=\$(grep '^CRON_SECRET=' ${ENV_FILE} | head -1 | cut -d= -f2-)
    curl -s -X POST \
      -H \"apikey: \${ANON_KEY}\" \
      -H \"x-cron-secret: \${CRON_SECRET}\" \
      http://localhost:8000/functions/v1/reconciliation-watchdog
  "
}

case "$CMD" in
  run)
    echo "═══ Reconciliation run ($(date -u +%Y-%m-%dT%H:%M:%SZ)) ═══"
    run_watchdog | python3 -m json.tool
    ;;

  history)
    echo "═══ Last 20 reconciliation_log rows ═══"
    ssh www-bc "docker exec supabase-db psql -U postgres -d postgres -c \"
      SELECT checked_at, check_name, status, drift::text || ' MXN' AS drift_mxn
      FROM reconciliation_log
      ORDER BY checked_at DESC
      LIMIT 20\""
    ;;

  offenders)
    echo "═══ Current drift offenders ═══"
    echo
    echo "User saldo drift:"
    ssh www-bc "docker exec supabase-db psql -U postgres -d postgres -c \"
      WITH per_user AS (
        SELECT p.id, p.username, p.full_name,
               p.saldo AS live_saldo,
               COALESCE((SELECT SUM(amount) FROM saldo_ledger WHERE user_id = p.id), 0) AS ledger_sum,
               p.saldo - COALESCE((SELECT SUM(amount) FROM saldo_ledger WHERE user_id = p.id), 0) AS drift
        FROM profiles p
      )
      SELECT id, COALESCE(username, full_name) AS who, live_saldo, ledger_sum, drift
      FROM per_user
      WHERE ABS(drift) > 0.01
      ORDER BY ABS(drift) DESC
      LIMIT 50\""
    echo
    echo "Business debt drift:"
    ssh www-bc "docker exec supabase-db psql -U postgres -d postgres -c \"
      WITH per_biz AS (
        SELECT b.id, b.name,
               b.outstanding_debt AS live_debt,
               COALESCE((SELECT SUM(remaining_amount) FROM salon_debts WHERE business_id = b.id AND remaining_amount > 0), 0) AS ledger_sum,
               b.outstanding_debt - COALESCE((SELECT SUM(remaining_amount) FROM salon_debts WHERE business_id = b.id AND remaining_amount > 0), 0) AS drift
        FROM businesses b
      )
      SELECT id, name, live_debt, ledger_sum, drift
      FROM per_biz
      WHERE ABS(drift) > 0.01
      ORDER BY ABS(drift) DESC
      LIMIT 50\""
    ;;

  tail)
    ssh www-bc 'tail -f /var/log/reconciliation.log'
    ;;

  *)
    echo "Usage: $0 {run|history|offenders|tail}"
    exit 1
    ;;
esac
