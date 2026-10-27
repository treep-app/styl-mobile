#!/usr/bin/env bash
# Release build for a physical iPhone using Team.local.xcconfig (personal team).
# TestFlight / App Store: use ./scripts/build_ios_testflight.sh (S48V9LQKCT).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

LOCAL="$ROOT/ios/Flutter/Team.local.xcconfig"
EXAMPLE="$ROOT/ios/Flutter/Team.local.xcconfig.example"

if [[ ! -f "$LOCAL" ]]; then
  echo "Create $LOCAL first (see $EXAMPLE)." >&2
  exit 1
fi

flutter pub get
(cd ios && pod install)
flutter build ios --release
