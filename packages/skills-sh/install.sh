#!/usr/bin/env bash
# packages/skills-sh/install.sh
#
# Install foundry-pipeline for skills.sh (https://skills.sh).
# Skills-only — no commands/hooks. Skills auto-discovered by the
# Agent Skills standard via `npx skills add caudellhenry/foundry-pipeline`.
#
# Flags:
#   --source=<dir>      Use a local dir as source
#   --tag=<version>     Pin to a specific git tag
#   --uninstall         Reverse
#
# When called directly, this prints the install command for the user to run.
# When called with --source, it symlinks each skill into a target dir.

set -uo pipefail

CANONICAL_REPO="caudellhenry/foundry-pipeline"

SOURCE_DIR=""
TAG=""
UNINSTALL=0
TARGET_DIR=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --source=*)   SOURCE_DIR="${1#--source=}"; shift ;;
    --tag=*)      TAG="${1#--tag=}"; shift ;;
    --uninstall)  UNINSTALL=1; shift ;;
    --target=*)   TARGET_DIR="${1#--target=}"; shift ;;
    *) echo "Unknown flag: $1" >&2; exit 2 ;;
  esac
done

if [[ "$UNINSTALL" -eq 1 && -n "$TARGET_DIR" ]]; then
  if [[ -d "$TARGET_DIR" ]]; then
    find "$TARGET_DIR" -maxdepth 1 -name 'foundry-*' -type l -exec rm {} +
    echo "Removed all foundry-* symlinks from $TARGET_DIR"
  fi
  exit 0
fi

# Resolve source
if [[ -z "$SOURCE_DIR" ]]; then
  if [[ -n "$TAG" ]]; then
    SOURCE_DIR="/tmp/foundry-pipeline-v$TAG"
    [[ -d "$SOURCE_DIR/.git" ]] || git clone --depth 1 --branch "v$TAG" "https://github.com/$CANONICAL_REPO.git" "$SOURCE_DIR"
  else
    SOURCE_DIR="/tmp/foundry-pipeline-latest"
    [[ -d "$SOURCE_DIR/.git" ]] || git clone --depth 1 "https://github.com/$CANONICAL_REPO.git" "$SOURCE_DIR"
  fi
fi

# If --target given, symlink skills into it
if [[ -n "$TARGET_DIR" ]]; then
  mkdir -p "$TARGET_DIR"
  count=0
  for skill_dir in "$SOURCE_DIR/packages/core/skills/"*/; do
    [[ -d "$skill_dir" ]] || continue
    skill_name=$(basename "$skill_dir")
    ln -sfn "$skill_dir" "$TARGET_DIR/$skill_name"
    ((count++))
  done
  echo "Installed $count skills into $TARGET_DIR"
  exit 0
fi

# Default: print the npx skills add command
cat <<EOF

skills.sh install (recommended):

  npx skills add $CANONICAL_REPO

This installs the 15 portable skills (ship, grill, research, prototype, prd,
tdd, board, implement, qa, diagnose, security-review, handoff, evals,
literate-diff, context-rotate) into your agent's skills directory.

Note: skills.sh supports only skills (no commands/hooks). For full
plugin surface (commands + hooks), install the Claude Code or Zcode package.

EOF
exit 0