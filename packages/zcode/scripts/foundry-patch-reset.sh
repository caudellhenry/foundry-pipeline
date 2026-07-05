#!/usr/bin/env bash
# packages/core/scripts/foundry-patch-reset.sh
#
# Discard local foundry-pipeline edits and reinstall canonical v$VERSION.

set -uo pipefail

CANONICAL_REPO="caudellhenry/foundry-pipeline"

SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="$(cd "$SCRIPT_PATH/../.." && pwd)"

if [[ -f "$INSTALL_DIR/VERSION" ]]; then
  VERSION="$(tr -d '[:space:]' < "$INSTALL_DIR/VERSION")"
else
  echo "ERROR: VERSION file not found at $INSTALL_DIR/VERSION" >&2
  exit 1
fi

# Backup local edits
BACKUP_DIR="$HOME/.foundry/patch-reset-backups/$(date -u +%Y%m%dT%H%M%SZ)"
mkdir -p "$BACKUP_DIR"
echo "Backing up $INSTALL_DIR to $BACKUP_DIR..."
cp -R "$INSTALL_DIR" "$BACKUP_DIR/"

# Confirm
read -r -p "Are you sure you want to discard local edits and reinstall canonical v$VERSION? [y/N] " response
if [[ ! "$response" =~ ^[Yy]$ ]]; then
  echo "Cancelled. Backup preserved at $BACKUP_DIR."
  exit 1
fi

# Reinstall
echo "Reinstalling canonical v$VERSION..."
if [[ -d "$INSTALL_DIR/.git" ]]; then
  cd "$INSTALL_DIR"
  git fetch --tags origin >/dev/null 2>&1
  git checkout "v${VERSION}" >/dev/null 2>&1
  git clean -fdx >/dev/null 2>&1
else
  # Re-extract from GitHub tarball
  tmpdir=$(mktemp -d)
  curl -sSfL "https://github.com/${CANONICAL_REPO}/archive/refs/tags/v${VERSION}.tar.gz" \
    | tar -xz -C "$tmpdir" --strip-components=1
  rm -rf "$INSTALL_DIR"
  mkdir -p "$INSTALL_DIR"
  cp -R "$tmpdir"/. "$INSTALL_DIR"/
  rm -rf "$tmpdir"
fi

echo "Reset complete. Local edits backed up to $BACKUP_DIR."
exit 0