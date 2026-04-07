#!/bin/bash
# BeautyCita Production Watchdog
# Runs every minute via cron. Checks critical services, auto-repairs after 2 consecutive failures.

set -uo pipefail

# === Configuration ===
LOCK_FILE="/tmp/watchdog.lock"
LOCK_MAX_AGE=300
FAILURE_DIR="/tmp/watchdog_failures"
NUCLEAR_COOLDOWN_FILE="/tmp/watchdog_nuclear_cooldown"
NUCLEAR_COOLDOWN_SECS=600
MAX_FAILURES=2
LOG_FILE="/var/log/watchdog.log"
METRICS_DIR="/var/www/beautycita.com/monitoring/textfile_collector"
METRICS_FILE="${METRICS_DIR}/watchdog-metrics.prom"
SUPABASE_DIR="/var/www/beautycita.com/bc-flutter/supabase-docker"
WA_API="http://100.78.37.84:3200/api/wa/send"
WA_PHONE="5217206777800"
VERBOSE="${WATCHDOG_VERBOSE:-0}"
SUDO_PASS="${WATCHDOG_SUDO_PASS:?Set WATCHDOG_SUDO_PASS env var}"

SERVICES=("nginx" "supabase_kong" "supabase_db" "supabase_auth" "supabase_functions" "supabase_realtime")

# === Helpers ===
timestamp() { date -u +"%Y-%m-%dT%H:%M:%S"; }
log_ok()     { [[ "$VERBOSE" == "1" ]] && echo "$(timestamp) [CHECK] $1: OK"; return 0; }
log_warn()   { echo "$(timestamp) [WARN] $1"; }
log_repair() { echo "$(timestamp) [REPAIR] $1"; }
log_crit()   { echo "$(timestamp) [CRITICAL] $1"; }

get_failure_count() { local f="${FAILURE_DIR}/$1"; [[ -f "$f" ]] && cat "$f" || echo 0; }
set_failure_count() { echo "$2" > "${FAILURE_DIR}/$1"; }

get_repair_total() { local f="/tmp/watchdog_repairs_$1"; [[ -f "$f" ]] && cat "$f" || echo 0; }
inc_repair_total() { local f="/tmp/watchdog_repairs_$1"; echo $(( $(get_repair_total "$1") + 1 )) > "$f"; }

get_last_repair_ts() { local f="/tmp/watchdog_last_repair_$1"; [[ -f "$f" ]] && cat "$f" || echo 0; }
set_last_repair_ts() { date +%s > "/tmp/watchdog_last_repair_$1"; }

send_wa_alert() {
  local service="$1" action="$2" result="$3"
  curl -s --max-time 3 -o /dev/null "$WA_API" 2>/dev/null || { log_warn "WhatsApp API unreachable, skipping alert"; return 0; }
  curl -s -X POST "$WA_API" \
    -H "Content-Type: application/json" \
    -d "{\"phone\":\"${WA_PHONE}\",\"message\":\"*BeautyCita Watchdog*\nService: ${service}\nAction: ${action}\nResult: ${result}\nTime: $(date)\"}" \
    --max-time 5 >/dev/null 2>&1 || true
}

# === Lock ===
acquire_lock() {
  if [[ -f "$LOCK_FILE" ]]; then
    local lock_age=$(( $(date +%s) - $(stat -c %Y "$LOCK_FILE" 2>/dev/null || echo 0) ))
    if (( lock_age > LOCK_MAX_AGE )); then
      log_warn "Stale lock (${lock_age}s), removing"
      rm -f "$LOCK_FILE"
    else
      exit 0
    fi
  fi
  echo $$ > "$LOCK_FILE"
  trap 'rm -f "$LOCK_FILE"' EXIT
}

# === Health Checks ===
check_nginx() {
  local code
  code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 http://localhost:80/ 2>/dev/null || echo "000")
  [[ "$code" != "000" ]]
}

check_supabase_kong() {
  local code
  code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 http://localhost:8000/rest/v1/ 2>/dev/null || echo "000")
  [[ "$code" == "200" || "$code" == "401" ]]
}

check_supabase_db() {
  docker exec supabase-db pg_isready -U postgres >/dev/null 2>&1
}

check_supabase_auth() {
  # Auth port not exposed to host — use Docker's built-in healthcheck
  local health
  health=$(docker inspect supabase-auth --format='{{.State.Health.Status}}' 2>/dev/null)
  [[ "$health" == "healthy" ]]
}

check_supabase_functions() {
  local status
  status=$(docker ps --filter name='^supabase-edge-functions$' --format '{{.Status}}' 2>/dev/null)
  [[ -n "$status" && "$status" == *"Up"* ]]
}

check_supabase_realtime() {
  local status
  status=$(docker ps --filter name='supabase-realtime' --format '{{.Status}}' 2>/dev/null)
  [[ -n "$status" && "$status" == *"Up"* ]]
}

