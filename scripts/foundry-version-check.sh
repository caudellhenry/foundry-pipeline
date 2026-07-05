#!/usr/bin/env bash
# scripts/foundry-version-check.sh
#
# CI guard: fails if any package.json or .claude-plugin/*.json version disagrees
# with the root VERSION file, or if any SKILL.md is missing foundry_version:.
#
# Exit 0 if everything is in sync, 1 otherwise.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION_FILE="$REPO_ROOT/VERSION"

if [[ ! -f "$VERSION_FILE" ]]; then
  echo "FAIL: VERSION file not found at $VERSION_FILE" >&2
  exit 1
fi

ROOT_VERSION="$(tr -d '[:space:]' < "$VERSION_FILE")"

if ! command -v jq >/dev/null 2>&1; then
  echo "FAIL: jq is required for version check." >&2
  exit 1
fi

declare -i DRIFT=0

echo "Checking all packages against VERSION=$ROOT_VERSION"

for pkg_dir in "$REPO_ROOT"/packages/*/; do
  pkg_name="$(basename "$pkg_dir")"

  for json_file in "$pkg_dir/package.json" \
                   "$pkg_dir/.claude-plugin/plugin.json" \
                   "$pkg_dir/.claude-plugin/marketplace.json"; do
    [[ -f "$json_file" ]] || continue
    current="$(jq -r '.version // ""' "$json_file")"
    if [[ -z "$current" ]]; then
      echo "  FAIL  ${json_file#$REPO_ROOT/}  (missing .version field)"
      DRIFT+=1
      continue
    fi
    if [[ "$current" != "$ROOT_VERSION" ]]; then
      echo "  FAIL  ${json_file#$REPO_ROOT/}  ($current ≠ $ROOT_VERSION)"
      DRIFT+=1
    else
      echo "  OK    ${json_file#$REPO_ROOT/}  ($current)"
    fi
  done

  while IFS= read -r -d '' skill_md; do
    if ! grep -q "^foundry_version: $ROOT_VERSION" "$skill_md" 2>/dev/null; then
      rel="${skill_md#$REPO_ROOT/}"
      current="$(grep -E '^foundry_version:' "$skill_md" 2>/dev/null | head -1 || echo '(missing)')"
      echo "  FAIL  $rel  ($current)"
      DRIFT+=1
    fi
  done < <(find "$pkg_dir" -name SKILL.md -print0 2>/dev/null)
done

if [[ "$DRIFT" -gt 0 ]]; then
  echo ""
  echo "FOUND $DRIFT version drift(s). Run: bash scripts/foundry-version-sync.sh"
  exit 1
fi

echo ""
echo "All packages in sync with VERSION=$ROOT_VERSION"
exit 0