#!/usr/bin/env bash
# packages/hermes/install.sh
#
# Install foundry-pipeline for Hermes.
# Strategy: symlink each packages/core/skills/<name> → ~/.hermes/skills/foundry-<name>
#
# Flags:
#   --source=<dir>      Use a local dir as source
#   --tag=<version>     Pin to a specific git tag
#   --uninstall         Reverse: remove all foundry-* symlinks

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

HERMES_SKILLS_DIR="${HERMES_SKILLS_DIR:-$HOME/.hermes/skills}"

if [[ "$UNINSTALL" -eq 1 ]]; then
  echo "Uninstalling foundry-pipeline from Hermes..."
  if [[ -d "$HERMES_SKILLS_DIR" ]]; then
    find "$HERMES_SKILLS_DIR" -maxdepth 1 -name 'foundry-*' -type l -exec rm {} +
    echo "Removed all foundry-* symlinks from $HERMES_SKILLS_DIR"
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

if [[ ! -d "$SOURCE_DIR/packages/core/skills" ]]; then
  echo "ERROR: $SOURCE_DIR does not look like foundry-pipeline" >&2
  exit 1
fi

mkdir -p "$HERMES_SKILLS_DIR"

count=0
for skill_dir in "$SOURCE_DIR/packages/core/skills/"*/; do
  [[ -d "$skill_dir" ]] || continue
  skill_name=$(basename "$skill_dir")
  link_name="foundry-${skill_name}"
  ln -sfn "$skill_dir" "$HERMES_SKILLS_DIR/$link_name"
  ((count++))
done

echo ""
echo "✓ Installed $count foundry skills to $HERMES_SKILLS_DIR"
echo ""
echo "Hermes auto-discovers skills from ~/.hermes/skills/. Restart Hermes to pick them up."
exit 0