#!/usr/bin/env bash
# packages/opencode/install.sh
# Same as hermes but for OpenCode at ~/.opencode/skills/

set -uo pipefail

CANONICAL_REPO="caudellhenry/foundry-pipeline"

SOURCE_DIR=""
TAG=""
UNINSTALL=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --source=*)   SOURCE_DIR="${1#--source=}"; shift ;;
    --tag=*)      TAG="${1#--tag=}"; shift ;;
    --uninstall)  UNINSTALL=1; shift ;;
    *) echo "Unknown flag: $1" >&2; exit 2 ;;
  esac
done

OPENCODE_SKILLS_DIR="${OPENCODE_SKILLS_DIR:-$HOME/.opencode/skills}"

if [[ "$UNINSTALL" -eq 1 ]]; then
  echo "Uninstalling foundry-pipeline from OpenCode..."
  if [[ -d "$OPENCODE_SKILLS_DIR" ]]; then
    find "$OPENCODE_SKILLS_DIR" -maxdepth 1 -name 'foundry-*' -type l -exec rm {} +
    echo "Removed all foundry-* symlinks from $OPENCODE_SKILLS_DIR"
  fi
  exit 0
fi

if [[ -z "$SOURCE_DIR" ]]; then
  if [[ -n "$TAG" ]]; then
    SOURCE_DIR="/tmp/foundry-pipeline-v$TAG"
    [[ -d "$SOURCE_DIR/.git" ]] || git clone --depth 1 --branch "v$TAG" "https://github.com/$CANONICAL_REPO.git" "$SOURCE_DIR"
  else
    SOURCE_DIR="/tmp/foundry-pipeline-latest"
    [[ -d "$SOURCE_DIR/.git" ]] || git clone --depth 1 "https://github.com/$CANONICAL_REPO.git" "$SOURCE_DIR"
  fi
fi

if [[ ! -d "$SOURCE_DIR/packages/core/skills" ]]; then
  echo "ERROR: $SOURCE_DIR does not look like foundry-pipeline" >&2
  exit 1
fi

mkdir -p "$OPENCODE_SKILLS_DIR"

count=0
for skill_dir in "$SOURCE_DIR/packages/core/skills/"*/; do
  [[ -d "$skill_dir" ]] || continue
  skill_name=$(basename "$skill_dir")
  link_name="foundry-${skill_name}"
  ln -sfn "$skill_dir" "$OPENCODE_SKILLS_DIR/$link_name"
  ((count++))
done

echo ""
echo "✓ Installed $count foundry skills to $OPENCODE_SKILLS_DIR"
echo ""
echo "OpenCode auto-discovers skills from ~/.opencode/skills/. Restart to pick them up."
exit 0