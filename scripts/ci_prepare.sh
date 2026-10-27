#!/usr/bin/env bash
# Ensures build assets exist (taxonomy). Safe to run in CI and locally.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$ROOT/taxonomy/styl_service_taxonomy.json"

if [[ -f "$DEST" ]]; then
  exit 0
fi

MONOREPO_SRC="$ROOT/../taxonomy/styl_service_taxonomy.json"
if [[ -f "$MONOREPO_SRC" ]]; then
  mkdir -p "$(dirname "$DEST")"
  cp "$MONOREPO_SRC" "$DEST"
  echo "Copied taxonomy from $MONOREPO_SRC"
  exit 0
fi

echo "Missing $DEST (commit taxonomy/ or keep monorepo ../taxonomy/)" >&2
exit 1
