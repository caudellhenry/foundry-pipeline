#!/usr/bin/env bash
# foundry-worktree.sh — per-ticket git worktree management
#
# Implements FR-20260704-008 (worktree-per-ticket isolation). Each writer
# sub-agent operates in its own worktree so that:
#   - in-progress tickets can't clobber each other on shared files
#   - the orchestrator can spawn multiple writers in parallel (FR-20260704-009)
#   - each ticket's branch has a clean reviewable history independent of main
#   - failed tickets can be discarded without contaminating main
#
# usage:
#   foundry-worktree.sh create <TICKET>           # create worktree + branch
#   foundry-worktree.sh path <TICKET>             # echo absolute worktree path
#   foundry-worktree.sh exists <TICKET>           # exit 0 if exists, 1 otherwise
#   foundry-worktree.sh remove <TICKET>           # remove worktree + branch
#   foundry-worktree.sh merge <TICKET>            # merge feat/<TICKET> into current branch
#   foundry-worktree.sh list                      # list all <TICKET> worktrees
#   foundry-worktree.sh cleanup                   # remove all <TICKET> worktrees + branches
#   foundry-worktree.sh path-parent               # echo the parent directory of the worktrees
#
# Naming convention:
#   worktree path = <project_root>/../<project_basename>-<TICKET>
#   branch        = feat/<TICKET>
#
# Example:
#   /Users/foo/projects/myapp/.foundry/state.md
#   /Users/foo/projects/myapp-STORY-001/   <-- worktree
#       .git (file pointing to /Users/foo/projects/myapp/.git/worktrees/myapp-STORY-001)
#       src/, package.json, ...
#   on branch: feat/STORY-001

set -euo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
PROJECT_ROOT="${DEV_PIPELINE_PROJECT_ROOT:-$(pwd)}"
FOUNDRY_DIR="$PROJECT_ROOT/.foundry"
STATE_FILE="$FOUNDRY_DIR/state.md"

cmd="${1:-help}"
shift || true

# Project basename (used for worktree directory naming)
PROJECT_BASENAME="$(basename "$PROJECT_ROOT")"
WORKTREE_PARENT="$(dirname "$PROJECT_ROOT")"
WORKTREE_PREFIX="${PROJECT_BASENAME}-STORY-"

worktree_path() {
  local ticket="$1"
  echo "${WORKTREE_PARENT}/${PROJECT_BASENAME}-${ticket}"
}

branch_name() {
  local ticket="$1"
  echo "feat/${ticket}"
}

