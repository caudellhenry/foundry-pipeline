#!/usr/bin/env bash
# foundry-spawn-implementer.sh — Build the Agent-tool prompt for the foundry-implementer sub-agent
#
# usage:
#   foundry-spawn-implementer.sh <TICKET> [$(/Users/henrycaudell/Agents Workspace/Skills/foundry/scripts/foundry-worktree.sh path $TICKET)]
#
# Emits a complete prompt body to stdout, ready to pass as the Agent tool's
# `prompt` parameter with profileId="Explore" or "general-purpose" (per role).

set -euo pipefail

TICKET="${1:-}"
WORKTREE_PATH="${2:-}"

if [[ -z "$TICKET" ]]; then
  echo "usage: foundry-spawn-implementer.sh <TICKET> [WORKTREE_PATH]" >&2
  exit 2
fi

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
PROJECT_ROOT="${DEV_PIPELINE_PROJECT_ROOT:-$(pwd)}"
DEV_DIR="$PROJECT_ROOT/.foundry"
STATE_FILE="$DEV_DIR/state.md"

ROLE_FILE="$PLUGIN_ROOT/agents/foundry-implementer.md"
STORY_FILE="$DEV_DIR/plan/stories/$TICKET.md"
TDD_FILE="$DEV_DIR/tdd/$TICKET.md"
EVIDENCE_FILE="$DEV_DIR/qa/evidence/$TICKET.md"

# Override paths if worktree is in use
if [[ -n "$WORKTREE_PATH" ]]; then
  WORKTREE_DEV_DIR="$WORKTREE_PATH/.foundry"
  TDD_FILE="$WORKTREE_DEV_DIR/tdd/$TICKET.md"
  EVIDENCE_FILE="$WORKTREE_DEV_DIR/qa/evidence/$TICKET.md"
fi

# Read state.md values
read_state() {
  local key="$1"
  awk -v k="^  $key:" '$0 ~ k { sub(k "[[:space:]]*", ""); gsub(/^"|"$/, ""); print; exit }' "$STATE_FILE"
}

TEST_CMD=$(read_state cmd)
TEST_TIMEOUT=$(read_state timeout)
TEST_TIMEOUT="${TEST_TIMEOUT:-300}"
WRITER_MODEL=$(read_state writer)
WRITER_MODEL="${WRITER_MODEL:-sonnet}"

# Read story frontmatter fields
read_story() {
  local key="$1"
  awk -v k="^  $key:" '$0 ~ k { sub(k "[[:space:]]*", ""); gsub(/^"|"$/, ""); print; exit }' "$STORY_FILE"
}

TEST_PATH=$(read_story test_path)
COVERAGE_TARGET=$(read_story coverage_target)
REVIEWER_REQUIRED=$(read_story reviewer_required)
REVIEWER_REQUIRED="${REVIEWER_REQUIRED:-true}"

BRANCH="feat/$TICKET"

cat <<EOF
==========================================
ROLE: foundry-implementer (model=$WRITER_MODEL)
==========================================

$(cat "$ROLE_FILE")

==========================================
PER-TICKET PAYLOAD
==========================================

TICKET: $TICKET
PROJECT_ROOT: ${WORKTREE_PATH:-$PROJECT_ROOT}
DEV_DIR: ${WORKTREE_PATH:+$WORKTREE_PATH/.foundry}
STATE_FILE: $STATE_FILE
STORY_FILE: $STORY_FILE
TDD_SPEC: $TDD_FILE
EVIDENCE_FILE: $EVIDENCE_FILE
TEST_PATH: ${TEST_PATH:-<none — run full suite>}
COVERAGE_TARGET: ${COVERAGE_TARGET:-<inherit from state.md>}
REVIEWER_REQUIRED: $REVIEWER_REQUIRED
BRANCH: $BRANCH
TEST_CMD: $TEST_CMD
TEST_TIMEOUT: ${TEST_TIMEOUT}s
WRITER_MODEL: $WRITER_MODEL
ITERATIONS: $(read_story iterations)
ITERATIONS=${ITERATIONS:-0}
${WORKTREE_PATH:+
⚠ WORKTREE MODE: Your working directory is $WORKTREE_PATH (a sibling worktree on branch $BRANCH).
  - All file edits, commits, and test runs happen INSIDE the worktree path above.
  - PROJECT_ROOT for shell commands = $WORKTREE_PATH
  - The orchestrator will merge feat/$TICKET back to main after you succeed.
  - Do NOT touch $PROJECT_ROOT (the parent); that's where state lives.
}

Begin. Read STORY_FILE and TDD_SPEC, then execute the role prompt above.
EOF
