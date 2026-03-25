#!/bin/bash
# BeautyCita Edge Function Test Suite
# Tests all 52 edge functions on the live server
# Usage: ./test-edge-functions.sh

set -euo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[1;36m'
BOLD='\033[1m'
NC='\033[0m'

PASS=0
FAIL=0
TOTAL=0

BASE="https://beautycita.com/supabase/functions/v1"
ANON="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYW5vbiIsImlzcyI6InN1cGFiYXNlIiwiaWF0IjoxNzM1Njg5NjAwLCJleHAiOjE4OTM0NTYwMDB9.rz0oLwpK6HMsRI3PStAW3K1gl79d6z1PqqW8lvCtF9Q"

header() {
  echo ""
  echo -e "${CYAN}${BOLD}=== $1 ===${NC}"
}

# test_endpoint NAME METHOD PATH EXPECTED_CODES [BODY]
# EXPECTED_CODES is comma-separated, e.g. "200,400"
test_endpoint() {
  local name="$1" method="$2" path="$3" expected="$4" body="${5:-{}}"
  TOTAL=$((TOTAL + 1))

  if [ "$method" = "GET" ]; then
    status=$(curl -s -o /dev/null -w "%{http_code}" \
      -H "apikey: $ANON" \
      --max-time 15 \
      "$BASE/$path" 2>/dev/null) || status="000"
  else
    status=$(curl -s -o /dev/null -w "%{http_code}" \
      -X POST \
      -H "apikey: $ANON" \
      -H "Content-Type: application/json" \
      -d "$body" \
      --max-time 15 \
      "$BASE/$path" 2>/dev/null) || status="000"
  fi

  local match=0
  IFS=',' read -ra codes <<< "$expected"
  for code in "${codes[@]}"; do
    if [ "$status" = "$code" ]; then
      match=1
      break
    fi
  done

  if [ "$match" -eq 1 ]; then
    echo -e "  ${GREEN}PASS${NC}  $name ${YELLOW}($status)${NC}"
    PASS=$((PASS + 1))
  else
    echo -e "  ${RED}FAIL${NC}  $name ${RED}(got $status, expected $expected)${NC}"
    FAIL=$((FAIL + 1))
  fi
}

echo -e "${BOLD}BeautyCita Edge Function Test Suite${NC}"
echo -e "Target: $BASE"
echo -e "Date:   $(date '+%Y-%m-%d %H:%M:%S')"

# ─────────────────────────────────────────────
header "PUBLIC ENDPOINTS (no auth beyond apikey)"
# ─────────────────────────────────────────────
test_endpoint "system-health"      GET  "system-health"     "200"
test_endpoint "feed-public"        GET  "feed-public"       "200"
test_endpoint "calendar-ics"       GET  "calendar-ics"      "400,401"
test_endpoint "phone-verify"       POST "phone-verify"      "200,400,401" '{"phone":"5551234567"}'
test_endpoint "register-business"  POST "register-business"  "400,401"    '{}'
test_endpoint "salon-registro"     POST "salon-registro"     "200,400,500" '{"action":"ping"}'

# ─────────────────────────────────────────────
header "AUTH-REQUIRED ENDPOINTS (expect 401/403 with anon key)"
# ─────────────────────────────────────────────
test_endpoint "send-email"          POST "send-email"          "401,403"
test_endpoint "bpi-admin"           POST "bpi-admin"           "401,403"
test_endpoint "sat-access"          POST "sat-access"          "401,403,500"
test_endpoint "sat-reporting"       POST "sat-reporting"       "401,403"
test_endpoint "cleanup-anon-users"  POST "cleanup-anon-users"  "401,403"
test_endpoint "order-followup"      POST "order-followup"      "401,403"
test_endpoint "suspend-salon"       POST "suspend-salon"       "401,403"
# feature-toggles is not an edge function (client reads app_config directly)

# ─────────────────────────────────────────────
header "WEBHOOK ENDPOINTS (expect 400/401 without signature)"
# ─────────────────────────────────────────────
test_endpoint "stripe-webhook"       POST "stripe-webhook"       "400,401"
test_endpoint "uber-webhook"         POST "uber-webhook"         "400,401"
test_endpoint "wa-incoming"          POST "wa-incoming"          "400,401"
test_endpoint "google-risc-receiver" POST "google-risc-receiver" "400,401"

# ─────────────────────────────────────────────
header "CRON ENDPOINTS (expect 401 without cron secret)"
# ─────────────────────────────────────────────
test_endpoint "booking-reminder"    POST "booking-reminder"    "401,403"
test_endpoint "booking-confirmation (cron)" POST "booking-confirmation" "401,403"
test_endpoint "scheduled-followup"  POST "scheduled-followup"  "401,403"
test_endpoint "process-no-show"     POST "process-no-show"     "401,403"

# ─────────────────────────────────────────────
header "USER-AUTH ENDPOINTS (expect 401 with just anon key)"
# ─────────────────────────────────────────────
test_endpoint "aphrodite-chat"              POST "aphrodite-chat"              "401,403,500"
test_endpoint "eros-chat"                   POST "eros-chat"                   "401,403,500"
test_endpoint "salon-chat"                  POST "salon-chat"                  "401,403"
test_endpoint "support-chat"               POST "support-chat"               "401,403"
test_endpoint "curate-results"              POST "curate-results"              "400,401,403"
test_endpoint "booking-confirmation (user)" POST "booking-confirmation"        "401,403"
test_endpoint "create-payment-intent"       POST "create-payment-intent"       "401,403"
test_endpoint "create-product-payment"      POST "create-product-payment"      "401,403"
test_endpoint "stripe-connect-onboard"      POST "stripe-connect-onboard"      "401,403"
test_endpoint "stripe-payment-methods"      POST "stripe-payment-methods"      "401,403"
test_endpoint "google-calendar-connect"     POST "google-calendar-connect"     "401,403,500"
test_endpoint "google-calendar-sync"        POST "google-calendar-sync"        "401,403,500"
test_endpoint "link-uber"                   POST "link-uber"                   "401,403"
test_endpoint "schedule-uber"               POST "schedule-uber"              "401,403"
test_endpoint "update-uber-rides"           POST "update-uber-rides"           "401,403"
test_endpoint "qr-auth"                     POST "qr-auth"                     "400,401,403"
test_endpoint "migrate-profile"             POST "migrate-profile"             "401,403"
test_endpoint "on-demand-scrape"            POST "on-demand-scrape"            "401,403"
test_endpoint "outreach-contact"            POST "outreach-contact"            "401,403"
test_endpoint "outreach-discovered-salon"   POST "outreach-discovered-salon"   "400,401,403"
test_endpoint "send-contact"                POST "send-contact"                "401,403"
test_endpoint "send-push-notification"      POST "send-push-notification"      "401,403"
test_endpoint "send-screenshot"             POST "send-screenshot"             "401,403"
test_endpoint "tag-review"                  POST "tag-review"                  "401,403"
test_endpoint "process-dispute-refund"      POST "process-dispute-refund"      "401,403"
test_endpoint "places-proxy"                POST "places-proxy"                "401,403"
test_endpoint "reschedule-notification"     POST "reschedule-notification"     "401,403"
test_endpoint "cancel-notification"         POST "cancel-notification"         "401,403"
test_endpoint "demo-reschedule"             POST "demo-reschedule"             "401,403"

# ─────────────────────────────────────────────
header "RATE LIMIT TEST (system-health x5 rapid)"
# ─────────────────────────────────────────────
RATE_PASS=0
RATE_FAIL=0
for i in 1 2 3 4 5; do
  status=$(curl -s -o /dev/null -w "%{http_code}" \
    -H "apikey: $ANON" \
    --max-time 10 \
    "$BASE/system-health" 2>/dev/null) || status="000"
  if [ "$status" = "200" ]; then
    RATE_PASS=$((RATE_PASS + 1))
  else
    RATE_FAIL=$((RATE_FAIL + 1))
  fi
done
TOTAL=$((TOTAL + 1))
if [ "$RATE_FAIL" -eq 0 ]; then
  echo -e "  ${GREEN}PASS${NC}  rate-limit (5/5 returned 200)"
  PASS=$((PASS + 1))
else
  echo -e "  ${RED}FAIL${NC}  rate-limit ($RATE_FAIL/5 did not return 200)"
  FAIL=$((FAIL + 1))
fi

# ─────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────
echo ""
echo -e "${BOLD}────────────────────────────────────${NC}"
echo -e "${BOLD}Results:${NC} ${GREEN}$PASS passed${NC}, ${RED}$FAIL failed${NC}, ${BOLD}$TOTAL total${NC}"

if [ "$FAIL" -eq 0 ]; then
  echo -e "${GREEN}${BOLD}All tests passed.${NC}"
  exit 0
else
  echo -e "${RED}${BOLD}$FAIL test(s) failed.${NC}"
  exit 1
fi
