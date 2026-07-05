#!/usr/bin/env bash
# foundry-tracker-pull-issue.sh — Fetch a single tracker issue into a foundry story
#
# Usage:
#   foundry-tracker-pull-issue.sh <ISSUE-IDENTIFIER>             # HAC-42 (Linear) | 42 / #42 / URL (GitHub)
#   foundry-tracker-pull-issue.sh <ISSUE-IDENTIFIER> --dry-run
#   foundry-tracker-pull-issue.sh <ISSUE-IDENTIFIER> --no-status-flip
#   foundry-tracker-pull-issue.sh --issue-url=<FULL-URL>
#
# Backend is auto-detected from .foundry/state.md `tracker.backend`. Supported:
#   - linear  (default if `tracker.linear.team_id` is set)
#   - github  (default if `tracker.github.repo` is set)
#   - local   (rejected with a clear error; use the local tracker adapter directly)
#
# What it does:
#   1. Reads `tracker:` block from .foundry/state.md to discover backend
#   2. Sources the configured adapter + the shared tracker-pull-common.sh helpers
#   3. Calls tracker_get_issue (via the adapter) to fetch the full issue
#   4. Maps the public identifier to a STORY-NNN local sid
#   5. Writes .foundry/plan/stories/<SID>.md via tracker_pull_write_story_file
#   6. Adds the SID to `## Ready` in .foundry/plan/board.md (idempotent)
#   7. Sets phases.execute.platform=<backend> if unset, bumps current_phase=execute
#   8. (Optional) Calls tracker_update_status to flip the tracker issue In Progress
#
# Idempotent: re-running on the same identifier updates the local story body
# but preserves the STORY-NNN id (so we don't churn the local board).

set -uo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
PROJECT_ROOT="${DEV_PIPELINE_PROJECT_ROOT:-$(pwd)}"
FOUNDRY_DIR="${FOUNDRY_DIR:-$PROJECT_ROOT/.foundry}"
STATE_FILE="${STATE_FILE:-$FOUNDRY_DIR/state.md}"
STORIES_DIR="${STORIES_DIR:-$FOUNDRY_DIR/plan/stories}"
TRACKER_ADAPTERS_DIR="$PLUGIN_ROOT/tracker-adapters"
SHARED_LIB="$PLUGIN_ROOT/scripts/lib/tracker-pull-common.sh"

# Source the tracker-adapter interface (provides tracker_autodetect + dispatch)
if [[ ! -f "$TRACKER_ADAPTERS_DIR/interface.sh" ]]; then
  echo "ERROR: can't find tracker-adapters/interface.sh at $TRACKER_ADAPTERS_DIR" >&2
  exit 1
fi
# shellcheck disable=SC1091
source "$TRACKER_ADAPTERS_DIR/interface.sh"

# Source the shared story-write helpers (used by both backend paths)
if [[ ! -f "$SHARED_LIB" ]]; then
  echo "ERROR: can't find $SHARED_LIB" >&2
  exit 1
fi
# shellcheck disable=SC1091
source "$SHARED_LIB"

tracker_autodetect
BACKEND="${TRACKER_ADAPTER:-local}"
DRY_RUN=0
MARK_IN_PROGRESS=1  # by default, flip the issue to "In Progress" on import

# Parse args
IDENTIFIER=""
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --no-status-flip) MARK_IN_PROGRESS=0 ;;
    --issue-url=*) IDENTIFIER="${arg#--issue-url=}" ;;
    -h|--help)
      cat <<'EOF'
usage: foundry-tracker-pull-issue.sh <ISSUE-IDENTIFIER> [--dry-run] [--no-status-flip]

Pulls a single tracker issue into .foundry/plan/stories/ and sets the
foundry pipeline to current_phase=execute so the next /foundry-execute
(or /foundry-loop-on) picks it up immediately.

Backend is auto-detected from .foundry/state.md (tracker.backend).

Identifiers by backend:
  linear  HAC-42               (public identifier; UUID resolved via GraphQL)
  github  42, #42, or full URL (e.g. https://github.com/owner/repo/issues/42)

Flags:
  --dry-run         Show what would happen, write no files, no API mutations
  --no-status-flip  Don't flip the tracker issue to "In Progress" on import

