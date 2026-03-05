#!/bin/bash
# deploy.sh — Build, upload APK + version.json to R2 with auto-bumped build number.
# Usage: ./deploy.sh [--required]
#   --required  marks the update as mandatory (users can't dismiss)
#
# What it does:
#   1. Reads current build number from pubspec.yaml
#   2. Increments it by 1
#   3. Updates pubspec.yaml AND lib/config/constants.dart
#   4. Builds release APK (arm64)
#   5. Uploads APK to R2
#   6. Uploads version.json to R2
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

FLUTTER="/home/bc/flutter/bin/flutter"
PUBSPEC="pubspec.yaml"
CONSTANTS="lib/config/constants.dart"

R2_BUCKET="s3://beautycita-medias/apk"
R2_ENDPOINT="https://e61486f47c2fe5a12fdce43b7a318343.r2.cloudflarestorage.com"
R2_ACCESS_KEY="ca3c10c25e5a6389797d8b47368626d4"
R2_SECRET_KEY="9a761a36330e00d98e1faa6c588c47a76fb8f15b573c6dcf197efe10d80bba4d"
APK_PUBLIC_URL="https://pub-56305a12c77043c9bd5de9db79a5e542.r2.dev/apk/beautycita.apk"

REQUIRED="false"
if [[ "${1:-}" == "--required" ]]; then
  REQUIRED="true"
fi

# ── 1. Read current version + build from pubspec.yaml ──
CURRENT_LINE=$(grep '^version:' "$PUBSPEC")
VERSION=$(echo "$CURRENT_LINE" | sed 's/version: \(.*\)+.*/\1/')
OLD_BUILD=$(echo "$CURRENT_LINE" | sed 's/version: .*+//')
NEW_BUILD=$((OLD_BUILD + 1))

echo "=== BeautyCita Deploy ==="
echo "  Version:   $VERSION"
echo "  Build:     $OLD_BUILD → $NEW_BUILD"
echo "  Required:  $REQUIRED"
echo ""

# ── 2. Update pubspec.yaml ──
sed -i "s/^version: .*$/version: ${VERSION}+${NEW_BUILD}/" "$PUBSPEC"
echo "[1/5] pubspec.yaml updated"

# ── 3. Update constants.dart ──
sed -i "s/static const int buildNumber = [0-9]*;/static const int buildNumber = ${NEW_BUILD};/" "$CONSTANTS"
echo "[2/5] constants.dart updated"

# ── 4. Build APK (split-per-abi for smaller download) ──
echo "[3/5] Building APK..."
$FLUTTER build apk --release --no-tree-shake-icons --split-per-abi 2>&1 | tail -3
APK_PATH="build/app/outputs/flutter-apk/app-arm64-v8a-release.apk"

if [[ ! -f "$APK_PATH" ]]; then
  echo "ERROR: APK not found at $APK_PATH"
  exit 1
fi

APK_SIZE=$(du -h "$APK_PATH" | cut -f1)
echo "  APK: $APK_PATH ($APK_SIZE)"

# ── 5. Upload APK to R2 ──
echo "[4/5] Uploading APK..."
AWS_ACCESS_KEY_ID="$R2_ACCESS_KEY" \
AWS_SECRET_ACCESS_KEY="$R2_SECRET_KEY" \
aws s3 cp "$APK_PATH" "$R2_BUCKET/beautycita.apk" \
  --endpoint-url "$R2_ENDPOINT" \
  --content-type "application/vnd.android.package-archive" \
  --quiet

echo "  Uploaded to $APK_PUBLIC_URL"

# ── 6. Upload version.json to R2 ──
echo "[5/5] Uploading version.json..."
VERSION_JSON="{\"version\":\"${VERSION}\",\"build\":${NEW_BUILD},\"url\":\"${APK_PUBLIC_URL}\",\"required\":${REQUIRED}}"
echo "$VERSION_JSON" > /tmp/beautycita-version.json

AWS_ACCESS_KEY_ID="$R2_ACCESS_KEY" \
AWS_SECRET_ACCESS_KEY="$R2_SECRET_KEY" \
aws s3 cp /tmp/beautycita-version.json "$R2_BUCKET/version.json" \
  --endpoint-url "$R2_ENDPOINT" \
  --content-type "application/json" \
  --cache-control "max-age=60" \
  --quiet

rm -f /tmp/beautycita-version.json

echo ""
echo "=== Deploy Complete ==="
echo "  Version:  $VERSION+$NEW_BUILD"
echo "  Required: $REQUIRED"
echo "  APK:      $APK_PUBLIC_URL"
echo "  JSON:     $VERSION_JSON"
