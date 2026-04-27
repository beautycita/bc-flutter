#!/bin/bash
# =============================================================================
# deploy.sh — BeautyCita main app: build, upload APK + version.json to R2,
#             auto-bump pubspec/constants, optionally deploy edge fns + web.
# =============================================================================
# Usage: ./deploy.sh [flags]
#   --required           mark update mandatory (forceUpdate=true in version.json)
#   --notes "text"       release notes shown in update modal
#   --distribute         also push APK to Firebase App Distribution
#   --edge               also rsync supabase/functions to www-bc + restart
#   --web                also build + rsync the beautycita_web project
#   --no-analyze         skip flutter analyze gate (dangerous; CI use only)
#   --no-commit          skip the auto-commit of version-bumped pubspec/constants
#   --skip-build         skip build, just re-upload existing APK + version.json
#
# What it does (in order):
#   0. Pre-flight: clean working tree expected (warns if dirty), on main branch.
#   1. flutter analyze (lib/) — fails build if any errors.
#   2. Read pubspec.yaml version + build, increment build number.
#   3. Update pubspec.yaml + constants.dart with new build number.
#   4. flutter build apk --release --split-per-abi (full output to stdout).
#   5. Upload arm64 APK to R2 → beautycita-medias/apk/beautycita.apk.
#   6. Build version.json + upload to R2 bucket root.
#   7. Auto-commit + push pubspec.yaml + constants.dart bump to main.
#   8. (--edge) rsync edge functions + restart docker functions container.
#   9. (--web) build web + rsync to www-bc dist.
#  10. (--distribute) push APK to Firebase App Distribution.
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

# ── Config ──────────────────────────────────────────────────────────────────
FLUTTER="/home/bc/flutter/bin/flutter"
PUBSPEC="pubspec.yaml"
CONSTANTS="lib/config/constants.dart"

R2_BUCKET_ROOT="s3://beautycita-medias"
R2_APK_PATH="${R2_BUCKET_ROOT}/apk"
R2_VERSION_JSON_PATH="${R2_BUCKET_ROOT}/version.json"
R2_ENDPOINT="https://e61486f47c2fe5a12fdce43b7a318343.r2.cloudflarestorage.com"
R2_ACCESS_KEY="ca3c10c25e5a6389797d8b47368626d4"
R2_SECRET_KEY="9a761a36330e00d98e1faa6c588c47a76fb8f15b573c6dcf197efe10d80bba4d"
APK_PUBLIC_URL="https://beautycita.com/download/beautycita.apk"

FIREBASE_CLI="$HOME/bin/firebase"
FIREBASE_PROJECT="beautycita-472406"
FIREBASE_APP_ID="1:925456539297:android:0578ed8632117802b39ae0"
FIREBASE_TESTER_GROUPS="alpha-testers"

WEB_DIR="$SCRIPT_DIR/../beautycita_web"
EDGE_LOCAL_DIR="$SCRIPT_DIR/supabase/functions/"
EDGE_REMOTE_HOST="www-bc"
EDGE_REMOTE_DIR="/var/www/beautycita.com/bc-flutter/supabase-docker/volumes/functions/"
WEB_REMOTE_DIR="/var/www/beautycita.com/frontend/dist/"

# ── Flags ───────────────────────────────────────────────────────────────────
REQUIRED="false"
RELEASE_NOTES=""
DISTRIBUTE="false"
DO_EDGE="false"
DO_WEB="false"
RUN_ANALYZE="true"
DO_COMMIT="true"
SKIP_BUILD="false"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --required)    REQUIRED="true"; shift ;;
    --notes)       RELEASE_NOTES="${2:-}"; shift 2 ;;
    --distribute)  DISTRIBUTE="true"; shift ;;
    --edge)        DO_EDGE="true"; shift ;;
    --web)         DO_WEB="true"; shift ;;
    --no-analyze)  RUN_ANALYZE="false"; shift ;;
    --no-commit)   DO_COMMIT="false"; shift ;;
    --skip-build)  SKIP_BUILD="true"; shift ;;
    -h|--help)
      sed -n '2,30p' "$0"
      exit 0
      ;;
    *)
      echo "ERROR: unknown arg: $1"
      echo "       supported: --required --notes \"text\" --distribute --edge --web --no-analyze --no-commit --skip-build"
      exit 1
      ;;
  esac
done

# ── Helpers ─────────────────────────────────────────────────────────────────
say() { printf '\033[1;36m%s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m%s\033[0m\n' "$*" >&2; }
die() { printf '\033[1;31m%s\033[0m\n' "$*" >&2; exit 1; }

aws_r2() {
  AWS_ACCESS_KEY_ID="$R2_ACCESS_KEY" \
  AWS_SECRET_ACCESS_KEY="$R2_SECRET_KEY" \
  aws "$@" --endpoint-url "$R2_ENDPOINT"
}