Examples:
  foundry-tracker-pull-issue.sh HAC-42              # Linear
  foundry-tracker-pull-issue.sh 42                  # GitHub
  foundry-tracker-pull-issue.sh '#42' --dry-run     # GitHub dry-run
  foundry-tracker-pull-issue.sh HAC-42 --no-status-flip   # import as-is
EOF
      exit 0 ;;
    *)
      if [[ -z "$IDENTIFIER" ]]; then IDENTIFIER="$arg"
      else echo "ERROR: unexpected arg '$arg'" >&2; exit 2
      fi
      ;;
  esac
done

if [[ -z "$IDENTIFIER" ]]; then
  echo "usage: foundry-tracker-pull-issue.sh <ISSUE-IDENTIFIER>" >&2
  exit 2
fi

# Source backend-specific adapter
case "$BACKEND" in
  linear) source "$TRACKER_ADAPTERS_DIR/linear/adapter.sh" ;;
  github) source "$TRACKER_ADAPTERS_DIR/github/adapter.sh" ;;
  local)
    echo "ERROR: foundry-tracker-pull-issue.sh does not support the 'local' backend." >&2
    echo "       Local issues live at .foundry/issues/ — create them directly with" >&2
    echo "       the local adapter or via /foundry-board." >&2
    exit 1
    ;;
  *)
    echo "ERROR: unknown tracker backend '$BACKEND' (expected linear|github|local)" >&2
    exit 1
    ;;
esac

if ! tracker_init >/dev/null 2>&1; then
  echo "ERROR: tracker_init failed (HALT-on-connector-failure) — see adapter output above" >&2
  exit 1
fi

export TRACKER_PULL_DRY_RUN="$DRY_RUN"
export TRACKER_PULL_FOUNDRY_DIR="$FOUNDRY_DIR"

if [[ "$DRY_RUN" == "1" ]]; then
  echo "[DRY-RUN] backend=$BACKEND identifier=$IDENTIFIER"
fi

# Dispatch on backend
case "$BACKEND" in
  linear) _pull_linear "$IDENTIFIER" ;;
  github) _pull_github "$IDENTIFIER" ;;
esac