# Read state.md worktree.enabled (default true if state.md missing)
worktree_enabled() {
  if [[ ! -f "$STATE_FILE" ]]; then echo "true"; return; fi
  local v
  v=$(awk -v k="^  enabled:" '
    /^worktree:/{flag=1; next}
    flag && /^  enabled:/{sub(k"[[:space:]]*",""); sub(/[[:space:]]*#.*$/,""); gsub(/[[:space:]]/,""); print; exit}
    flag && /^[^ ]/{exit}
  ' "$STATE_FILE" 2>/dev/null)
  echo "${v:-true}"
}

require_worktree_enabled() {
  if [[ "$(worktree_enabled)" != "true" ]]; then
    echo "ERROR: worktree mode is disabled in state.md (worktree.enabled: false). Enable it with: foundry-state.sh set-worktree enabled" >&2
    exit 2
  fi
}

require_git_repo() {
  if ! git -C "$PROJECT_ROOT" rev-parse --git-dir >/dev/null 2>&1; then
    echo "ERROR: $PROJECT_ROOT is not a git repo. Worktrees require git." >&2
    exit 2
  fi
}

wt_create() {
  local ticket="${1:-}"
  if [[ -z "$ticket" ]]; then echo "usage: foundry-worktree.sh create <TICKET>" >&2; exit 2; fi
  require_worktree_enabled
  require_git_repo
  local path branch
  path="$(worktree_path "$ticket")"
  branch="$(branch_name "$ticket")"
  if [[ -d "$path" ]]; then
    echo "EXISTS: $path"
    exit 0
  fi
  # Create the branch if it doesn't exist
  if ! git -C "$PROJECT_ROOT" rev-parse --verify "$branch" >/dev/null 2>&1; then
    git -C "$PROJECT_ROOT" branch "$branch" >/dev/null
  fi
  # Create the worktree
  git -C "$PROJECT_ROOT" worktree add "$path" "$branch"
  echo "$path"
}

wt_path() {
  local ticket="${1:-}"
  if [[ -z "$ticket" ]]; then echo "usage: foundry-worktree.sh path <TICKET>" >&2; exit 2; fi
  worktree_path "$ticket"
}

wt_exists() {
  local ticket="${1:-}"
  if [[ -z "$ticket" ]]; then echo "usage: foundry-worktree.sh exists <TICKET>" >&2; exit 2; fi
  local path
  path="$(worktree_path "$ticket")"
  if [[ -d "$path" ]]; then exit 0; else exit 1; fi
}

wt_remove() {
  local ticket="${1:-}"
  if [[ -z "$ticket" ]]; then echo "usage: foundry-worktree.sh remove <TICKET>" >&2; exit 2; fi
  local path branch
  path="$(worktree_path "$ticket")"
  branch="$(branch_name "$ticket")"
  if [[ ! -d "$path" ]]; then
    echo "NOT_FOUND: $path"
    return 0
  fi
  git -C "$PROJECT_ROOT" worktree remove --force "$path" 2>/dev/null || rm -rf "$path"
  # Delete the branch too (only if merged; use -d not -D to be safe)
  git -C "$PROJECT_ROOT" branch -d "$branch" 2>/dev/null || true
  echo "REMOVED: $path (and branch $branch)"
}

wt_merge() {
  local ticket="${1:-}"
  if [[ -z "$ticket" ]]; then echo "usage: foundry-worktree.sh merge <TICKET>" >&2; exit 2; fi
  require_git_repo
  local branch
  branch="$(branch_name "$ticket")"
  if ! git -C "$PROJECT_ROOT" rev-parse --verify "$branch" >/dev/null 2>&1; then
    echo "ERROR: branch $branch does not exist" >&2
    exit 1
  fi
  # Fast-forward merge if possible, else merge commit (--no-ff preserves ticket history)
  # Use -m so conflict resolution is straightforward
  if git -C "$PROJECT_ROOT" merge-base --is-ancestor "$branch" HEAD 2>/dev/null; then
    echo "ALREADY_MERGED: $branch"
    return 0
  fi
  if ! git -C "$PROJECT_ROOT" merge --no-ff "$branch" -m "merge: $branch" 2>&1; then
    echo "MERGE_CONFLICT: resolve manually with: git -C $PROJECT_ROOT status" >&2
    return 1
  fi
  echo "MERGED: $branch"
}

wt_list() {
  require_git_repo
  git -C "$PROJECT_ROOT" worktree list --porcelain | awk '
    /^worktree / { path = substr($0, 10) }
    /^branch / {
      br = substr($0, 8)
      sub(/^refs\/heads\//, "", br)
      # Only show our STORY-### worktrees
      if (path ~ /STORY-[0-9]+$/) {
        # Extract ticket id from path
        n = split(path, a, "-STORY-")
        ticket = "STORY-" a[n]
        printf "%s\t%s\t%s\n", ticket, path, br
      }
    }
  '
}

wt_cleanup() {
  require_git_repo
  local removed=0
  while IFS=$'\t' read -r ticket path br; do
    [[ -z "$ticket" ]] && continue
    wt_remove "$ticket" >/dev/null
    removed=$((removed + 1))
  done < <(wt_list)
  # Also prune any stale worktree metadata
  git -C "$PROJECT_ROOT" worktree prune
  echo "Cleanup complete ($removed worktrees removed)"
}

wt_path_parent() {
  echo "$WORKTREE_PARENT"
}

case "$cmd" in
  create)        wt_create "${1:-}" ;;
  path)          wt_path "${1:-}" ;;
  exists)        wt_exists "${1:-}" ;;
  remove)        wt_remove "${1:-}" ;;
  merge)         wt_merge "${1:-}" ;;
  list)          wt_list ;;
  cleanup)       wt_cleanup ;;
  path-parent)   wt_path_parent ;;
  help|*) cat <<'EOF'
foundry-worktree.sh — per-ticket git worktree management (FR-20260704-008)

usage:
  foundry-worktree.sh create <TICKET>         create worktree + feat/<TICKET> branch
  foundry-worktree.sh path <TICKET>           echo absolute worktree path
  foundry-worktree.sh exists <TICKET>         exit 0 if exists, 1 otherwise
  foundry-worktree.sh remove <TICKET>         remove worktree + delete branch
  foundry-worktree.sh merge <TICKET>          merge feat/<TICKET> into current branch (--no-ff)
  foundry-worktree.sh list                    list all STORY-### worktrees
  foundry-worktree.sh cleanup                 remove all STORY-### worktrees + prune metadata
  foundry-worktree.sh path-parent             echo the parent dir where worktrees live

Each ticket's worktree path = <project_basename>-<TICKET> in the parent directory.
Each ticket's branch = feat/<TICKET>.

State: read state.md worktree.enabled (default: true).
EOF
    ;;
esac