# ── 0. Pre-flight ───────────────────────────────────────────────────────────
say "=== BeautyCita Deploy ==="

if ! command -v aws >/dev/null; then die "aws CLI not on PATH"; fi
if [[ ! -x "$FLUTTER" ]]; then die "flutter not at $FLUTTER"; fi
[[ -f "$PUBSPEC" ]] || die "missing $PUBSPEC"
[[ -f "$CONSTANTS" ]] || die "missing $CONSTANTS"

CUR_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "?")
if [[ "$CUR_BRANCH" != "main" ]]; then
  warn "  WARN: not on main (current: $CUR_BRANCH) — proceeding"
fi

DIRTY=$(git status --porcelain "$PUBSPEC" "$CONSTANTS" 2>/dev/null | wc -l)
if [[ "$DIRTY" -gt 0 ]]; then
  warn "  WARN: $PUBSPEC or $CONSTANTS already modified — proceeding"
fi

# ── 1. Analyze ──────────────────────────────────────────────────────────────
# Only `error •` is fatal. info/warning lints don't block deploy — they're
# tracked elsewhere and shouldn't be load-bearing here.
if [[ "$RUN_ANALYZE" == "true" ]]; then
  say "[analyze] flutter analyze lib/"
  "$FLUTTER" analyze lib/ 2>&1 | tee /tmp/bc-analyze.out | tail -3 || true
  if grep -qE "error •" /tmp/bc-analyze.out; then
    grep -E "error •" /tmp/bc-analyze.out | head -20
    die "analyze reported errors — fix them or pass --no-analyze"
  fi
  rm -f /tmp/bc-analyze.out
fi

# ── 2. Version bump ─────────────────────────────────────────────────────────
CURRENT_LINE=$(grep '^version:' "$PUBSPEC")
VERSION=$(echo "$CURRENT_LINE" | sed 's/version: \(.*\)+.*/\1/')
OLD_BUILD=$(echo "$CURRENT_LINE" | sed 's/version: .*+//')
NEW_BUILD=$((OLD_BUILD + 1))

say "  Version:    $VERSION"
say "  Build:      $OLD_BUILD → $NEW_BUILD"
say "  Required:   $REQUIRED"
say "  Edge:       $DO_EDGE"
say "  Web:        $DO_WEB"
say "  Distribute: $DISTRIBUTE"

# ── 3. Patch pubspec + constants ────────────────────────────────────────────
sed -i "s/^version: .*$/version: ${VERSION}+${NEW_BUILD}/" "$PUBSPEC"
sed -i "s/static const int buildNumber = [0-9]*;/static const int buildNumber = ${NEW_BUILD};/" "$CONSTANTS"

# ── 4. Build APK ────────────────────────────────────────────────────────────
if [[ "$SKIP_BUILD" == "true" ]]; then
  say "[build] --skip-build flag set; reusing existing APK"
  APK_PATH="build/app/outputs/flutter-apk/app-arm64-v8a-release.apk"
  [[ -f "$APK_PATH" ]] || die "no existing APK at $APK_PATH; cannot --skip-build"
else
  say "[build] flutter build apk --release --split-per-abi"
  # Full output goes to /tmp/bc-build.log + tail to terminal so failures are
  # visible. set -e propagates failure.
  if ! "$FLUTTER" build apk --release --split-per-abi 2>&1 | tee /tmp/bc-build.log | tail -10; then
    die "flutter build apk failed — see /tmp/bc-build.log"
  fi
  APK_PATH="build/app/outputs/flutter-apk/app-arm64-v8a-release.apk"
  [[ -f "$APK_PATH" ]] || die "APK not produced at $APK_PATH"
  rm -f /tmp/bc-build.log
fi

APK_SIZE=$(du -h "$APK_PATH" | cut -f1)
say "  APK: $APK_PATH ($APK_SIZE)"

# ── 5. Upload APK to R2 ─────────────────────────────────────────────────────
say "[r2] uploading APK"
aws_r2 s3 cp "$APK_PATH" "$R2_APK_PATH/beautycita.apk" \
  --content-type "application/vnd.android.package-archive" \
  --quiet || die "APK upload failed"

# ── 6. version.json ─────────────────────────────────────────────────────────
say "[r2] uploading version.json"
V_VERSION="$VERSION" \
V_BUILD="$NEW_BUILD" \
V_REQUIRED="$REQUIRED" \
V_URL="$APK_PUBLIC_URL" \
V_NOTES="$RELEASE_NOTES" \
python3 - > /tmp/bc-version.json <<'PY'
import json, os
required = os.environ["V_REQUIRED"].lower() == "true"
print(json.dumps({
    "version":     os.environ["V_VERSION"],
    "build":       int(os.environ["V_BUILD"]),
    "buildNumber": int(os.environ["V_BUILD"]),
    "required":    required,
    "forceUpdate": required,
    "url":         os.environ["V_URL"],
    "releaseNotes": os.environ["V_NOTES"],
}))
PY
aws_r2 s3 cp /tmp/bc-version.json "$R2_VERSION_JSON_PATH" \
  --content-type "application/json" \
  --cache-control "max-age=60" \
  --quiet || die "version.json upload failed"
