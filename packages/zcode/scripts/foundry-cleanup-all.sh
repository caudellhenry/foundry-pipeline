#!/usr/bin/env bash
# packages/core/scripts/foundry-cleanup-all.sh
#
# Cross-harness cleanup. Removes legacy foundry/sdlc/ai-eng/ai-eng-sdlc
# artifacts from every harness plugin dir (home + workspace), backs them
# up to ~/.foundry.bak.<timestamp>/, preserves ~/.foundry/, and clears
# /tmp/foundry-pipeline-*. Idempotent.
#
# Patterns matched:
#   foundry-*  sdlc-*  ai-eng-*  ai-eng-sdlc-*
#
# Targets (home, 14):
#   ~/.claude ~/.zcode ~/.hermes ~/.opencode ~/.antigravity ~/.mimocode
#   ~/.minimax ~/.cursor ~/.codex ~/.windsurf ~/.cline ~/.gemini
#   ~/.continue ~/.agents
#
# Targets (workspace, 13):
#   $WORKSPACE/.claude .zcode .hermes .opencode .antigravity .mimocode
#   .minimax .cursor .codex .windsurf .cline .gemini .cua-driver
#
# Flags:
#   --workspace=<dir>     Workspace root (default: $HOME/Agents Workspace)
#   --dry-run             Print what would be removed; do not touch disk
#   --no-backup           Skip the ~/.foundry.bak.<ts>/ archive
#   -h, --help            Show this help

set -uo pipefail

WORKSPACE_DIR="${HOME}/Agents Workspace"
DRY_RUN=0
DO_BACKUP=1

HOME_HARNESSES=(
  .claude .zcode .hermes .opencode .antigravity .mimocode
  .minimax .cursor .codex .windsurf .cline .gemini .continue .agents
)
WORKSPACE_HARNESSES=(
  .claude .zcode .hermes .opencode .antigravity .mimocode
  .minimax .cursor .codex .windsurf .cline .gemini .cua-driver
)
PATTERNS=(foundry-* sdlc-* ai-eng-* ai-eng-sdlc-*)

while [[ $# -gt 0 ]]; do
  case "$1" in
    --workspace=*)  WORKSPACE_DIR="${1#--workspace=}"; shift ;;
    --dry-run)      DRY_RUN=1; shift ;;
    --no-backup)    DO_BACKUP=0; shift ;;
    -h|--help)
      sed -n '2,/^set -uo/p' "$0" | sed 's/^# \{0,1\}//' | head -40
      exit 0
      ;;
    *) echo "Unknown flag: $1" >&2; exit 2 ;;
  esac
done

TS="$(date -u +%Y%m%dT%H%M%SZ)"
BACKUP_DIR="$HOME/.foundry.bak.$TS"

move_or_print() {
  local src="$1"
  if [[ -z "$src" || ! -e "$src" && ! -L "$src" ]]; then
    return 0
  fi
  if [[ "$DRY_RUN" == "1" ]]; then
    echo "  DRY  would move: $src"
    return 0
  fi
  if [[ "$DO_BACKUP" == "1" ]]; then
    local rel="${src#$HOME/}"
    local dest="$BACKUP_DIR/$rel"
    mkdir -p "$(dirname "$dest")"
    mv "$src" "$dest"
    echo "  MOVED  $src → $dest"
  else
    rm -rf "$src"
    echo "  REMOVED  $src"
  fi
}

scan_dir() {
  local root="$1"
  local label="$2"
  [[ -d "$root" ]] || return 0
  for pat in "${PATTERNS[@]}"; do
    # Match both regular entries and broken symlinks (-L/-e for symlink, then check type)
    # Use nullglob to skip when no matches
    shopt -s nullglob dotglob
    local hits=()
    # shellcheck disable=SC2207  # we want glob expansion
    hits=($(compgen -G "$root/$pat" 2>/dev/null || true))
    shopt -u nullglob dotglob
    for hit in "${hits[@]+"${hits[@]}"}"; do
      [[ -e "$hit" || -L "$hit" ]] || continue
      move_or_print "$hit"
    done
  done
}

echo "foundry-cleanup-all — cross-harness cleanup"
echo "  timestamp:  $TS"
echo "  workspace:  $WORKSPACE_DIR"
echo "  dry-run:    $DRY_RUN"
echo "  backup:     $DO_BACKUP"
echo ""

if [[ "$DO_BACKUP" == "1" && "$DRY_RUN" != "1" ]]; then
  mkdir -p "$BACKUP_DIR"
  echo "  backup → $BACKUP_DIR"
  echo ""
fi

echo "--- home harnesses (${#HOME_HARNESSES[@]}) ---"
for h in "${HOME_HARNESSES[@]}"; do
  scan_dir "$HOME/$h" "home:$h"
done

echo ""
echo "--- workspace harnesses (${#WORKSPACE_HARNESSES[@]}) ---"
if [[ -d "$WORKSPACE_DIR" ]]; then
  for h in "${WORKSPACE_HARNESSES[@]}"; do
    scan_dir "$WORKSPACE_DIR/$h" "work:$h"
  done
else
  echo "  (workspace dir $WORKSPACE_DIR not present — skipping)"
fi

# Clear /tmp clone dirs
echo ""
echo "--- /tmp/foundry-pipeline-* ---"
shopt -s nullglob
tmp_hits=(/tmp/foundry-pipeline-* /tmp/foundry-pipeline)
shopt -u nullglob
for hit in "${tmp_hits[@]}"; do
  [[ -e "$hit" || -L "$hit" ]] || continue
  move_or_print "$hit"
done

echo ""
if [[ "$DRY_RUN" == "1" ]]; then
  echo "(dry-run) no changes made."
elif [[ "$DO_BACKUP" == "1" ]]; then
  echo "✓ Cleanup complete. Backup: $BACKUP_DIR"
else
  echo "✓ Cleanup complete (no backup)."
fi
exit 0