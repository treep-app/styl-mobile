#!/usr/bin/env bash
# Run the same checks as GitHub Actions before you push.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "==> CI prepare"
chmod +x scripts/ci_prepare.sh
./scripts/ci_prepare.sh

echo "==> flutter pub get"
flutter pub get

echo "==> flutter analyze (same flags as GitHub Actions)"
flutter analyze --no-fatal-infos

echo "==> flutter test"
flutter test

echo ""
echo "Tip: run ./scripts/ci_local.sh before every push (same as GitHub Actions)."
echo "OK — safe to push (Mobile CI checks passed)."
