#!/usr/bin/env bash
# packages/claude-code/install.sh
#
# Install foundry-pipeline for Claude Code.
#
# Strategy:
#   1. Resolve source dir (clone caudellhenry/foundry-pipeline if needed)
#   2. Run monorepo build (sync version + copy core into this package)
#   3. Symlink <CLAUDE_PLUGINS_DIR>/foundry-pipeline/<version> → source dir
#   4. Print post-install instructions
#
# Flags:
#   --source=<dir>      Use a local dir as source (skip clone)
#   --tag=<version>     Pin to a specific git tag (default: latest)
#   --uninstall         Reverse: remove symlink + .foundry-version-manifest

set -uo pipefail

CANONICAL_REPO="caudellhenry/foundry-pipeline"
PLUGIN_NAME="foundry-pipeline"

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

# Resolve Claude Code plugins dir
CLAUDE_PLUGINS_DIR="${CLAUDE_PLUGINS_DIR:-$HOME/.claude/plugins}"
PLUGIN_CACHE_DIR="$CLAUDE_PLUGINS_DIR/cache"

# Uninstall mode
if [[ "$UNINSTALL" -eq 1 ]]; then
  echo "Uninstalling $PLUGIN_NAME..."
  if [[ -d "$PLUGIN_CACHE_DIR/$PLUGIN_NAME" ]]; then
    rm -rf "$PLUGIN_CACHE_DIR/$PLUGIN_NAME"
    echo "Removed $PLUGIN_CACHE_DIR/$PLUGIN_NAME"
  fi
  echo "Note: you may also need to remove the symlink in $CLAUDE_PLUGINS_DIR/$PLUGIN_NAME"
  exit 0
fi

# Resolve source
if [[ -z "$SOURCE_DIR" ]]; then
  if [[ -n "$TAG" ]]; then
    echo "Cloning $CANONICAL_REPO at tag v$TAG..."
    SOURCE_DIR="/tmp/$PLUGIN_NAME-v$TAG"
    if [[ ! -d "$SOURCE_DIR/.git" ]]; then
      git clone --depth 1 --branch "v$TAG" "https://github.com/$CANONICAL_REPO.git" "$SOURCE_DIR"
    fi
  else
    echo "Cloning $CANONICAL_REPO (latest)..."
    SOURCE_DIR="/tmp/$PLUGIN_NAME-latest"
    if [[ ! -d "$SOURCE_DIR/.git" ]]; then
      git clone --depth 1 "https://github.com/$CANONICAL_REPO.git" "$SOURCE_DIR"
    else
      (cd "$SOURCE_DIR" && git pull --tags origin main >/dev/null 2>&1)
    fi
  fi
fi

if [[ ! -f "$SOURCE_DIR/VERSION" ]]; then
  echo "ERROR: $SOURCE_DIR does not look like foundry-pipeline (no VERSION file)" >&2
  exit 1
fi

VERSION="$(tr -d '[:space:]' < "$SOURCE_DIR/VERSION")"
echo "Installing foundry-pipeline v$VERSION..."

# Build the claude-code package (rsync core into it)
echo "Building claude-code package..."
(cd "$SOURCE_DIR" && bash scripts/foundry-monorepo-build.sh >/dev/null)

# Symlink into Claude Code plugins cache
mkdir -p "$PLUGIN_CACHE_DIR"
DEST="$PLUGIN_CACHE_DIR/$PLUGIN_NAME"

# Remove old versions
rm -rf "$DEST"

# Use a versioned subdir + a stable symlink at the top level
VERSIONED_DEST="$PLUGIN_CACHE_DIR/$PLUGIN_NAME/$VERSION"
mkdir -p "$(dirname "$VERSIONED_DEST")"
ln -sfn "$SOURCE_DIR/packages/claude-code" "$VERSIONED_DEST"

# Top-level stable symlink to the latest
ln -sfn "$VERSION" "$DEST/.latest-version"

echo ""
echo "✓ Installed foundry-pipeline v$VERSION"
echo ""
echo "Next steps:"
echo "  1. Add the marketplace (one-time):"
echo "     /plugin marketplace add $CANONICAL_REPO"
echo ""
echo "  2. Install in Claude Code:"
echo "     /plugin install $PLUGIN_NAME@$PLUGIN_NAME"
echo ""
echo "  3. Verify:"
echo "     /foundry:status"
echo ""
echo "Or run directly from this dir:"
echo "  bash $SOURCE_DIR/packages/claude-code/hooks/session-start.sh"
exit 0