# === Repairs ===
repair_nginx()              { echo "$SUDO_PASS" | sudo -S systemctl restart nginx 2>/dev/null; }
repair_supabase_kong()      { cd "$SUPABASE_DIR" && docker compose restart kong 2>/dev/null; }
repair_supabase_db()        { cd "$SUPABASE_DIR" && docker compose restart db 2>/dev/null; }
repair_supabase_auth()      { cd "$SUPABASE_DIR" && docker compose restart auth 2>/dev/null; }
repair_supabase_functions() { cd "$SUPABASE_DIR" && docker compose restart functions 2>/dev/null; }
repair_supabase_realtime()  { cd "$SUPABASE_DIR" && docker compose restart realtime 2>/dev/null; }

# === Nuclear Option ===
nuclear_restart() {
  if [[ -f "$NUCLEAR_COOLDOWN_FILE" ]]; then
    local age=$(( $(date +%s) - $(stat -c %Y "$NUCLEAR_COOLDOWN_FILE" 2>/dev/null || echo 0) ))
    if (( age < NUCLEAR_COOLDOWN_SECS )); then
      log_crit "Nuclear cooldown active (${age}s/${NUCLEAR_COOLDOWN_SECS}s), skipping"
      return 1
    fi
  fi

  log_crit "NUCLEAR: nginx + db + kong all down. Restarting Docker daemon..."
  touch "$NUCLEAR_COOLDOWN_FILE"
  send_wa_alert "ALL SERVICES" "NUCLEAR: Restarting Docker daemon" "IN PROGRESS"

  echo "$SUDO_PASS" | sudo -S systemctl restart docker 2>/dev/null
  sleep 30

  local recovered=true
  check_nginx    || recovered=false
  check_supabase_db   || recovered=false
  check_supabase_kong || recovered=false

  if $recovered; then
    log_repair "NUCLEAR: Stack recovered after Docker restart"
    send_wa_alert "ALL SERVICES" "NUCLEAR: Docker restart" "RECOVERED"
  else
    log_crit "NUCLEAR: Stack still down. Manual intervention required."
    send_wa_alert "ALL SERVICES" "NUCLEAR: Docker restart FAILED" "CRITICAL - Manual intervention required"
  fi
}

# === Metrics ===
write_metrics() {
  mkdir -p "$METRICS_DIR"
  local now=$(date +%s)
  {
    echo "# HELP beautycita_watchdog_last_run_timestamp Last watchdog run"
    echo "# TYPE beautycita_watchdog_last_run_timestamp gauge"
    echo "beautycita_watchdog_last_run_timestamp ${now}"
    echo ""
    echo "# HELP beautycita_watchdog_service_up Whether each service is up (1=up, 0=down)"
    echo "# TYPE beautycita_watchdog_service_up gauge"
    for svc in "${SERVICES[@]}"; do
      echo "beautycita_watchdog_service_up{service=\"${svc}\"} ${SVC_UP[$svc]:-1}"
    done
    echo ""
    echo "# HELP beautycita_watchdog_repairs_total Total repairs performed"
    echo "# TYPE beautycita_watchdog_repairs_total counter"
    for svc in "${SERVICES[@]}"; do
      echo "beautycita_watchdog_repairs_total{service=\"${svc}\"} $(get_repair_total "$svc")"
    done
    echo ""
    echo "# HELP beautycita_watchdog_last_repair_timestamp Last repair attempt timestamp per service"
    echo "# TYPE beautycita_watchdog_last_repair_timestamp gauge"
    for svc in "${SERVICES[@]}"; do
      echo "beautycita_watchdog_last_repair_timestamp{service=\"${svc}\"} $(get_last_repair_ts "$svc")"
    done
  } > "${METRICS_FILE}.tmp"
  mv "${METRICS_FILE}.tmp" "$METRICS_FILE"
}

# === Main ===
main() {
  acquire_lock
  mkdir -p "$FAILURE_DIR" "$METRICS_DIR"

  declare -A SVC_UP
  local nginx_down=false db_down=false kong_down=false

  for svc in "${SERVICES[@]}"; do
    if "check_${svc}"; then
      SVC_UP[$svc]=1
      set_failure_count "$svc" 0
      log_ok "$svc"
    else
      SVC_UP[$svc]=0
      local cur=$(( $(get_failure_count "$svc") + 1 ))
      set_failure_count "$svc" "$cur"

      if (( cur < MAX_FAILURES )); then
        log_warn "${svc}: FAIL (attempt ${cur}/${MAX_FAILURES})"
      else
        log_repair "${svc}: restarting... (${cur} consecutive failures)"
        "repair_${svc}"
        sleep 5

        if "check_${svc}"; then
          log_repair "${svc}: RECOVERED"
          SVC_UP[$svc]=1
          set_failure_count "$svc" 0
          inc_repair_total "$svc"
          set_last_repair_ts "$svc"
          send_wa_alert "$svc" "Restarted" "RECOVERED"
        else
          log_crit "${svc}: STILL DOWN after restart"
          inc_repair_total "$svc"
          set_last_repair_ts "$svc"
          send_wa_alert "$svc" "Restarted" "STILL DOWN - needs manual check"
        fi
      fi

      [[ "$svc" == "nginx" ]] && nginx_down=true
      [[ "$svc" == "supabase_db" ]] && db_down=true
      [[ "$svc" == "supabase_kong" ]] && kong_down=true
    fi
  done

  # Nuclear: all three critical services down after repair attempts
  if $nginx_down && $db_down && $kong_down; then
    nuclear_restart
  fi

  write_metrics
}

main "$@"
