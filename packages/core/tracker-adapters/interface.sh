#!/usr/bin/env bash
# packages/core/tracker-adapters/interface.sh
#
# Common tracker interface — every adapter must implement these functions.
#
# Usage in a skill/script:
#   source packages/core/tracker-adapters/interface.sh
#   source packages/core/tracker-adapters/<backend>/adapter.sh
#   tracker_init || exit 1
#   issue_id=$(tracker_create_issue "Title" "Body" "label1,label2")
#   tracker_update_status "$issue_id" "in_progress"
#
# All implementations emit JSON to stdout unless --quiet is passed.

set -uo pipefail

# Path to current adapter (set by sourcing the adapter)
: "${TRACKER_ADAPTER:=local}"
: "${TRACKER_DIR:=.foundry}"
: "${TRACKER_STATE_FILE:=$TRACKER_DIR/state.md}"

# Common helpers (shared across adapters)
_tracker_log() {
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $*" >> "$TRACKER_DIR/logs/tracker.log" 2>/dev/null || true
}

_tracker_jq_escape() {
  jq -Rn --arg s "$1" '$s'
}

# Tracker status enums (canonical)
TRACKER_STATUS_READY="ready"
TRACKER_STATUS_IN_PROGRESS="in_progress"
TRACKER_STATUS_REVIEW="review"
TRACKER_STATUS_DONE="done"
TRACKER_STATUS_BLOCKED="blocked"

# Validate status
tracker_validate_status() {
  local status="$1"
  case "$status" in
    ready|in_progress|review|done|blocked) return 0 ;;
    *) echo "ERROR: invalid status '$status' (must be ready|in_progress|review|done|blocked)" >&2; return 1 ;;
  esac
}

# Dispatch a tracker function based on $TRACKER_ADAPTER.
# Usage: tracker_dispatch <function_name> [args...]
tracker_dispatch() {
  local fn="$1"
  shift
  case "$TRACKER_ADAPTER" in
    local)  "tracker_local_${fn#tracker_}" "$@" ;;
    github) "tracker_github_${fn#tracker_}" "$@" ;;
    linear) "tracker_linear_${fn#tracker_}" "$@" ;;
    *)
      echo "ERROR: unknown tracker adapter '$TRACKER_ADAPTER'" >&2
      return 1
      ;;
  esac
}

# Auto-detect which adapter to use from state.md frontmatter
tracker_autodetect() {
  if [[ ! -f "$TRACKER_STATE_FILE" ]]; then
    TRACKER_ADAPTER="local"
    return
  fi
  local detected
  detected=$(awk '/^tracker:/{flag=1; next} flag && /^  backend:/{print $2; exit} flag && /^[a-z]/{exit}' "$TRACKER_STATE_FILE" 2>/dev/null)
  if [[ -z "$detected" ]]; then
    TRACKER_ADAPTER="local"
  else
    TRACKER_ADAPTER="$detected"
  fi
}

# Public API — all dispatch via tracker_dispatch
tracker_init()           { tracker_dispatch init "$@"; }
tracker_create_issue()   { tracker_dispatch create_issue "$@"; }
tracker_update_status()  { tracker_dispatch update_status "$@"; }
tracker_add_comment()    { tracker_dispatch add_comment "$@"; }
tracker_get_issue()      { tracker_dispatch get_issue "$@"; }
tracker_list_issues()    { tracker_dispatch list_issues "$@"; }
tracker_link_dep()       { tracker_dispatch link_dep "$@"; }

# Export public API
export -f tracker_init tracker_create_issue tracker_update_status \
          tracker_add_comment tracker_get_issue tracker_list_issues \
          tracker_link_dep tracker_dispatch tracker_autodetect \
          tracker_validate_status _tracker_log _tracker_jq_escape