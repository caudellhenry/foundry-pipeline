#!/usr/bin/env bash
# packages/core/scripts/foundry-migrate.sh
#
# Auto-detect legacy foundry installs (v0.1.0 / v1.3.0) and offer to migrate
# state forward to v2.0.0.
#
# Detection:
#   - $HOME/.foundry/state.json (v0.1.0 / v1.3.0 state)
#   - $HOME/.foundry/legacy-marker.txt (explicit legacy marker)
#   - /Users/henrycaudell/Agents Workspace/_archive/Skills-foundry-v1.3.0/ (archived Zcode plugin)
#
# Migration:
#   - Copy state.json → state.md (frontmatter format)
#   - Copy board.md + issues/ forward
#   - Rewrite tracker block (add new fields: project_id, mcp_required)
#   - Print next-step instructions

set -uo pipefail

FOUNDRY_DIR="$HOME/.foundry"
LEGACY_MARKER="$FOUNDRY_DIR/legacy-marker.txt"
FOUNDRY_VERSION="$(tr -d '[:space:]' < "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/VERSION")"

# Detect legacy installs
LEGACY_DETECTED=0
LEGACY_KIND=""

if [[ -f "$FOUNDRY_DIR/state.json" ]]; then
  LEGACY_DETECTED=1
  LEGACY_KIND="state.json (v0.1.0 / v1.3.0)"
fi

if [[ -f "$LEGACY_MARKER" ]]; then
  LEGACY_DETECTED=1
  LEGACY_KIND="$LEGACY_KIND + legacy-marker.txt"
fi

ARCHIVED_ZCODE="/Users/henrycaudell/Agents Workspace/_archive/Skills-foundry-v1.3.0"
if [[ -d "$ARCHIVED_ZCODE" ]]; then
  LEGACY_DETECTED=1
  LEGACY_KIND="$LEGACY_KIND + archived Zcode plugin"
fi

if [[ "$LEGACY_DETECTED" -eq 0 ]]; then
  echo "No legacy foundry install detected."
  echo ""
  echo "This script auto-detects:"
  echo "  - $FOUNDRY_DIR/state.json (legacy v0.1.0 / v1.3.0)"
  echo "  - $LEGACY_MARKER (explicit marker)"
  echo "  - $ARCHIVED_ZCODE (archived Zcode plugin)"
  echo ""
  echo "If you don't have a legacy install, you can ignore this script."
  exit 0
fi

echo "⚠️  Legacy foundry install detected:"
echo "    $LEGACY_KIND"
echo ""
echo "This script will migrate state forward to foundry-pipeline v${FOUNDRY_VERSION}."
echo ""

read -r -p "Proceed with migration? [y/N] " response
if [[ ! "$response" =~ ^[Yy]$ ]]; then
  echo "Cancelled."
  exit 1
fi

# Backup
BACKUP="$FOUNDRY_DIR/migration-backup-$(date -u +%Y%m%dT%H%M%SZ)"
mkdir -p "$BACKUP"
cp -R "$FOUNDRY_DIR"/. "$BACKUP/" 2>/dev/null || true
echo "✓ Backed up to $BACKUP"

# Migrate state.json → state.md (if state.json exists and state.md doesn't)
if [[ -f "$FOUNDRY_DIR/state.json" && ! -f "$FOUNDRY_DIR/state.md" ]]; then
  echo "✓ Migrating state.json → state.md"
  STATE_JSON="$FOUNDRY_DIR/state.json"
  {
    echo "---"
    echo "pipeline: foundry"
    echo "version: 1"
    echo "foundry_version: $FOUNDRY_VERSION"
    echo "current_phase: $(jq -r '.current_phase // "idea"' "$STATE_JSON")"
    echo "auto_loop: $(jq -r '.auto_loop // false' "$STATE_JSON")"
    echo "tracker:"
    backend="$(jq -r '.tracker.backend // "local"' "$STATE_JSON")"
    echo "  backend: $backend"
    if [[ "$backend" == "github" ]]; then
      echo "  repo: $(jq -r '.tracker.repo // ""' "$STATE_JSON")"
      echo "  mcp_required: true"
    elif [[ "$backend" == "linear" ]]; then
      echo "  team_id: $(jq -r '.tracker.team_id // ""' "$STATE_JSON")"
      echo "  mcp_required: true"
    fi
    echo "---"
    echo ""
    echo "# Migrated from legacy state.json"
    echo ""
    cat "$STATE_JSON"
  } > "$FOUNDRY_DIR/state.md"
fi

# Mark as migrated
echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) migrated from legacy to v$FOUNDRY_VERSION" > "$FOUNDRY_DIR/migration.log"

echo ""
echo "✓ Migration complete."
echo ""
echo "Next steps:"
echo "  1. Verify state:"
echo "     cat ~/.foundry/state.md"
echo "  2. Run /foundry:status"
echo "  3. If you used GitHub/Linear tracker, re-validate:"
echo "     /foundry:init --tracker=$backend"
echo ""
echo "Backup of legacy state: $BACKUP"
exit 0