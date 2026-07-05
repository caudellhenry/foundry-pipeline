#!/usr/bin/env bash
# packages/antigravity/install.sh
#
# Install foundry-pipeline for Antigravity.
# Plugin dir copy to ~/.antigravity/plugins/foundry-pipeline/<version>/

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

ANTIGRAVITY_PLUGINS_DIR="${ANTIGRAVITY_PLUGINS_DIR:-$HOME/.antigravity/plugins}"

if [[ "$UNINSTALL" -eq 1 ]]; then
  if [[ -d "$ANTIGRAVITY_PLUGINS_DIR/$PLUGIN_NAME" ]]; then
    rm -rf "$ANTIGRAVITY_PLUGINS_DIR/$PLUGIN_NAME"
    echo "Removed $ANTIGRAVITY_PLUGINS_DIR/$PLUGIN_NAME"
  fi
  exit 0
fi

# Resolve source
if [[ -z "$SOURCE_DIR" ]]; then
  if [[ -n "$TAG" ]]; then
    SOURCE_DIR="/tmp/$PLUGIN_NAME-v$TAG"
    [[ -d "$SOURCE_DIR/.git" ]] || git clone --depth 1 --branch "v$TAG" "https://github.com/$CANONICAL_REPO.git" "$SOURCE_DIR"
  else
    SOURCE_DIR="/tmp/$PLUGIN_NAME-latest"
    [[ -d "$SOURCE_DIR/.git" ]] || git clone --depth 1 "https://github.com/$CANONICAL_REPO.git" "$SOURCE_DIR"
  fi
fi

if [[ ! -f "$SOURCE_DIR/VERSION" ]]; then
  echo "ERROR: $SOURCE_DIR does not look like foundry-pipeline" >&2
  exit 1
fi

VERSION="$(tr -d '[:space:]' < "$SOURCE_DIR/VERSION")"
echo "Installing foundry-pipeline v$VERSION for Antigravity..."

(cd "$SOURCE_DIR" && bash scripts/foundry-monorepo-build.sh >/dev/null)

# Copy the antigravity package (which has skills symlinks) into the Antigravity plugins dir
DEST="$ANTIGRAVITY_PLUGINS_DIR/$PLUGIN_NAME/$VERSION"
mkdir -p "$DEST"
rm -rf "$DEST"
cp -R "$SOURCE_DIR/packages/antigravity/." "$DEST/"

echo ""
echo "✓ Installed foundry-pipeline v$VERSION to $DEST"
echo ""
echo "Restart Antigravity to pick up the new plugin."
exit 0