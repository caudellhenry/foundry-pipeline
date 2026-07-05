#!/usr/bin/env bash
# foundry-post-merge.sh — Clean up after a PR merges: close the GitHub issue,
# delete the feature branch (local + remote), and update the local state.
#
# Usage:
#   foundry-post-merge.sh <SID> [<PR_URL>]    # SID like STORY-42 or HAC-42
#   foundry-post-merge.sh <SID> --dry-run
#
# What it does:
#   1. Reads .foundry/plan/stories/<SID>.md frontmatter for the GH issue id
#   2. Confirms the PR is merged (gh pr view --json state,mergedAt)
#   3. Posts a comment on the GH issue: "✅ Merged via PR #<N>. Closing."
#   4. Closes the GH issue (state=closed + foundry:done label)
#   5. Deletes the local + remote feature branch
#   6. Marks the operation as done in .foundry/post-merge/<SID>.done (idempotent)
#
# Idempotent: re-running on an already-merged ticket is a no-op.

set -uo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
PROJECT_ROOT="${DEV_PIPELINE_PROJECT_ROOT:-$(pwd)}"
FOUNDRY_DIR="$PROJECT_ROOT/.foundry"
STATE_FILE="$FOUNDRY_DIR/state.md"
STORIES_DIR="$FOUNDRY_DIR/plan/stories"
TRACKER_ADAPTERS_DIR="$PLUGIN_ROOT/tracker-adapters"
POST_MERGE_DIR="$FOUNDRY_DIR/post-merge"

# Source tracker adapter interface (provides tracker_autodetect)
if [[ ! -f "$TRACKER_ADAPTERS_DIR/interface.sh" ]]; then
  echo "ERROR: can't find tracker-adapters/interface.sh at $TRACKER_ADAPTERS_DIR" >&2
  exit 1
fi
# shellcheck disable=SC1091
source "$TRACKER_ADAPTERS_DIR/interface.sh"

# ──────────────────────────────────────────────────────────────────────────────
# Parse args
# ──────────────────────────────────────────────────────────────────────────────

SID=""
PR_URL=""
DRY_RUN=0
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    -h|--help)
      cat <<'EOF'
usage: foundry-post-merge.sh <SID> [<PR_URL>] [--dry-run]

Post-merge cleanup: close the GitHub issue, delete the feature branch.
Idempotent — re-running is a no-op via the .foundry/post-merge/<SID>.done marker.

SID: STORY-42 (github) or HAC-42 (linear). For github, the GH issue id is
     read from the story frontmatter (github_issue_id). The PR URL is optional;
     if omitted, it's read from .foundry/state.md phases.execute.prs.<SID>.

Examples:
  foundry-post-merge.sh STORY-42
  foundry-post-merge.sh STORY-42 https://github.com/me/repo/pull/42
  foundry-post-merge.sh STORY-42 --dry-run
EOF
      exit 0 ;;
    *)
      if [[ -z "$SID" ]]; then SID="$arg"
      elif [[ -z "$PR_URL" ]]; then PR_URL="$arg"
      else echo "ERROR: unexpected arg '$arg'" >&2; exit 2
      fi
      ;;
  esac
done

if [[ -z "$SID" ]]; then
  echo "usage: foundry-post-merge.sh <SID> [<PR_URL>] [--dry-run]" >&2
  exit 2
fi

mkdir -p "$POST_MERGE_DIR" 2>/dev/null || true

# Dedupe: if already post-merged, skip.
if [[ -f "$POST_MERGE_DIR/$SID.done" ]]; then
  echo "  (already post-merged — skipping; remove $POST_MERGE_DIR/$SID.done to redo)"
  exit 0
fi

# ──────────────────────────────────────────────────────────────────────────────
# Read story frontmatter
# ──────────────────────────────────────────────────────────────────────────────

STORY_FILE="$STORIES_DIR/${SID}.md"
if [[ ! -f "$STORY_FILE" ]]; then
  echo "ERROR: no story file at $STORY_FILE" >&2
  exit 1
fi

# Branch name from frontmatter (default: feat/<SID>)
BRANCH=$(awk -F': ' '/^branch:/{gsub(/[ "]/, "", $2); print $2; exit}' "$STORY_FILE")
BRANCH="${BRANCH:-feat/$SID}"

# GH issue id from frontmatter (when tracker.backend: github)
GITHUB_ISSUE_ID=$(awk -F': ' '/^github_issue_id:/{gsub(/[ "]/, "", $2); print $2; exit}' "$STORY_FILE")
GITHUB_URL=$(awk -F': ' '/^github_url:/{gsub(/[ "]/, "", $2); print $2; exit}' "$STORY_FILE")

