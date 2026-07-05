#!/usr/bin/env bash
# packages/core/scripts/foundry-upgrade.sh
#
# Upgrade foundry-pipeline: pull latest, switch to target tag, remove any
# orphan symlinks left by prior install bugs (e.g. v2.0.1 wrote to
# ~/.zcode/cli/plugins/cache/<ver> instead of
# ~/.zcode/cli/plugins/cache/foundry-pipeline/<ver>), then re-run the
# workspace installer.
#
# Idempotent — safe to run multiple times.
#
# Flags:
#   --source=<dir>     Canonical clone (default: $WORKSPACE/Skills/foundry-pipeline)
#   --workspace=<dir>  Workspace root (default: $HOME/Agents Workspace)
#   --to=<version>     Target tag (default: latest)
#   --no-fetch         Skip `git fetch --tags`
#   --no-reinstall     Skip the reinstall step (just fix orphans)
#   --no-verify        Skip the post-install verify step
#   --dry-run          Print what would happen; do not touch disk
#   -h, --help         Show this help

set -uo pipefail

CANONICAL_REPO="caudellhenry/foundry-pipeline"
PLUGIN_NAME="foundry-pipeline"

WORKSPACE_DIR="${WORKSPACE_DIR:-$HOME/Agents Workspace}"
SOURCE_DIR=""
TARGET_VERSION=""
DO_FETCH=1
DO_REINSTALL=1
DO_VERIFY=1
DRY_RUN=0

# Harness registry — paths the v2.0.1 bug wrote to (missing foundry-pipeline/
# segment for plugin-style harnesses). These get scanned + cleaned up.
ORPHAN_HOME_PATHS=(
  "$HOME/.claude/plugins/cache"
  "$HOME/.zcode/cli/plugins/cache"
  "$HOME/.antigravity/plugins"
  "$HOME/.mimocode/plugins"
)
ORPHAN_WS_PATHS=(
  "$WORKSPACE_DIR/.claude/plugins/cache"
  "$WORKSPACE_DIR/.zcode/cli/plugins/cache"
  "$WORKSPACE_DIR/.antigravity/plugins"
  "$WORKSPACE_DIR/.mimocode/plugins"
)

while [[ $# -gt 0 ]]; do
  case "$1" in
    --source=*)        SOURCE_DIR="${1#--source=}"; shift ;;
    --workspace=*)     WORKSPACE_DIR="${1#--workspace=}"; shift ;;
    --to=*)            TARGET_VERSION="${1#--to=}"; shift ;;
    --no-fetch)        DO_FETCH=0; shift ;;
    --no-reinstall)    DO_REINSTALL=0; shift ;;
    --no-verify)       DO_VERIFY=0; shift ;;
    --dry-run)         DRY_RUN=1; shift ;;
    -h|--help)
      cat <<'HELP'
foundry-upgrade.sh — upgrade foundry-pipeline to a newer tag

Usage:
  foundry-upgrade.sh [flags]

Steps performed:
  [1/5] git fetch --tags                  (unless --no-fetch)
  [2/5] git checkout <target>             (target = latest tag or --to)
  [3/5] removing orphan symlinks          (v2.0.1 install-bug paths)
  [4/5] foundry-install-workspace.sh      (unless --no-reinstall)
  [5/5] verify symlinks resolve           (unless --no-verify)

Flags:
  --source=<dir>     Canonical clone (default: $WORKSPACE/Skills/foundry-pipeline)
  --workspace=<dir>  Workspace root (default: $HOME/Agents Workspace)
  --to=vX.Y.Z        Target tag (default: latest v*)
  --no-fetch         Skip git fetch
  --no-reinstall     Skip the reinstall step
  --no-verify        Skip the post-install verify step
  --dry-run          Print what would happen; do not touch disk

Idempotent — safe to run multiple times.
HELP
      exit 0
      ;;
    *) echo "Unknown flag: $1" >&2; exit 2 ;;
  esac
done

# Auto-detect clone
SOURCE_DIR="${SOURCE_DIR:-$WORKSPACE_DIR/Skills/foundry-pipeline}"

if [[ ! -d "$SOURCE_DIR/.git" ]]; then
  echo "ERROR: $SOURCE_DIR does not look like a foundry-pipeline clone (no .git/)" >&2
  echo "Hint:" >&2
  echo "  git clone https://github.com/$CANONICAL_REPO.git \"$SOURCE_DIR\"" >&2
  exit 1
