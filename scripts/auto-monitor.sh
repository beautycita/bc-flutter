#!/bin/bash
# BeautyCita Auto-Monitor — runs health checks, auto-repairs, notifies on failure
# Designed to run as cron job every 15 minutes on beautypi
# Usage: ./auto-monitor.sh [--notify] [--repair]
#   --notify  Send WhatsApp on failure (default: log only)
#   --repair  Attempt auto-repair on failed services (default: report only)

set -uo pipefail

LOG_DIR="/home/dmyl/guestkey/logs"
LOG_FILE="$LOG_DIR/auto-monitor.log"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
BASE="https://beautycita.com/supabase/functions/v1"
ANON="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYW5vbiIsImlzcyI6InN1cGFiYXNlIiwiaWF0IjoxNzM1Njg5NjAwLCJleHAiOjE4OTM0NTYwMDB9.rz0oLwpK6HMsRI3PStAW3K1gl79d6z1PqqW8lvCtF9Q"
WA_API="http://100.78.37.84:3200"
WA_TOKEN="bc-wa-server-2026"
NOTIFY_NUMBER="523221429800"
BPI_URL="http://127.0.0.1:3210"
BPI_TOKEN="bc-bpi-admin-2026"

DO_NOTIFY=false
DO_REPAIR=false
for arg in "$@"; do
  case "$arg" in
    --notify) DO_NOTIFY=true ;;
    --repair) DO_REPAIR=true ;;
  esac
done

mkdir -p "$LOG_DIR"

FAILURES=()
REPAIRS=()

log() {
  echo "[$TIMESTAMP] $1" >> "$LOG_FILE"
}

# ── 1. System Health Check ────────────────────────────────────────────────────

health_json=$(curl -s --max-time 15 -H "apikey: $ANON" "$BASE/system-health" 2>/dev/null)
if [ -z "$health_json" ]; then
  FAILURES+=("system-health endpoint unreachable")
  log "FAIL: system-health endpoint unreachable"
else
  overall=$(echo "$health_json" | python3 -c "import sys,json; print(json.load(sys.stdin).get('overall','unknown'))" 2>/dev/null)

  if [ "$overall" != "operational" ]; then
    # Find which services are down
    down_services=$(echo "$health_json" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for name, info in data.get('services', {}).items():
    if info.get('status') not in ('operational',):
        print(f\"{name}: {info.get('status')} ({info.get('uptime','')})\")" 2>/dev/null)

    while IFS= read -r line; do
      [ -z "$line" ] && continue
      FAILURES+=("$line")
      log "FAIL: $line"
    done <<< "$down_services"
  else
    log "OK: all services operational"
  fi
fi

# ── 2. Critical Edge Function Smoke Tests ─────────────────────────────────────

check_endpoint() {
  local name="$1" method="$2" path="$3" expected="$4" body="${5:-{}}"
  local status

  if [ "$method" = "GET" ]; then
    status=$(curl -s -o /dev/null -w "%{http_code}" -H "apikey: $ANON" --max-time 10 "$BASE/$path" 2>/dev/null) || status="000"
  else
    status=$(curl -s -o /dev/null -w "%{http_code}" -X POST -H "apikey: $ANON" -H "Content-Type: application/json" -d "$body" --max-time 10 "$BASE/$path" 2>/dev/null) || status="000"
  fi

  if echo "$expected" | grep -q "$status"; then
    return 0
  else
    FAILURES+=("$name: got $status (expected $expected)")
    log "FAIL: $name returned $status (expected $expected)"
    return 1
  fi
}

# Core endpoints that must always work
check_endpoint "system-health" GET "system-health" "200"
check_endpoint "feed-public" GET "feed-public" "200"
check_endpoint "send-email-auth" POST "send-email" "401" '{}'
check_endpoint "curate-results" POST "curate-results" "400,401,500" '{}'
check_endpoint "stripe-webhook-auth" POST "stripe-webhook" "400" '{}'

# ── 3. Auto-Repair (if enabled) ──────────────────────────────────────────────

if $DO_REPAIR && [ ${#FAILURES[@]} -gt 0 ]; then
  # Map failure names to bpi service IDs
  declare -A SERVICE_MAP=(
    ["Lead Generator"]="lead-generator"
    ["WA Enrichment"]="wa-enrichment"
    ["IG Enrichment"]="ig-enrichment"
    ["GuestKey"]="guestkey"
    ["WA Validator"]="wa-validator"
  )

  for failure in "${FAILURES[@]}"; do
    for svc_name in "${!SERVICE_MAP[@]}"; do
      if echo "$failure" | grep -q "$svc_name"; then
        svc_id="${SERVICE_MAP[$svc_name]}"
        log "REPAIR: attempting $svc_id"

        result=$(curl -s --max-time 30 \
          -X POST \
          -H "Authorization: Bearer $BPI_TOKEN" \
          -H "Content-Type: application/json" \
          -d "{\"action\":\"repair\",\"service\":\"$svc_id\"}" \
          "$BPI_URL/api/bpi/action" 2>/dev/null)

        success=$(echo "$result" | python3 -c "import sys,json; print(json.load(sys.stdin).get('success',False))" 2>/dev/null)

        if [ "$success" = "True" ]; then
          REPAIRS+=("$svc_name: repaired successfully")
          log "REPAIRED: $svc_name"
        else
          REPAIRS+=("$svc_name: repair failed")
          log "REPAIR FAILED: $svc_name — $result"
        fi
      fi
    done
  done
fi

# ── 4. Notify (if enabled and failures exist) ────────────────────────────────

if $DO_NOTIFY && [ ${#FAILURES[@]} -gt 0 ]; then
  msg="*GuestKey Monitor*\n"
  msg+="$TIMESTAMP\n\n"
  msg+="*Fallos detectados:*\n"
  for f in "${FAILURES[@]}"; do
    msg+="- $f\n"
  done

  if [ ${#REPAIRS[@]} -gt 0 ]; then
    msg+="\n*Reparaciones:*\n"
    for r in "${REPAIRS[@]}"; do
      msg+="- $r\n"
    done
  fi

  curl -s --max-time 10 \
    -X POST \
    -H "Authorization: Bearer $WA_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"phone\":\"$NOTIFY_NUMBER\",\"message\":\"$(echo -e "$msg")\"}" \
    "$WA_API/api/wa/send" > /dev/null 2>&1

  log "NOTIFIED: WhatsApp sent to $NOTIFY_NUMBER"
fi

# ── 5. Summary ───────────────────────────────────────────────────────────────

if [ ${#FAILURES[@]} -eq 0 ]; then
  log "SUMMARY: all checks passed"
  exit 0
else
  log "SUMMARY: ${#FAILURES[@]} failure(s), ${#REPAIRS[@]} repair(s)"
  exit 1
fi
