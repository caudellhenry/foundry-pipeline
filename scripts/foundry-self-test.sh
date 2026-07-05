#!/usr/bin/env bash
# scripts/foundry-self-test.sh
#
# Verifies the foundry-pipeline monorepo's own shell scripts pass bash -n
# syntax check. Used by the foundry-evals.yml CI workflow.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

declare -i FAIL=0
declare -i OK=0

# 1. Bash syntax check every shell script in the repo
echo "[1/3] bash -n on every .sh under repo"
while IFS= read -r -d '' sh; do
  if bash -n "$sh" 2>/dev/null; then
    OK+=1
  else
    echo "  FAIL  ${sh#$REPO_ROOT/}"
    bash -n "$sh"
    FAIL+=1
  fi
done < <(find . -name '*.sh' \
            -not -path './.git/*' \
            -not -path './node_modules/*' \
            -print0)
echo "  $OK ok, $FAIL failed"
echo ""

# 2. JSON syntax check every .json under the repo
echo "[2/3] jq empty on every .json under repo"
if command -v jq >/dev/null 2>&1; then
  while IFS= read -r -d '' json; do
    if jq empty "$json" >/dev/null 2>&1; then
      OK+=1
    else
      echo "  FAIL  ${json#$REPO_ROOT/}"
      jq empty "$json"
      FAIL+=1
    fi
  done < <(find . -name '*.json' \
              -not -path './.git/*' \
              -not -path './node_modules/*' \
              -not -path '*/.foundry-version-manifest.json' \
              -print0)
  echo "  $OK ok, $FAIL failed"
else
  echo "  SKIP (jq not installed)"
fi
echo ""

# 3. VERSION file sanity
echo "[3/3] VERSION file sanity"
if [[ -f VERSION ]]; then
  ver="$(tr -d '[:space:]' < VERSION)"
  if [[ "$ver" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[A-Za-z0-9.-]+)?$ ]]; then
    echo "  OK  VERSION=$ver"
    OK+=1
  else
    echo "  FAIL  VERSION='$ver' does not match MAJOR.MINOR.PATCH[-prerelease]"
    FAIL+=1
  fi
else
  echo "  FAIL  VERSION file missing"
  FAIL+=1
fi
echo ""

if [[ "$FAIL" -gt 0 ]]; then
  echo "Self-test FAILED: $FAIL failures."
  exit 1
fi

echo "Self-test PASSED ($OK checks)."
exit 0