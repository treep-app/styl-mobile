#!/usr/bin/env bash
# Build a release IPA for TestFlight / App Store (STYL org team S48V9LQKCT).
# Always pins the production API (https://api.stylaus.com/api/v1).
#
# Prerequisites (one-time on this Mac):
#   1. Xcode → Settings → Accounts → sign in with the Apple ID for team S48V9LQKCT
#   2. Open ios/Runner.xcworkspace → Runner → Signing → Team STYL → Automatic signing ON
#   3. Let Xcode download/create iOS "Apple Distribution" (not Mac Developer ID) certs
#
# Usage:
#   ./scripts/build_ios_testflight.sh
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

STYL_TEAM="S48V9LQKCT"
API_BASE_URL="https://api.stylaus.com/api/v1"
LOCAL_TEAM="$ROOT/ios/Flutter/Team.local.xcconfig"
LOCAL_BACKUP=""
RESTORE_LOCAL=0

cleanup() {
  if [[ "$RESTORE_LOCAL" == 1 && -f "${LOCAL_TEAM}.testflight-backup" ]]; then
    mv "${LOCAL_TEAM}.testflight-backup" "$LOCAL_TEAM"
    echo "Restored Team.local.xcconfig"
  fi
}
trap cleanup EXIT

echo "==> STYL iOS TestFlight / App Store IPA"
echo "    API_BASE_URL=$API_BASE_URL"
echo "    bundle id=com.stylaus.app"
echo "    signing team=$STYL_TEAM"

if [[ -f "$LOCAL_TEAM" ]]; then
  echo ""
  echo "==> Disabling Team.local.xcconfig for this build (TestFlight must use $STYL_TEAM)."
  mv "$LOCAL_TEAM" "${LOCAL_TEAM}.testflight-backup"
  RESTORE_LOCAL=1
fi

flutter pub get
(
  cd ios
  pod install
)

TEAM="$(
  xcodebuild -showBuildSettings \
    -project ios/Runner.xcodeproj \
    -scheme Runner \
    -configuration Release 2>/dev/null \
    | awk -F' = ' '/DEVELOPMENT_TEAM/ {print $2; exit}'
)"
if [[ "$TEAM" != "$STYL_TEAM" ]]; then
  echo ""
  echo "ERROR: DEVELOPMENT_TEAM is '$TEAM', expected '$STYL_TEAM'." >&2
  echo "Check ios/Flutter/Team.xcconfig and remove any local override." >&2
  exit 1
fi

if ! security find-identity -v -p codesigning 2>/dev/null | grep -q "($STYL_TEAM)"; then
  echo ""
  echo "WARNING: No code-signing identity for team $STYL_TEAM in this keychain." >&2
  echo "         Sign in to Xcode with the STYL Apple ID and open Runner signing once." >&2
  echo "         iOS TestFlight needs Apple Distribution / Apple Development for iOS —" >&2
  echo "         Mac 'Developer ID Application' certs are not used for TestFlight." >&2
  echo ""
fi

flutter build ipa --release \
  --export-options-plist=ios/ExportOptions.plist \
  --dart-define="API_BASE_URL=${API_BASE_URL}" \
  --dart-define=USE_PROD_API=true

echo ""
echo "==> IPA ready under build/ios/ipa/"
ls -lh build/ios/ipa/*.ipa 2>/dev/null || true
echo ""
echo "Upload with Transporter or Xcode Organizer → TestFlight."
echo "Testers will hit production: https://api.stylaus.com/api/v1"
