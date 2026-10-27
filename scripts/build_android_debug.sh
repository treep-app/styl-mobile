#!/usr/bin/env bash
# Build a debuggable STYL APK for Android testing.
#
# Usage:
#   ./scripts/build_android_debug.sh
#       → Production API (https://api.stylaus.com/api/v1)
#
#   ./scripts/build_android_debug.sh local
#       → Local backend via Android emulator (10.0.2.2:3000)
#
#   ./scripts/build_android_debug.sh device
#       → Local backend via this machine's LAN IP (physical phone)
#
#   ./scripts/build_android_debug.sh http://192.168.1.20:3000/api/v1
#       → Explicit API base URL
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

mode_or_url="${1:-production}"

detect_lan_ip() {
  if command -v ipconfig >/dev/null 2>&1; then
    # macOS
    ipconfig getifaddr en0 2>/dev/null \
      || ipconfig getifaddr en1 2>/dev/null \
      || true
  elif command -v hostname >/dev/null 2>&1; then
    hostname -I 2>/dev/null | awk '{print $1}'
  fi
}

EXTRA_DEFINES=()

case "$mode_or_url" in
  production|prod|"")
    API_BASE_URL="https://api.stylaus.com/api/v1"
    ;;
  local|emulator)
    API_BASE_URL="http://10.0.2.2:3000/api/v1"
    EXTRA_DEFINES+=(--dart-define=USE_LOCAL_API=true)
    ;;
  device)
    LAN_IP="$(detect_lan_ip)"
    if [[ -z "${LAN_IP}" ]]; then
      echo "Could not detect LAN IP. Pass the API URL explicitly:" >&2
      echo "  $0 http://YOUR_IP:3000/api/v1" >&2
      exit 1
    fi
    API_BASE_URL="http://${LAN_IP}:3000/api/v1"
    EXTRA_DEFINES+=(--dart-define=USE_LOCAL_API=true)
    ;;
  http://*|https://*)
    API_BASE_URL="$mode_or_url"
    ;;
  *)
    echo "Unknown argument: $mode_or_url" >&2
    echo "Use: production | local | device | <API_BASE_URL>" >&2
    exit 1
    ;;
esac

echo "==> STYL Android debug APK"
echo "    API_BASE_URL=$API_BASE_URL"
echo "    applicationId=com.stylaus.app.debug"

flutter pub get
flutter build apk --debug \
  --dart-define="API_BASE_URL=${API_BASE_URL}" \
  "${EXTRA_DEFINES[@]+"${EXTRA_DEFINES[@]}"}"

OUT="$ROOT/build/app/outputs/flutter-apk/app-debug.apk"
echo ""
echo "==> APK ready"
echo "    $OUT"
ls -lh "$OUT"
echo ""
echo "Install on a device/emulator:"
echo "  adb install -r \"$OUT\""
echo ""
echo "Notes:"
echo "  • App label: STYL Debug"
echo "  • Default target is production: https://api.stylaus.com/api/v1"
echo "  • For a local API: ./scripts/build_android_debug.sh local"
