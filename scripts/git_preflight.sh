#!/usr/bin/env bash
# Run before first push: ensures secrets and build artifacts are not tracked.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if ! git rev-parse --is-inside-work-tree &>/dev/null; then
  echo "Not a git repository. From mobile/: git init && git add ." >&2
  exit 1
fi

fail=0

warn_tracked() {
  local path="$1"
  if git ls-files --error-unmatch "$path" &>/dev/null; then
    echo "ERROR: tracked secret or build artifact: $path" >&2
    fail=1
  fi
}

for path in \
  android/key.properties \
  android/app/upload-keystore.jks \
  android/upload-keystore.jks \
  ios/Flutter/Team.local.xcconfig; do
  warn_tracked "$path"
done

if git ls-files | grep -qE '(^|/)(\.env|\.env\.local)$'; then
  echo "ERROR: .env file is tracked — use GitHub Secrets instead" >&2
  fail=1
fi

if git ls-files | grep -qE '\.(jks|keystore|p12|mobileprovision)$'; then
  echo "ERROR: signing material is tracked" >&2
  fail=1
fi

if git ls-files | grep -qiE 'service.account|iam\.gserviceaccount'; then
  echo "ERROR: possible GCP service account JSON is tracked" >&2
  fail=1
fi

if git ls-files build/ 2>/dev/null | grep -q .; then
  echo "ERROR: build/ is tracked" >&2
  fail=1
fi

if git ls-files ios/Pods/ 2>/dev/null | grep -q .; then
  echo "ERROR: ios/Pods/ is tracked" >&2
  fail=1
fi

STAGED="$(git diff --cached --name-only 2>/dev/null || true)"
if [[ -n "$STAGED" ]]; then
  if echo "$STAGED" | grep -vE '\.example$' | grep -qE '(^|/)key\.properties$|\.jks$|\.keystore$|\.p12$|(^|/)\.env($|\.)'; then
    echo "ERROR: staged files include secrets" >&2
    fail=1
  fi
fi

if [[ "$fail" -ne 0 ]]; then
  echo "" >&2
  echo "Fix: git rm --cached <path>  then commit. Keep secrets in GitHub Actions secrets only." >&2
  exit 1
fi

echo "OK: no secrets or build junk tracked ($(git ls-files | wc -l | tr -d ' ') files would be in repo)."
echo "Next: git add . && git status   then commit and push."