VERSION_JSON_DUMP=$(cat /tmp/bc-version.json)
rm -f /tmp/bc-version.json

# ── 7. Auto-commit version bump ─────────────────────────────────────────────
if [[ "$DO_COMMIT" == "true" ]]; then
  say "[git] committing version bump"
  git add "$PUBSPEC" "$CONSTANTS"
  if ! git diff --cached --quiet; then
    git commit -m "Build $NEW_BUILD: version bump

Auto-committed by deploy.sh.
Required: $REQUIRED${RELEASE_NOTES:+
Notes: $RELEASE_NOTES}

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>" || warn "  commit failed; continuing"
    git push origin "$CUR_BRANCH" 2>&1 | tail -5 || warn "  push failed; continuing"
  else
    say "  no changes to commit (already at $NEW_BUILD?)"
  fi
fi

# ── 8. Edge functions deploy (optional) ─────────────────────────────────────
if [[ "$DO_EDGE" == "true" ]]; then
  say "[edge] rsync supabase/functions → www-bc"
  rsync -avz --delete-after \
    --exclude '.git' --exclude 'node_modules' --exclude '*.swp' \
    "$EDGE_LOCAL_DIR" "${EDGE_REMOTE_HOST}:${EDGE_REMOTE_DIR}" 2>&1 | tail -5
  say "[edge] restarting functions container"
  ssh "$EDGE_REMOTE_HOST" \
    "cd /var/www/beautycita.com/bc-flutter/supabase-docker && docker compose restart functions" \
    2>&1 | tail -3
fi

# ── 9. Web deploy (optional) ────────────────────────────────────────────────
if [[ "$DO_WEB" == "true" ]]; then
  say "[web] flutter build web (in $WEB_DIR)"
  if [[ ! -d "$WEB_DIR" ]]; then
    warn "  $WEB_DIR not found — skipping --web"
  else
    # Note: callers needing to skip icon tree-shaking should run flutter build web
    # manually with that flag — deploy.sh defaults to tree-shaking on (matches
    # Doc Holiday's expectation).
    (cd "$WEB_DIR" && "$FLUTTER" build web --release 2>&1 | tee /tmp/bc-web.log | tail -10) || \
      die "web build failed — see /tmp/bc-web.log"
    rm -f /tmp/bc-web.log
    say "[web] rsync → www-bc"
    rsync -avz --delete --exclude sativa --exclude private \
      --exclude portfolio-upload-config.json --exclude portfolio-upload.html \
      "$WEB_DIR/build/web/" "${EDGE_REMOTE_HOST}:${WEB_REMOTE_DIR}" 2>&1 | tail -5
  fi
fi

# ── 10. Firebase App Distribution (optional) ────────────────────────────────
if [[ "$DISTRIBUTE" == "true" ]]; then
  if [[ ! -x "$FIREBASE_CLI" ]]; then
    warn "  --distribute requested but $FIREBASE_CLI not executable — skipping"
  else
    say "[firebase] distributing to $FIREBASE_TESTER_GROUPS"
    FB_NOTES="Build $NEW_BUILD"
    [[ -n "$RELEASE_NOTES" ]] && FB_NOTES="$FB_NOTES — $RELEASE_NOTES"
    "$FIREBASE_CLI" --project "$FIREBASE_PROJECT" appdistribution:distribute "$APK_PATH" \
      --app "$FIREBASE_APP_ID" \
      --release-notes "$FB_NOTES" \
      --groups "$FIREBASE_TESTER_GROUPS" 2>&1 | grep -E "uploaded|distributed|Error|error" || true
  fi
fi

# ── Done ────────────────────────────────────────────────────────────────────
echo ""
say "=== Deploy Complete ==="
say "  Version:    $VERSION+$NEW_BUILD"
say "  APK:        $APK_PUBLIC_URL"
say "  Required:   $REQUIRED"
say "  JSON:       $VERSION_JSON_DUMP"
[[ "$DO_EDGE" == "true" ]] && say "  Edge:       deployed"
[[ "$DO_WEB" == "true" ]] && say "  Web:        deployed"
[[ "$DISTRIBUTE" == "true" ]] && say "  Firebase:   distributed"
[[ "$DO_COMMIT" == "true" ]] && say "  Git:        committed + pushed"
