#!/usr/bin/env bash
# packages/core/scripts/foundry-patch-diff.sh
#
# Show the full diff between the local foundry-pipeline install and the
# canonical v$VERSION tag.

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

if [[ -d "$INSTALL_DIR/.git" ]]; then
  # git-aware
  git -C "$INSTALL_DIR" diff "v${VERSION}..HEAD" --stat
  echo ""
  git -C "$INSTALL_DIR" diff "v${VERSION}..HEAD"
else
  # file-checksum mode — fetch manifest, compare each file
  manifest=$(curl -sSfL "https://raw.githubusercontent.com/${CANONICAL_REPO}/v${VERSION}/packages/claude-code/.foundry-version-manifest.json" 2>/dev/null || echo "")
  if [[ -z "$manifest" ]]; then
    echo "ERROR: could not fetch canonical manifest" >&2
    exit 1
  fi
  echo "$manifest" | jq -r '.files | keys[]' | while IFS= read -r file; do
    local_file="$INSTALL_DIR/$file"
    if [[ ! -f "$local_file" ]]; then
      echo "DELETED: $file"
      continue
    fi
    local_sha=$(shasum -a 256 "$local_file" 2>/dev/null | awk '{print $1}')
    canonical_sha=$(echo "$manifest" | jq -r --arg f "$file" '.files[$f]')
    if [[ "$local_sha" != "$canonical_sha" ]]; then
      echo "MODIFIED: $file (local=$local_sha canonical=$canonical_sha)"
    fi
  done
fi