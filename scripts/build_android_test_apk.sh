#!/usr/bin/env bash
# Small sideload APK for team testing (arm64 phones only — not a fat debug APK).
#
# Profile (default): ~40MB, production API (https://api.stylaus.com/api/v1).
# Debug split: smaller than app-debug.apk but still debuggable; pass API via build_android_debug.sh.
#
# Usage: ./scripts/build_android_test_apk.sh [profile|debug]
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

MODE="${1:-profile}"

case "$MODE" in
  profile)
    flutter pub get
    flutter build apk --profile --split-per-abi --target-platform android-arm64
    APK="build/app/outputs/flutter-apk/app-arm64-v8a-profile.apk"
    ;;
  debug)
    flutter pub get
    flutter build apk --debug --split-per-abi --target-platform android-arm64
    APK="build/app/outputs/flutter-apk/app-arm64-v8a-debug.apk"
    ;;
  *)
    echo "Usage: $0 [profile|debug]" >&2
    exit 1
    ;;
esac

VERSION="$(grep '^version:' pubspec.yaml | sed 's/version: *//; s/+.*//')"
DIST="$ROOT/dist"
mkdir -p "$DIST"
SHARE_NAME="styl-android-test-${VERSION}-arm64-${MODE}.apk"
cp "$APK" "$DIST/$SHARE_NAME"

echo
echo "==> Team test APK (arm64-v8a, ${MODE})"
if [[ "$MODE" == profile ]]; then
  echo "    API: https://api.stylaus.com/api/v1"
else
  echo "    API: debug defaults (use ./scripts/build_android_debug.sh for prod/local API fat APK)"
fi
ls -lh "$APK" "$DIST/$SHARE_NAME"
echo
echo "Share: $DIST/$SHARE_NAME"
echo "Install: adb install -r \"$DIST/$SHARE_NAME\""
echo
echo "Most modern Android phones are arm64. x86 emulators need: flutter build apk --debug (fat) or x86_64 ABI."
