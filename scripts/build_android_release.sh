#!/usr/bin/env bash
# Production Android App Bundle for Google Play (com.stylaus.app).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

API_BASE_URL="https://api.stylaus.com/api/v1"

"$ROOT/scripts/ci_prepare.sh"

if [[ ! -f "$ROOT/android/key.properties" ]]; then
  echo "Missing android/key.properties — copy android/key.properties.example and add upload-keystore.jks" >&2
  exit 1
fi

flutter pub get
flutter build appbundle --release \
  --dart-define="API_BASE_URL=${API_BASE_URL}" \
  --dart-define=USE_PROD_API=true

echo ""
echo "==> AAB: build/app/outputs/bundle/release/app-release.aab"
ls -lh build/app/outputs/bundle/release/app-release.aab
