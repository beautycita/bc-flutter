#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# tiktok-feed-curate.sh — bulk-add TikTok URLs to the /explorar feed
# ─────────────────────────────────────────────────────────────────────────────
# Usage:
#   ./tiktok-feed-curate.sh path/to/seed.txt
#
# seed.txt format (one per line, '#' starts a comment):
#   maquillaje | MX | https://www.tiktok.com/@creator/video/7385…
#   cabello    | CO | https://www.tiktok.com/@other/video/7385…
#   unas       |    | https://vm.tiktok.com/ZM…   # region blank = leave null
#
# Calls the admin-only tiktok-feed-ingest edge fn with the service role key
# pulled from prod .env (via ssh). No logging of secrets.
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

SEED_FILE="${1:-}"
if [[ -z "$SEED_FILE" || ! -f "$SEED_FILE" ]]; then
  echo "usage: $0 path/to/seed.txt" >&2
  exit 1
fi

ENDPOINT="https://beautycita.com/supabase/functions/v1/tiktok-feed-ingest"

# Pull both keys from prod .env — anon key is technically public (served on
# every web page) but we keep it out of git to satisfy the deploy guardian.
keys=$(ssh www-bc "grep -E '^(SERVICE_ROLE_KEY|SUPABASE_SERVICE_ROLE_KEY|ANON_KEY|SUPABASE_ANON_KEY)=' /var/www/beautycita.com/bc-flutter/supabase-docker/.env 2>/dev/null")
SERVICE_KEY=$(echo "$keys" | grep -E '^(SERVICE_ROLE_KEY|SUPABASE_SERVICE_ROLE_KEY)=' | head -1 | cut -d= -f2-)
ANON_KEY=$(echo "$keys" | grep -E '^(ANON_KEY|SUPABASE_ANON_KEY)=' | head -1 | cut -d= -f2-)
if [[ -z "$SERVICE_KEY" || -z "$ANON_KEY" ]]; then
  echo "couldn't read Supabase keys from prod .env" >&2
  exit 1
fi

ok=0 fail=0
while IFS= read -r line || [[ -n "$line" ]]; do
  line="${line%%#*}"                               # strip comments
  line="$(echo "$line" | tr -d '\r' | sed 's/^ *//;s/ *$//')"
  [[ -z "$line" ]] && continue

  IFS='|' read -r category region url <<< "$line"
  category="$(echo "$category" | xargs)"
  region="$(echo "${region:-}" | xargs)"
  url="$(echo "$url" | xargs)"
  [[ -z "$category" || -z "$url" ]] && { echo "skip: malformed line → $line" >&2; continue; }

  payload=$(jq -n --arg u "$url" --arg c "$category" --arg r "$region" '
    {url:$u, category:$c} + (if $r=="" then {} else {creator_region:$r} end)
  ')

  resp=$(curl -sS -X POST "$ENDPOINT" \
    -H "apikey: $ANON_KEY" \
    -H "Authorization: Bearer $SERVICE_KEY" \
    -H "Content-Type: application/json" \
    -d "$payload") || { echo "fail: curl error → $url" >&2; ((fail++)); continue; }

  if echo "$resp" | jq -e '.upserted == true' >/dev/null 2>&1; then
    handle=$(echo "$resp" | jq -r '.creator_handle // "?"')
    vid=$(echo "$resp" | jq -r '.video_id')
    echo "ok   $category ${region:-  } $vid $handle"
    ((ok++))
  else
    err=$(echo "$resp" | jq -r '.error // .' 2>/dev/null | head -c 200)
    echo "fail $url → $err" >&2
    ((fail++))
  fi

  sleep 0.5    # polite
done < "$SEED_FILE"

echo
echo "done — $ok added/updated, $fail failed"
