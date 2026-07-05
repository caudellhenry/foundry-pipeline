#!/usr/bin/env bash
# scripts/foundry-version-sync.sh
#
# Reads the root VERSION file and writes that version into every
# `packages/*/package.json` and `packages/*/.claude-plugin/plugin.json`.
#
# Also stamps `foundry_version:` into every SKILL.md so any agent can grep it.
#
# Idempotent: safe to run multiple times.
# Exit 0 on success, 1 on missing jq / malformed files.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION_FILE="$REPO_ROOT/VERSION"

if [[ ! -f "$VERSION_FILE" ]]; then
  echo "ERROR: VERSION file not found at $VERSION_FILE" >&2
  exit 1
fi

ROOT_VERSION="$(tr -d '[:space:]' < "$VERSION_FILE")"

# Validate MAJOR.MINOR.PATCH or MAJOR.MINOR.PATCH-prerelease
if ! [[ "$ROOT_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[A-Za-z0-9.-]+)?$ ]]; then
  echo "ERROR: VERSION ('$ROOT_VERSION') does not match MAJOR.MINOR.PATCH[-prerelease]" >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq is required for version sync. Install with: brew install jq" >&2
  exit 1
fi

echo "Syncing version $ROOT_VERSION → all packages"

declare -i UPDATED=0
declare -i SKIPPED=0

for pkg_dir in "$REPO_ROOT"/packages/*/; do
  pkg_name="$(basename "$pkg_dir")"
  [[ "$pkg_name" == "core" || -d "$pkg_dir/.claude-plugin" ]] || { SKIPPED+=1; continue; }

  # 1. Update package.json
  pkg_json="$pkg_dir/package.json"
  if [[ -f "$pkg_json" ]]; then
    current="$(jq -r '.version // ""' "$pkg_json")"
    if [[ "$current" != "$ROOT_VERSION" ]]; then
      jq --arg v "$ROOT_VERSION" '.version = $v' "$pkg_json" > "$pkg_json.tmp"
      mv "$pkg_json.tmp" "$pkg_json"
      echo "  $pkg_name/package.json: $current → $ROOT_VERSION"
      UPDATED+=1
    fi
  fi

  # 2. Update .claude-plugin/plugin.json
  for plugin_json in "$pkg_dir"/.claude-plugin/plugin.json "$pkg_dir"/.claude-plugin/marketplace.json; do
    if [[ -f "$plugin_json" ]]; then
      current="$(jq -r '.version // ""' "$plugin_json")"
      if [[ "$current" != "$ROOT_VERSION" ]]; then
        jq --arg v "$ROOT_VERSION" '.version = $v' "$plugin_json" > "$plugin_json.tmp"
        mv "$plugin_json.tmp" "$plugin_json"
        echo "  ${pkg_name}/${plugin_json#$pkg_dir/}: $current → $ROOT_VERSION"
        UPDATED+=1
      fi
    fi
  done

  # 3. Stamp foundry_version into every SKILL.md under this package
  while IFS= read -r -d '' skill_md; do
    if grep -q "^foundry_version:" "$skill_md" 2>/dev/null; then
      # Replace existing
      sed -i.bak "s/^foundry_version:.*/foundry_version: $ROOT_VERSION/" "$skill_md"
      rm -f "$skill_md.bak"
    else
      # Insert after the first `---` close line (after frontmatter)
      awk -v v="$ROOT_VERSION" '
        BEGIN { in_fm=0; fm_done=0; printed=0 }
        /^---$/ {
          if (in_fm && !fm_done) { fm_done=1; print; print "foundry_version: " v; printed=1; next }
          in_fm=1; print; next
        }
        { print }
      ' "$skill_md" > "$skill_md.tmp"
      mv "$skill_md.tmp" "$skill_md"
    fi
  done < <(find "$pkg_dir" -name SKILL.md -print0 2>/dev/null)
done

echo "Done. Updated: $UPDATED, Skipped: $SKIPPED"
exit 0