fi

echo "foundry-pipeline upgrade"
echo "  clone:     $SOURCE_DIR"
echo "  workspace: $WORKSPACE_DIR"
echo "  dry-run:   $DRY_RUN"
echo ""

# 1. Fetch latest tags
if [[ "$DO_FETCH" == "1" ]]; then
  echo "[1/5] git fetch --tags"
  if [[ "$DRY_RUN" != "1" ]]; then
    (cd "$SOURCE_DIR" && git fetch --tags 2>&1 | tail -5) || {
      echo "  WARN: git fetch failed (continuing)" >&2
    }
  fi
fi

# 2. Determine target version
if [[ -z "$TARGET_VERSION" ]]; then
  if [[ "$DRY_RUN" != "1" ]]; then
    TARGET_VERSION="$(cd "$SOURCE_DIR" && git tag --list --sort=-version:refname 'v*' 2>/dev/null | head -1)"
    if [[ -z "$TARGET_VERSION" ]]; then
      echo "ERROR: no v* tags found in $SOURCE_DIR" >&2
      exit 1
    fi
  else
    TARGET_VERSION="v<latest>"
  fi
fi
echo "  target:    $TARGET_VERSION"

# 3. Checkout target
echo "[2/5] git checkout $TARGET_VERSION"
if [[ "$DRY_RUN" != "1" ]]; then
  (cd "$SOURCE_DIR" && git checkout "$TARGET_VERSION" 2>&1 | tail -3)
fi

# 4. Remove orphan symlinks
echo "[3/5] removing orphan symlinks (from v2.0.1 install bug)"
orphan_count=0
remove_orphan() {
  local root="$1"
  [[ -d "$root" ]] || return 0
  # Match <version> directly under the cache/plugin dir (the v2.0.1 bug path)
  for hit in "$root"/*/; do
    [[ -e "$hit" || -L "$hit" ]] || continue
    base="$(basename "$hit")"
    # Heuristic: looks like a version (e.g. 2.0.1, 1.4.0)
    if [[ "$base" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[A-Za-z0-9.-]+)?$ ]]; then
      if [[ "$DRY_RUN" == "1" ]]; then
        echo "  DRY  would remove: $hit"
      else
        rm -rf "$hit"
        echo "  removed  $hit"
      fi
      orphan_count=$((orphan_count + 1))
    fi
  done
}
for p in "${ORPHAN_HOME_PATHS[@]}"; do remove_orphan "$p"; done
for p in "${ORPHAN_WS_PATHS[@]}"; do remove_orphan "$p"; done
echo "  → $orphan_count orphan(s) cleaned"

# 5. Reinstall (workspace pattern)
if [[ "$DO_REINSTALL" == "1" ]]; then
  echo "[4/5] foundry-install-workspace.sh"
  if [[ "$DRY_RUN" != "1" ]]; then
    bash "$SOURCE_DIR/packages/core/scripts/foundry-install-workspace.sh" \
      --source="$SOURCE_DIR" \
      --workspace="$WORKSPACE_DIR" 2>&1 | tail -15
  fi
else
  echo "[4/5] skipped (--no-reinstall)"
fi

# 6. Verify
if [[ "$DO_VERIFY" == "1" ]]; then
  echo "[5/5] verify"
  if [[ "$DRY_RUN" != "1" ]]; then
    target_short="${TARGET_VERSION#v}"
    ok=1
    for path in \
      "$HOME/.zcode/cli/plugins/cache/foundry-pipeline/$target_short" \
      "$HOME/.antigravity/plugins/foundry-pipeline/$target_short" \
      "$HOME/.mimocode/plugins/foundry-pipeline/$target_short" \
      "$HOME/.claude/plugins/cache/foundry-pipeline/$target_short"
    do
      if [[ -L "$path" ]]; then
        echo "  OK    $path"
      else
        echo "  MISS  $path"
        ok=0
      fi
    done
    if [[ "$ok" == "1" ]]; then
      echo ""
      echo "✓ Upgrade complete. v$target_short active."
    else
      echo ""
      echo "WARN: some symlinks missing — see above." >&2
      exit 1
    fi
  fi
else
  echo "[5/5] skipped (--no-verify)"
fi

exit 0