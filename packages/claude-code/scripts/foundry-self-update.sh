#!/usr/bin/env bash
# packages/core/scripts/foundry-self-update.sh
#
# Detect local divergence between the installed foundry-pipeline and the
# canonical version in caudellhenry/foundry-pipeline at the current tag.
#
# Two detection modes:
#   A) git-aware — when install dir is a git checkout
#   B) file-checksum — when install dir is NOT a git checkout
#
# Output:
#   exit 0  — local equals canonical (or snooze active)
#   exit 1  — local diverges from canonical (emit divergence prompt)
#
# Flags:
#   --emit-hook-json   Emit JSON suitable for a hook 'additionalContext' field
#   --install-dir=DIR  Override install dir detection
#   --version=VERSION  Override canonical version (default: auto-detect)
#   --no-snooze        Bypass the ~/.foundry/patch-skip-until snooze

set -uo pipefail

# Canonical repo
CANONICAL_REPO="caudellhenry/foundry-pipeline"
CANONICAL_API_BASE="https://api.github.com"
CANONICAL_RAW_BASE="https://raw.githubusercontent.com/${CANONICAL_REPO}"

# Parse flags
EMIT_JSON=0
INSTALL_DIR=""
VERSION_OVERRIDE=""
NO_SNOOZE=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --emit-hook-json)  EMIT_JSON=1; shift ;;
    --install-dir=*)   INSTALL_DIR="${1#--install-dir=}"; shift ;;
    --version=*)       VERSION_OVERRIDE="${1#--version=}"; shift ;;
    --no-snooze)       NO_SNOOZE=1; shift ;;
    *) echo "Unknown flag: $1" >&2; exit 2 ;;
  esac
done

# Detect install dir (resolves symlinks)
if [[ -z "$INSTALL_DIR" ]]; then
  SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  INSTALL_DIR="$(cd "$SCRIPT_PATH/../.." && pwd)"
fi

# Detect version
if [[ -z "$VERSION_OVERRIDE" ]]; then
  if [[ -f "$INSTALL_DIR/VERSION" ]]; then
    VERSION_OVERRIDE="$(tr -d '[:space:]' < "$INSTALL_DIR/VERSION")"
  else
    echo "ERROR: cannot detect version (no VERSION file at $INSTALL_DIR)" >&2
    exit 1
  fi
fi

# Check snooze
if [[ "$NO_SNOOZE" -eq 0 && -f "$HOME/.foundry/patch-skip-until" ]]; then
  skip_until=$(tr -d '[:space:]' < "$HOME/.foundry/patch-skip-until" 2>/dev/null || echo "")
  if [[ -n "$skip_until" ]] && date "+%Y-%m-%d" >/dev/null 2>&1; then
    today=$(date "+%Y-%m-%d")
    if [[ "$today" < "$skip_until" ]]; then
      exit 0  # Snoozed
    fi
  fi
fi

# Detect mode
IS_GIT_CHECKOUT=0
if [[ -d "$INSTALL_DIR/.git" ]] || git -C "$INSTALL_DIR" rev-parse --git-dir >/dev/null 2>&1; then
  IS_GIT_CHECKOUT=1
fi

# Helper: emit divergence prompt
emit_prompt() {
  local files_changed="$1"
  local commits_ahead="$2"

  if [[ "$EMIT_JSON" -eq 1 ]]; then
    # JSON output for hook additionalContext
    cat <<EOF
{
  "hookSpecificOutput": {
    "additionalContext": "⚠️  foundry v${VERSION_OVERRIDE} installed locally differs from canonical v${VERSION_OVERRIDE}.\\n\\n    ${files_changed} files modified.\\n    ${commits_ahead} unpushed commits ahead.\\n\\n    Commands:\\n      /foundry:patch-diff    Show the diff vs canonical\\n      /foundry:patch-push    Push local changes to ${CANONICAL_REPO}\\n      /foundry:patch-reset   Discard local changes, reinstall canonical v${VERSION_OVERRIDE}\\n      /foundry:patch-skip    Ignore this divergence (default 30 days)"
  }
}
EOF
  else
    cat <<EOF
⚠️  foundry v${VERSION_OVERRIDE} installed locally differs from canonical v${VERSION_OVERRIDE}.

    ${files_changed} files modified.
    ${commits_ahead} unpushed commits ahead.

    Commands:
      /foundry:patch-diff    Show the diff vs canonical
      /foundry:patch-push    Push local changes to ${CANONICAL_REPO}
      /foundry:patch-reset   Discard local changes, reinstall canonical v${VERSION_OVERRIDE}
      /foundry:patch-skip    Ignore this divergence (default 30 days)
EOF
  fi
}

if [[ "$IS_GIT_CHECKOUT" -eq 1 ]]; then
  # Mode A — git-aware
  local_head=$(git -C "$INSTALL_DIR" rev-parse HEAD 2>/dev/null || echo "")
  upstream_sha=$(git ls-remote --tags "https://github.com/${CANONICAL_REPO}.git" "v${VERSION_OVERRIDE}" 2>/dev/null | awk '{print $1}' | head -1 || echo "")

  if [[ -z "$local_head" || -z "$upstream_sha" ]]; then
    echo "ERROR: could not resolve local/upstream SHA" >&2
    exit 1
  fi

  if [[ "$local_head" == "$upstream_sha" ]]; then
    exit 0  # In sync
  fi

  # Compute diff stats
  files_changed=$(git -C "$INSTALL_DIR" diff --name-only "v${VERSION_OVERRIDE}..HEAD" 2>/dev/null | wc -l | tr -d ' ')
  commits_ahead=$(git -C "$INSTALL_DIR" rev-list --count "v${VERSION_OVERRIDE}..HEAD" 2>/dev/null || echo "?")

  emit_prompt "$files_changed" "$commits_ahead"
  exit 1
else
  # Mode B — file-checksum
  # Read canonical manifest
  manifest_url="${CANONICAL_RAW_BASE}/v${VERSION_OVERRIDE}/packages/claude-code/.foundry-version-manifest.json"
  manifest=$(curl -sSfL "$manifest_url" 2>/dev/null || echo "")

  if [[ -z "$manifest" ]]; then
    echo "ERROR: could not fetch canonical manifest from $manifest_url" >&2
    exit 1
  fi

  # Compare every file in the manifest
  files_changed=0
  while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    local_file="$INSTALL_DIR/$file"
    if [[ ! -f "$local_file" ]]; then
      ((files_changed++))
      continue
    fi
    local_sha=$(shasum -a 256 "$local_file" 2>/dev/null | awk '{print $1}')
    canonical_sha=$(echo "$manifest" | jq -r --arg f "$file" '.files[$f] // empty')
    if [[ "$local_sha" != "$canonical_sha" ]]; then
      ((files_changed++))
    fi
  done < <(echo "$manifest" | jq -r '.files | keys[]')

  if [[ "$files_changed" -eq 0 ]]; then
    exit 0  # In sync
  fi

  emit_prompt "$files_changed" "?"
  exit 1
fi