# ──────────────────────────────────────────────────────────────────────────────
# Linear pull: HAC-N → UUID → fetch via tracker_get_issue → write story
# ──────────────────────────────────────────────────────────────────────────────
_pull_linear() {
  local ident="$1"

  # Read LINEAR_TEAM_ID + LINEAR_API_KEY (still required for the HAC-N → UUID
  # resolution step that lives outside the adapter's get_issue contract).
  local linear_team_id
  linear_team_id="${LINEAR_TEAM_ID:-$(awk '
    /^tracker:/{ in_t=1 }
    in_t && /^[^[:space:]]/ && !/^tracker:/{ in_t=0 }
    in_t && /^[[:space:]]+linear:/{ in_l=1 }
    in_l && /^[[:space:]]+team_id:[ \t]/ {
      val=$2
      gsub(/["\\]/, "", val)
      print val
      exit
    }
  ' "$STATE_FILE" 2>/dev/null)}"
  LINEAR_API_KEY="${LINEAR_API_KEY:-}"

  if [[ -z "$linear_team_id" || -z "$LINEAR_API_KEY" ]]; then
    echo "ERROR: state.md tracker.linear.team_id and \$LINEAR_API_KEY must be set for the linear backend" >&2
    exit 1
  fi

  # Resolve identifier (HAC-42) → UUID via GraphQL
  local issue_json
  issue_json=$(curl -sS -X POST \
    -H "Authorization: $LINEAR_API_KEY" \
    -H "Content-Type: application/json" \
    https://api.linear.app/graphql \
    -d "$(jq -n --arg id "$ident" --arg team "$linear_team_id" \
        '{query: "query($id: String!, $team: String!) { issues(filter: {identifier: {eq: $id}, team: {id: {eq: $team}}}) { nodes { id identifier title description url state { name } priority estimate dueDate labels { nodes { name } } parent { identifier } } } }", variables: {id: $id, team: $team}}')" \
    | jq -r '.data.issues.nodes[0] // empty')
  if [[ -z "$issue_json" || "$issue_json" == "null" ]]; then
    echo "ERROR: Linear issue $ident not found in team $linear_team_id" >&2
    exit 1
  fi

  local issue_uuid issue_id issue_title issue_description issue_url issue_state issue_priority issue_parent
  issue_uuid=$(echo "$issue_json" | jq -r '.id')
  issue_id=$(echo "$issue_json" | jq -r '.identifier')
  issue_title=$(echo "$issue_json" | jq -r '.title')
  issue_description=$(echo "$issue_json" | jq -r '.description // ""')
  issue_url=$(echo "$issue_json" | jq -r '.url')
  issue_state=$(echo "$issue_json" | jq -r '.state.name')
  issue_priority=$(echo "$issue_json" | jq -r '.priority // null')
  issue_parent=$(echo "$issue_json" | jq -r '.parent.identifier // ""')

  echo "  identifier:  $issue_id"
  echo "  title:       $issue_title"
  echo "  state:       $issue_state"
  echo "  url:         $issue_url"
  echo "  parent:      ${issue_parent:-<none>}"

  # Map Linear identifier → STORY-NNN file (1:1, keeps the public id readable)
  local sid="$issue_id"

  # Priority: Linear priority 1=urgent..4=low → foundry P1..P4
  local priority_label="P${issue_priority:-3}"

  # Set env vars for shared helper
  export TRACKER_PULL_SID="$sid"
  export TRACKER_PULL_TITLE="$issue_title"
  export TRACKER_PULL_BODY="$issue_description"
  export TRACKER_PULL_IMPORTED_FROM="linear"
  export TRACKER_PULL_TRACKER_ID_FIELD="linear_issue_id"
  export TRACKER_PULL_TRACKER_ID_VALUE="$issue_id"
  export TRACKER_PULL_TRACKER_ID2_FIELD="linear_issue_uuid"
  export TRACKER_PULL_TRACKER_ID2_VALUE="$issue_uuid"
  export TRACKER_PULL_TRACKER_URL="$issue_url"
  export TRACKER_PULL_TRACKER_HUMAN_ID="$issue_id"
  export TRACKER_PULL_PRIORITY="$priority_label"
  export TRACKER_PULL_STATE="$issue_state"
  if [[ -n "$issue_parent" ]]; then
    export TRACKER_PULL_PARENT_FEATURE="$issue_parent"
  fi

  tracker_pull_write_story_file
  tracker_pull_add_to_board

  # (3) Set current_phase=execute + advance to ## In progress (in_progress status)
  if [[ "$DRY_RUN" == "0" && -f "$FOUNDRY_DIR/plan/board.md" ]]; then
    local board_file="$FOUNDRY_DIR/plan/board.md"
    # If SID already in any section, leave it; else add to In progress
    if ! grep -qE "(^|[^A-Za-z0-9_-])${sid}([^A-Za-z0-9_-]|$)" "$board_file"; then
      local tmp
      tmp="$(mktemp)"
      awk -v sid="$sid" -v title="$issue_title" '
        /^## In progress/ { in_ip=1; print; next }
        in_ip && /^$/ { print "- [ ] " sid " — " title; in_ip=0; print; next }
        { print }
      ' "$board_file" > "$tmp" && mv "$tmp" "$board_file"
      echo "  ✓ added $sid to ## In progress in board.md"
    fi
  fi

  tracker_pull_advance_phase

  # (4) (Optional) Flip the Linear issue to "In Progress" so the PO sees it
  if [[ "$MARK_IN_PROGRESS" == "1" && "$DRY_RUN" == "0" ]]; then
    if [[ -n "$issue_uuid" ]]; then
      if tracker_update_status "$issue_uuid" "in_progress" >/dev/null 2>&1; then
        echo "  ✓ flipped Linear issue to In Progress"
      else
        echo "  (couldn't flip Linear status — non-blocking; carry on)"
      fi
    fi
  fi

  echo ""
  echo "✓ Pulled $issue_id into local plan. Next step: /foundry-execute (or /foundry-loop-on)"
  echo "  Story file: $STORIES_DIR/${sid}.md"
}

# ──────────────────────────────────────────────────────────────────────────────
# GitHub pull: 42 / #42 / full URL → fetch via _tracker_github_api → write story
# ──────────────────────────────────────────────────────────────────────────────
_pull_github() {
  local ident="$1"

  # Strip URL prefix / leading '#' to get a bare issue number.
  # Accepts: 42 | #42 | owner/repo#42 | https://github.com/owner/repo/issues/42
  local num="$ident"
  num="${num#\#}"                                # strip leading #
  num="${num##*/issues/}"                        # strip URL prefix
  num="${num##*/}"                               # in case of trailing path
  num="${num%\#*}"                               # strip trailing #fragment

  if ! [[ "$num" =~ ^[0-9]+$ ]]; then
    echo "ERROR: GitHub issue identifier must be a number, '#N', or full URL (got '$ident')" >&2
    exit 2
  fi

  # Fetch issue via the GitHub adapter's API helper.
  local issue_json
  if ! issue_json="$(_tracker_github_api GET "issues/$num" 2>/dev/null)"; then
    echo "ERROR: failed to fetch GitHub issue #$num (network or auth error)" >&2
    exit 1
  fi

  local title body state url labels
  title=$(echo "$issue_json" | jq -r '.title // empty')
  body=$(echo "$issue_json" | jq -r '.body // ""')
  state=$(echo "$issue_json" | jq -r '.state // "open"')
  url=$(echo "$issue_json" | jq -r '.html_url // empty')
  labels=$(echo "$issue_json" | jq -r '[.labels // [] | .[].name] | join(",")')

  if [[ -z "$title" ]]; then
    echo "ERROR: GitHub issue #$num not found in $GITHUB_REPO (or empty response)" >&2
    exit 1
  fi

  echo "  identifier:  #${num}"
  echo "  title:       $title"
  echo "  state:       $state"
  echo "  url:         $url"
  echo "  labels:      ${labels:-<none>}"

  # Local SID = STORY-<issue_number> for 1:1 traceability.
  local sid="STORY-${num}"

  # Priority inference: P0 if `priority: urgent` label, P1 if `priority: high`,
  # P2 default. (Linear-style priority is not native to GitHub.)
  local priority_label="P2"
  if [[ ",$labels," == *",priority: urgent,"* || ",$labels," == *",P0,"* ]]; then
    priority_label="P0"
  elif [[ ",$labels," == *",priority: high,"* || ",$labels," == *",P1,"* ]]; then
    priority_label="P1"
  elif [[ ",$labels," == *",priority: low,"* || ",$labels," == *",P3,"* ]]; then
    priority_label="P3"
  fi

  # Set env vars for shared helper
  export TRACKER_PULL_SID="$sid"
  export TRACKER_PULL_TITLE="$title"
  export TRACKER_PULL_BODY="$body"
  export TRACKER_PULL_IMPORTED_FROM="github"
  export TRACKER_PULL_TRACKER_ID_FIELD="github_issue_id"
  export TRACKER_PULL_TRACKER_ID_VALUE="$num"
  export TRACKER_PULL_TRACKER_URL="$url"
  export TRACKER_PULL_TRACKER_HUMAN_ID="#${num}"
  export TRACKER_PULL_PRIORITY="$priority_label"
  export TRACKER_PULL_STATE="$state"

  tracker_pull_write_story_file
  tracker_pull_add_to_board

  # Move to ## In progress (in_progress status)
  if [[ "$DRY_RUN" == "0" && -f "$FOUNDRY_DIR/plan/board.md" ]]; then
    local board_file="$FOUNDRY_DIR/plan/board.md"
    if ! grep -qE "(^|[^A-Za-z0-9_-])${sid}([^A-Za-z0-9_-]|$)" "$board_file"; then
      local tmp
      tmp="$(mktemp)"
      awk -v sid="$sid" -v title="$title" '
        /^## In progress/ { in_ip=1; print; next }
        in_ip && /^$/ { print "- [ ] " sid " — " title; in_ip=0; print; next }
        { print }
      ' "$board_file" > "$tmp" && mv "$tmp" "$board_file"
      echo "  ✓ added $sid to ## In progress in board.md"
    fi
  fi

  tracker_pull_advance_phase

  # (Optional) Flip the GH issue to "In Progress" via the adapter
  if [[ "$MARK_IN_PROGRESS" == "1" && "$DRY_RUN" == "0" ]]; then
    if tracker_update_status "$num" "in_progress" >/dev/null 2>&1; then
      echo "  ✓ flipped GitHub issue to in_progress"
    else
      echo "  (couldn't flip GitHub status — non-blocking; carry on)"
    fi
  fi

  echo ""
  echo "✓ Pulled #${num} into local plan. Next step: /foundry-execute (or /foundry-loop-on)"
  echo "  Story file: $STORIES_DIR/${sid}.md"
}