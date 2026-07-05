#!/usr/bin/env bash
# foundry-tracker-writeback.sh — Write status + summary comment back to the
# configured tracker (Linear/GitHub) for a single foundry story.
#
# Usage:
#   foundry-tracker-writeback.sh <SID> --status=<status> --summary=<text>
#                                  [--commit=<sha7>] [--pr=<url>] [--tests=<X/Y>]
#                                  [--status-label=<name>]              # custom label override (e.g. "In QA")
#                                  [--linear-state-name="Done"]         # linear-only override
#                                  [--dry-run]
#
# Examples:
#   foundry-tracker-writeback.sh HAC-42 --status=done \
#     --summary="Implemented red→green→refactor with full coverage. PR #17 opened." \
#     --commit=abc1234 --pr=https://github.com/me/repo/pull/17
#
#   foundry-tracker-writeback.sh HAC-42 --status=blocked \
#     --summary="Blocked: missing API credentials; routed NEW-007 to /foundry-plan"
#
#   foundry-tracker-writeback.sh STORY-42 --status=done --pr=...  # GitHub
#
# What it does:
#   1. Reads .foundry/plan/stories/<SID>.md frontmatter
#   2. Looks up the canonical tracker id:
#        - linear:  linear_issue_id (HAC-N) + linear_issue_uuid
#        - github:  github_issue_id (number)
#   3. Calls tracker_update_status to flip the issue to the corresponding status
#   4. Posts a comment via tracker_add_comment with the summary + commit + PR + tests
#
# Backend is auto-detected from .foundry/state.md `tracker.backend`. Defaults
# to `local` if unset (in which case this script is a no-op + warning).

set -uo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
PROJECT_ROOT="${DEV_PIPELINE_PROJECT_ROOT:-$(pwd)}"
FOUNDRY_DIR="${FOUNDRY_DIR:-$PROJECT_ROOT/.foundry}"
STORIES_DIR="${STORIES_DIR:-$FOUNDRY_DIR/plan/stories}"
TRACKER_ADAPTERS_DIR="$PLUGIN_ROOT/tracker-adapters"

# Source tracker adapter interface (provides tracker_autodetect)
if [[ ! -f "$TRACKER_ADAPTERS_DIR/interface.sh" ]]; then
  echo "ERROR: can't find tracker-adapters/interface.sh at $TRACKER_ADAPTERS_DIR" >&2
  exit 1
fi
# shellcheck disable=SC1091
source "$TRACKER_ADAPTERS_DIR/interface.sh"

tracker_autodetect
BACKEND="${TRACKER_ADAPTER:-local}"

# Parse args
SID=""
STATUS=""
SUMMARY=""
COMMIT=""
PR_URL=""
TESTS=""
LINEAR_STATE_NAME=""
STATUS_LABEL=""
DRY_RUN=0
for arg in "$@"; do
  case "$arg" in
    --status=*)          STATUS="${arg#--status=}" ;;
    --summary=*)         SUMMARY="${arg#--summary=}" ;;
    --commit=*)          COMMIT="${arg#--commit=}" ;;
    --pr=*)              PR_URL="${arg#--pr=}" ;;
    --tests=*)           TESTS="${arg#--tests=}" ;;
    --linear-state-name=*) LINEAR_STATE_NAME="${arg#--linear-state-name=}" ;;
    --status-label=*)    STATUS_LABEL="${arg#--status-label=}" ;;
    --dry-run)           DRY_RUN=1 ;;
    -h|--help)
      cat <<'EOF'
usage: foundry-tracker-writeback.sh <SID> --status=<done|blocked|in_progress|ready|review> --summary=<text> [flags]

Flags:
  --status=<status>             done | blocked | in_progress | ready | review (required)
  --summary=<text>              multi-line summary (required; first line = title, rest = body)
  --commit=<sha7>               commit hash (optional, added to comment)
  --pr=<url>                    PR/MR URL (optional, added to comment)
  --tests=<X/Y>                 test results (optional, added to comment)
  --status-label=<name>         backend-generic label override (rare; defaults to foundry:* mapping)
  --linear-state-name=<name>    linear-only state name override (rare; for teams with non-canonical workflow)
  --dry-run                     preview only

Reads story frontmatter from .foundry/plan/stories/<SID>.md. Posts a comment + flips the issue status.
Backend is auto-detected from .foundry/state.md `tracker.backend`.

Examples:
  foundry-tracker-writeback.sh HAC-42 --status=done --summary="..."      # Linear
  foundry-tracker-writeback.sh STORY-42 --status=done --summary="..."   # GitHub
  foundry-tracker-writeback.sh HAC-42 --status=blocked --summary="Waiting on API key"
EOF
      exit 0 ;;
    *)
      if [[ -z "$SID" ]]; then SID="$arg"
      else echo "ERROR: unexpected arg '$arg'" >&2; exit 2
      fi
      ;;
  esac
done

if [[ -z "$SID" ]]; then
  echo "usage: foundry-tracker-writeback.sh <SID> --status=<...> --summary=<...>" >&2
  exit 2
fi

if [[ -z "$STATUS" || -z "$SUMMARY" ]]; then
  echo "ERROR: --status and --summary are required" >&2
  exit 2
fi

# Validate status (canonical set)
case "$STATUS" in
  ready|in_progress|review|done|blocked) ;;
  *) echo "ERROR: invalid --status '$STATUS' (must be ready|in_progress|review|done|blocked)" >&2; exit 2 ;;
esac

# Source backend-specific adapter
case "$BACKEND" in
  linear) source "$TRACKER_ADAPTERS_DIR/linear/adapter.sh" ;;
  github) source "$TRACKER_ADAPTERS_DIR/github/adapter.sh" ;;
  local)
    echo "  (tracker backend is 'local' — writeback is a no-op for local issues)"
    exit 0
    ;;
  *)
    echo "ERROR: unknown tracker backend '$BACKEND'" >&2
    exit 1
    ;;
