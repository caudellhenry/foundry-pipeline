#!/usr/bin/env bash
# foundry-spawn-writer.sh — Build the Agent-tool prompt for the writer sub-agent
#
# usage:
#   foundry-spawn-writer.sh <TICKET>
#
# Reads:
#   - agents/foundry-writer.md (the role prompt)
#   - .foundry/plan/stories/<TICKET>.md (story)
#   - .foundry/tdd/<TICKET>.md (TDD spec, if exists)
#   - .foundry/state.md (test config + models)
#   - .foundry/qa/evidence/<TICKET>.md (prior evidence, if exists)
#
# Emits a complete prompt body to stdout, ready to pass as `prompt` to the
# Agent tool with profileId="general-purpose".
#
# The orchestrator (skills/foundry-orchestrator) is responsible for the actual
# Agent tool invocation; this script just produces the prompt.

set -euo pipefail

TICKET="${1:-}"
shift || true

WORKTREE_PATH=""

for arg in "$@"; do
  case "$arg" in
    --worktree-path=*) WORKTREE_PATH="${arg#--worktree-path=}" ;;
  esac
done

if [[ -z "$TICKET" ]]; then
  echo "usage: foundry-spawn-writer.sh <TICKET> [--worktree-path=PATH]" >&2
  exit 2
fi

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
PROJECT_ROOT="${DEV_PIPELINE_PROJECT_ROOT:-$(pwd)}"
FOUNDRY_DIR="$PROJECT_ROOT/.foundry"
STATE_FILE="$FOUNDRY_DIR/state.md"

ROLE_FILE="$PLUGIN_ROOT/agents/foundry-writer.md"
STORY_FILE="$FOUNDRY_DIR/plan/stories/$TICKET.md"
TDD_FILE="$FOUNDRY_DIR/tdd/$TICKET.md"
EVIDENCE_FILE="$FOUNDRY_DIR/qa/evidence/$TICKET.md"

# If a worktree path is provided, all writes go inside the worktree
if [[ -n "$WORKTREE_PATH" ]]; then
  # The .foundry/ stays in the parent (canonical state location).
  # The worktree is just where the code changes live.
  WORKTREE_FOUNDRY_DIR="$WORKTREE_PATH/.foundry"
  TDD_FILE="$WORKTREE_FOUNDRY_DIR/tdd/$TICKET.md"
  EVIDENCE_FILE="$WORKTREE_FOUNDRY_DIR/qa/evidence/$TICKET.md"
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

# 1. Role prompt
echo "=========================================="
echo "ROLE: foundry-writer (model=$WRITER_MODEL)"
echo "=========================================="
echo ""
cat "$ROLE_FILE"
echo ""
echo "=========================================="
echo "PER-TICKET PAYLOAD"
echo "=========================================="
echo ""
cat <<EOF
TICKET: $TICKET
PROJECT_ROOT: ${WORKTREE_PATH:-$PROJECT_ROOT}
FOUNDRY_DIR: ${WORKTREE_PATH:+$WORKTREE_PATH/.foundry}
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
echo ""
echo "=========================================="
echo "STORY FILE CONTENT"
echo "=========================================="
echo ""
if [[ -f "$STORY_FILE" ]]; then
  cat "$STORY_FILE"
else
  echo "(missing — should not happen; orchestrator must guarantee story file exists)"
fi
echo ""
echo "=========================================="
echo "TDD SPEC CONTENT"
echo "=========================================="
echo ""
if [[ -f "$TDD_FILE" ]]; then
  cat "$TDD_FILE"
else
  echo "(no TDD spec — implement directly from story acceptance criteria)"
fi
echo ""
echo "=========================================="
echo "PRIOR EVIDENCE (if any)"
echo "=========================================="
echo ""
if [[ -f "$EVIDENCE_FILE" ]]; then
  echo "(prior evidence — read for context; you may overwrite)"
  echo ""
  cat "$EVIDENCE_FILE"
fi
echo ""
echo "=========================================="
echo "END OF PROMPT — execute the role"
echo "=========================================="