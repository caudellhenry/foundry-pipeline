#!/usr/bin/env bash
# foundry-spawn-reviewer.sh — Build the Agent-tool prompt for the per-ticket reviewer
#
# usage:
#   foundry-spawn-reviewer.sh <TICKET>
#
# Emits prompt body to stdout. The orchestrator passes it to the Agent tool
# with profileId="Explore" (read-only, model=lite by default).

set -euo pipefail

TICKET="${1:-}"
if [[ -z "$TICKET" ]]; then
  echo "usage: foundry-spawn-reviewer.sh <TICKET>" >&2
  exit 2
fi

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
PROJECT_ROOT="${DEV_PIPELINE_PROJECT_ROOT:-$(pwd)}"
FOUNDRY_DIR="$PROJECT_ROOT/.foundry"
STATE_FILE="$FOUNDRY_DIR/state.md"

ROLE_FILE="$PLUGIN_ROOT/agents/foundry-reviewer.md"
STORY_FILE="$FOUNDRY_DIR/plan/stories/$TICKET.md"
TDD_FILE="$FOUNDRY_DIR/tdd/$TICKET.md"
EVIDENCE_FILE="$FOUNDRY_DIR/qa/evidence/$TICKET.md"
REVIEW_FILE="$FOUNDRY_DIR/qa/review/$TICKET.md"

read_state() {
  local key="$1"
  awk -v k="^  $key:" '$0 ~ k { sub(k "[[:space:]]*", ""); gsub(/^"|"$/, ""); print; exit }' "$STATE_FILE"
}

REVIEWER_MODEL=$(read_state reviewer)
REVIEWER_MODEL="${REVIEWER_MODEL:-lite}"

# Read commit + branch from story frontmatter (set by writer)
read_story() {
  local key="$1"
  awk -v k="^  $key:" '$0 ~ k { sub(k "[[:space:]]*", ""); gsub(/^"|"$/, ""); print; exit }' "$STORY_FILE"
}

COMMIT=$(read_story commit)
BRANCH=$(read_story branch)
COMMIT="${COMMIT:-HEAD}"
BRANCH="${BRANCH:-main}"

echo "=========================================="
echo "ROLE: foundry-reviewer (model=$REVIEWER_MODEL, profile=Explore)"
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
PROJECT_ROOT: $PROJECT_ROOT
FOUNDRY_DIR: $FOUNDRY_DIR
STORY_FILE: $STORY_FILE
TDD_SPEC: $TDD_FILE
EVIDENCE_FILE: $EVIDENCE_FILE
COMMIT: $COMMIT
BRANCH: $BRANCH
REVIEW_OUTPUT: $REVIEW_FILE
REVIEWER_MODEL: $REVIEWER_MODEL

Begin. Read EVIDENCE_FILE and the diff for commit $COMMIT, then execute the role prompt above.
EOF
echo ""
echo "=========================================="
echo "EVIDENCE (writer's claims)"
echo "=========================================="
echo ""
if [[ -f "$EVIDENCE_FILE" ]]; then
  cat "$EVIDENCE_FILE"
else
  echo "(missing — writer has not produced evidence; flag this as NEEDS-FIX)"
fi
echo ""
echo "=========================================="
echo "STORY (what was the ticket supposed to do?)"
echo "=========================================="
echo ""
if [[ -f "$STORY_FILE" ]]; then
  cat "$STORY_FILE"
fi
echo ""
echo "=========================================="
echo "TDD SPEC (frozen contract)"
echo "=========================================="
echo ""
if [[ -f "$TDD_FILE" ]]; then
  cat "$TDD_FILE"
fi
echo ""
echo "=========================================="
echo "DIFF FOR REVIEW (commit $COMMIT)"
echo "=========================================="
echo ""
git -C "$PROJECT_ROOT" show --stat "$COMMIT" 2>/dev/null || echo "(commit not found in git history)"
echo ""
git -C "$PROJECT_ROOT" show "$COMMIT" 2>/dev/null || true
echo ""
echo "=========================================="
echo "END OF PROMPT — execute the role"
echo "=========================================="