esac

# Initialise the adapter (reads repo/team from state.md)
if ! tracker_init >/dev/null 2>&1; then
  echo "ERROR: tracker_init failed (HALT-on-connector-failure) — see adapter output above" >&2
  exit 1
fi

# ──────────────────────────────────────────────────────────────────────────────
# 1. Read story frontmatter for cached tracker id
# ──────────────────────────────────────────────────────────────────────────────

STORY_FILE="$STORIES_DIR/${SID}.md"
if [[ ! -f "$STORY_FILE" ]]; then
  echo "ERROR: no story file at $STORY_FILE" >&2
  exit 1
fi

# Backend-specific tracker id extraction
TRACKER_ID=""
TRACKER_URL=""
case "$BACKEND" in
  linear)
    TRACKER_ID=$(awk -F': ' '/^linear_issue_id:/{gsub(/[ "]/, "", $2); print $2; exit}' "$STORY_FILE")
    LINEAR_UUID=$(awk -F': ' '/^linear_issue_uuid:/{gsub(/[ "]/, "", $2); print $2; exit}' "$STORY_FILE")
    TRACKER_URL=$(awk -F': ' '/^linear_url:/{gsub(/[ "]/, "", $2); print $2; exit}' "$STORY_FILE")
    if [[ -z "$TRACKER_ID" ]]; then
      echo "ERROR: story $SID has no linear_issue_id in frontmatter — was it imported via foundry-tracker-pull-issue?" >&2
      exit 1
    fi
    ;;
  github)
    TRACKER_ID=$(awk -F': ' '/^github_issue_id:/{gsub(/[ "]/, "", $2); print $2; exit}' "$STORY_FILE")
    TRACKER_URL=$(awk -F': ' '/^github_url:/{gsub(/[ "]/, "", $2); print $2; exit}' "$STORY_FILE")
    if [[ -z "$TRACKER_ID" ]]; then
      echo "ERROR: story $SID has no github_issue_id in frontmatter — was it imported via foundry-tracker-pull-issue?" >&2
      exit 1
    fi
    ;;
esac

# ──────────────────────────────────────────────────────────────────────────────
# 2. Build the comment body
# ──────────────────────────────────────────────────────────────────────────────

COMMENT_BODY="$SUMMARY"
[[ -n "$COMMIT" ]] && COMMENT_BODY+=$'\n\nCommit: `'"$COMMIT"'`'
[[ -n "$PR_URL" ]] && COMMENT_BODY+=$'\nPR: '"$PR_URL"
[[ -n "$TESTS" ]] && COMMENT_BODY+=$'\nTests: '"$TESTS"
COMMENT_BODY+=$'\n\nFoundry dev+QA loop · '"$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# ──────────────────────────────────────────────────────────────────────────────
# 3. Status / state-name mapping (per backend)
# ──────────────────────────────────────────────────────────────────────────────

case "$BACKEND" in
  linear)
    # Map foundry canonical status → Linear workflow state name
    # Custom state names can be overridden per team via --linear-state-name.
    case "$STATUS" in
      ready)       LINEAR_STATE_NAME="${LINEAR_STATE_NAME:-Todo}" ;;
      in_progress) LINEAR_STATE_NAME="${LINEAR_STATE_NAME:-In Progress}" ;;
      review)      LINEAR_STATE_NAME="${LINEAR_STATE_NAME:-In Review}" ;;
      done)        LINEAR_STATE_NAME="${LINEAR_STATE_NAME:-Done}" ;;
      blocked)     LINEAR_STATE_NAME="${LINEAR_STATE_NAME:-Blocked}" ;;
    esac
    ;;
  github)
    # GitHub doesn't have workflow states; the adapter maps canonical status
    # to a foundry:<status> label. --status-label overrides that label.
    # No-op here — the adapter's tracker_update_status handles it.
    ;;
esac

# ──────────────────────────────────────────────────────────────────────────────
# 4. Execute
# ──────────────────────────────────────────────────────────────────────────────

if [[ "$DRY_RUN" == "1" ]]; then
  echo "[DRY-RUN] would write back to $TRACKER_ID ($TRACKER_URL)"
  if [[ "$BACKEND" == "linear" ]]; then
    echo "  status:    $LINEAR_STATE_NAME"
  else
    echo "  status:    $STATUS (mapped to foundry:$STATUS${STATUS_LABEL:+ [override: $STATUS_LABEL]})"
  fi
  echo "  comment:   ${COMMENT_BODY:0:120}..."
  exit 0
fi

echo "Writing back to $BACKEND issue $TRACKER_ID..."

# Update status (the adapter handles the backend-specific call).
# Pass the canonical STATUS to tracker_update_status; the adapter maps to its
# backend's representation (state UUID for Linear, label for GitHub).
if tracker_update_status "$TRACKER_ID" "$STATUS" >/dev/null 2>&1; then
  if [[ "$BACKEND" == "linear" ]]; then
    echo "  ✓ status → $LINEAR_STATE_NAME"
  else
    echo "  ✓ status → foundry:$STATUS"
  fi
else
  echo "  ⚠ couldn't update status — non-blocking" >&2
fi

# Post the summary comment.
if tracker_add_comment "$TRACKER_ID" "$COMMENT_BODY" >/dev/null 2>&1; then
  echo "  ✓ comment posted"
else
  echo "  ⚠ couldn't post comment — non-blocking" >&2
fi

echo ""
echo "✓ Wrote back to $TRACKER_ID ($TRACKER_URL)"