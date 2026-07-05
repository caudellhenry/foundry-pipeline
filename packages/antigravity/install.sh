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

# Link (or copy if FOUNDRY_INSTALL_COPY=1) the antigravity package into the
# Antigravity plugins dir. Default: ln -sfn so `git pull` in the canonical
# clone updates every harness at once.
DEST="$ANTIGRAVITY_PLUGINS_DIR/$PLUGIN_NAME/$VERSION"
mkdir -p "$ANTIGRAVITY_PLUGINS_DIR/$PLUGIN_NAME"

if [[ "${FOUNDRY_INSTALL_COPY:-0}" == "1" ]]; then
  rm -rf "$DEST"
  cp -R "$SOURCE_DIR/packages/antigravity/." "$DEST/"
  echo "  mode: copy (FOUNDRY_INSTALL_COPY=1)"
else
  ln -sfn "$SOURCE_DIR/packages/antigravity" "$DEST"
  echo "  mode: symlink (default — pull in the clone to update)"
fi

echo ""
echo "✓ Installed foundry-pipeline v$VERSION to $DEST"
echo ""
echo "Restart Antigravity to pick up the new plugin."
exit 0