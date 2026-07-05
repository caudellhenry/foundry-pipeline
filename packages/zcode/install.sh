#!/usr/bin/env bash
# packages/zcode/install.sh
#
# Install foundry-pipeline for Zcode.
#
# Strategy:
#   1. Resolve source dir (clone caudellhenry/foundry-pipeline if needed)
#   2. Run monorepo build (sync version + copy core into this package)
#   3. Symlink ~/.zcode/cli/plugins/cache/foundry-pipeline/<version> → packages/zcode
#   4. Print post-install instructions
#
# Flags:
#   --source=<dir>      Use a local dir as source (skip clone)
#   --tag=<version>     Pin to a specific git tag (default: latest)
#   --uninstall         Reverse: remove symlink

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

# Resolve Zcode plugin cache dir
ZCODE_CACHE_DIR="${ZCODE_CACHE_DIR:-$HOME/.zcode/cli/plugins/cache}"

if [[ "$UNINSTALL" -eq 1 ]]; then
  echo "Uninstalling $PLUGIN_NAME from Zcode..."
  if [[ -d "$ZCODE_CACHE_DIR/$PLUGIN_NAME" ]]; then
    rm -rf "$ZCODE_CACHE_DIR/$PLUGIN_NAME"
    echo "Removed $ZCODE_CACHE_DIR/$PLUGIN_NAME"
  fi
  exit 0
fi

# Resolve source
if [[ -z "$SOURCE_DIR" ]]; then
  if [[ -n "$TAG" ]]; then
    SOURCE_DIR="/tmp/$PLUGIN_NAME-v$TAG"
    if [[ ! -d "$SOURCE_DIR/.git" ]]; then
      git clone --depth 1 --branch "v$TAG" "https://github.com/$CANONICAL_REPO.git" "$SOURCE_DIR"
    fi
  else
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
echo "Installing foundry-pipeline v$VERSION for Zcode..."

# Build the zcode package
echo "Building zcode package..."
(cd "$SOURCE_DIR" && bash scripts/foundry-monorepo-build.sh >/dev/null)

# Symlink into Zcode plugin cache
mkdir -p "$ZCODE_CACHE_DIR"
DEST="$ZCODE_CACHE_DIR/$PLUGIN_NAME/$VERSION"
ln -sfn "$SOURCE_DIR/packages/zcode" "$DEST"

echo ""
echo "✓ Installed foundry-pipeline v$VERSION to $DEST"
echo ""
echo "Next steps:"
echo "  1. Restart Zcode to pick up the new plugin."
echo "  2. Verify:"
echo "     /foundry:status"
echo ""
echo "Or run directly from this dir:"
echo "  bash $SOURCE_DIR/packages/zcode/hooks/session-start.sh"
exit 0