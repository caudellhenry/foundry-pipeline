#!/usr/bin/env bash
# packages/mimocode/install.sh
#
# Install foundry-pipeline for MimoCode.
# Plugin dir copy to ~/.mimocode/plugins/foundry-pipeline/<version>/

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

MIMOCODE_PLUGINS_DIR="${MIMOCODE_PLUGINS_DIR:-$HOME/.mimocode/plugins}"

if [[ "$UNINSTALL" -eq 1 ]]; then
  if [[ -d "$MIMOCODE_PLUGINS_DIR/$PLUGIN_NAME" ]]; then
    rm -rf "$MIMOCODE_PLUGINS_DIR/$PLUGIN_NAME"
    echo "Removed $MIMOCODE_PLUGINS_DIR/$PLUGIN_NAME"
  fi
  exit 0
fi

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
echo "Installing foundry-pipeline v$VERSION for MimoCode..."

(cd "$SOURCE_DIR" && bash scripts/foundry-monorepo-build.sh >/dev/null)

DEST="$MIMOCODE_PLUGINS_DIR/$PLUGIN_NAME/$VERSION"
mkdir -p "$DEST"
rm -rf "$DEST"
cp -R "$SOURCE_DIR/packages/mimocode/." "$DEST/"

echo ""
echo "✓ Installed foundry-pipeline v$VERSION to $DEST"
echo ""
echo "Restart MimoCode to pick up the new plugin."
exit 0