# If PR_URL not passed, try to read from state.md phases.execute.prs.<SID>
if [[ -z "$PR_URL" ]]; then
  PR_URL=$(awk -v sid="$SID" '
    /^[[:space:]]+prs:[[:space:]]*$/ { f=1; next }
    f && /^[[:space:]]+[a-z]/ && !/^[[:space:]]+[a-z][a-z]*-[a-z]/ { f=0 }
    f && /^[[:space:]]+[A-Z][A-Z]*-[0-9]+:/ {
      match($0, /[A-Z][A-Z]*-[0-9]+/)
      tid = substr($0, RSTART, RLENGTH)
      if (tid == sid) {
        sub(/^[[:space:]]*[A-Z][A-Z]*-[0-9]+:[[:space:]]*/, "")
        gsub(/[[:space:]]+$/, "")
        sub(/[[:space:]]+#.*$/, "")
        print
        exit
      }
    }
  ' "$STATE_FILE" 2>/dev/null)
fi

echo "Post-merge cleanup for $SID"
echo "  branch:    $BRANCH"
echo "  pr_url:    ${PR_URL:-<none>}"
echo "  gh_issue:  ${GITHUB_ISSUE_ID:-<none>} ($GITHUB_URL)"

# ──────────────────────────────────────────────────────────────────────────────
# Confirm PR is merged (best-effort)
# ──────────────────────────────────────────────────────────────────────────────

PR_IS_MERGED="unknown"
if [[ -n "$PR_URL" ]] && command -v gh >/dev/null 2>&1; then
  if PR_STATE_JSON=$(gh pr view "$PR_URL" --json state,mergedAt 2>/dev/null); then
    PR_IS_MERGED=$(echo "$PR_STATE_JSON" | jq -r 'if .mergedAt != null and .mergedAt != "" then "true" else "false" end')
  fi
fi
echo "  pr_merged: $PR_IS_MERGED"

# Refuse to proceed if the PR is explicitly NOT merged (closed-but-unmerged)
if [[ "$PR_IS_MERGED" == "false" ]]; then
  echo "ERROR: PR $PR_URL is closed but not merged. Refusing to close the GH issue or delete the branch." >&2
  echo "       If the PR was abandoned, manually close the issue and clean up the branch." >&2
  exit 1
fi

# ──────────────────────────────────────────────────────────────────────────────
# Dispatch: GitHub backend — close the GH issue
# ──────────────────────────────────────────────────────────────────────────────

if [[ -n "$GITHUB_ISSUE_ID" ]]; then
  tracker_autodetect
  BACKEND="${TRACKER_ADAPTER:-local}"
  if [[ "$BACKEND" == "github" ]] || [[ -n "$GITHUB_ISSUE_ID" ]]; then
    # Source github adapter for close-issue + comment.
    # shellcheck disable=SC1091
    source "$TRACKER_ADAPTERS_DIR/github/adapter.sh"
    if ! tracker_init >/dev/null 2>&1; then
      echo "ERROR: GitHub tracker init failed (HALT-on-connector-failure)" >&2
      exit 1
    fi

    if [[ "$DRY_RUN" == "0" ]]; then
      # Post a comment first (so the audit trail is preserved even if close fails).
      if [[ -n "$PR_URL" ]]; then
        COMMENT="✅ Merged via PR $PR_URL. Closing this issue and cleaning up the branch."
        if tracker_add_comment "$GITHUB_ISSUE_ID" "$COMMENT" >/dev/null 2>&1; then
          echo "  ✓ comment posted on #$GITHUB_ISSUE_ID"
        else
          echo "  ⚠ couldn't post comment — non-blocking" >&2
        fi
      fi

      # Flip status to done + close (adapter does both).
      if tracker_update_status "$GITHUB_ISSUE_ID" "done" >/dev/null 2>&1; then
        echo "  ✓ GH issue #$GITHUB_ISSUE_ID → done (closed)"
      else
        echo "  ⚠ couldn't update GH issue status — non-blocking" >&2
      fi
    else
      echo "  [DRY-RUN] would comment on #$GITHUB_ISSUE_ID"
      echo "  [DRY-RUN] would close #$GITHUB_ISSUE_ID (state=closed, label=foundry:done)"
    fi
  fi
fi

# ──────────────────────────────────────────────────────────────────────────────
# Delete the feature branch (local + remote)
# ──────────────────────────────────────────────────────────────────────────────

if [[ "$DRY_RUN" == "0" ]]; then
  # Don't delete the default branch by accident.
  case "$BRANCH" in
    main|master|develop|trunk) echo "  ⚠ refusing to delete '$BRANCH' (looks like a default branch)"; BRANCH="" ;;
  esac

  if [[ -n "$BRANCH" ]]; then
    # Local delete: tolerate missing branches (-D forces, --quiet suppresses noise).
    if git -C "$PROJECT_ROOT" rev-parse --verify "$BRANCH" >/dev/null 2>&1; then
      git -C "$PROJECT_ROOT" branch -d "$BRANCH" 2>/dev/null || git -C "$PROJECT_ROOT" branch -D "$BRANCH"
      echo "  ✓ deleted local branch $BRANCH"
    else
      echo "  (local branch $BRANCH not present — skipping)"
    fi

    # Remote delete: only if a remote exists AND the branch is there.
    if git -C "$PROJECT_ROOT" ls-remote --heads origin "$BRANCH" 2>/dev/null | grep -q "$BRANCH"; then
      if git -C "$PROJECT_ROOT" push origin --delete "$BRANCH" 2>/dev/null; then
        echo "  ✓ deleted remote branch origin/$BRANCH"
      else
        echo "  ⚠ couldn't delete remote branch — non-blocking" >&2
      fi
    fi
  fi

  # Mark done (idempotency marker)
  touch "$POST_MERGE_DIR/$SID.done"
fi

echo ""
echo "✓ Post-merge complete for $SID"