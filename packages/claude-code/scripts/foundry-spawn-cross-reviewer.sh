#!/usr/bin/env bash
# foundry-spawn-cross-reviewer.sh — Build the Agent-tool prompt for the cross-reviewer
#
# usage:
#   foundry-spawn-cross-reviewer.sh <ROUND> <TICKET-1> [TICKET-2 ...]
#
# Emits prompt body to stdout. Orchestrator passes it to Agent with profileId="Explore".

set -euo pipefail

ROUND="${1:-}"
shift || true
TICKETS=("$@")

if [[ -z "$ROUND" || "${#TICKETS[@]}" -eq 0 ]]; then
  echo "usage: foundry-spawn-cross-reviewer.sh <ROUND> <TICKET-1> [TICKET-2 ...]" >&2
  exit 2
fi

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
PROJECT_ROOT="${DEV_PIPELINE_PROJECT_ROOT:-$(pwd)}"
FOUNDRY_DIR="$PROJECT_ROOT/.foundry"
STATE_FILE="$FOUNDRY_DIR/state.md"

ROLE_FILE="$PLUGIN_ROOT/agents/foundry-cross-reviewer.md"
REVIEWS_DIR="$FOUNDRY_DIR/qa/review"
TICKETS_STR=$(IFS=,; echo "${TICKETS[*]}")
INTENT_SUMMARY="round-$ROUND"  # orchestrator can pass --intent=... in future
REVIEW_FILE="$REVIEWS_DIR/CROSS-${INTENT_SUMMARY}-round-${ROUND}.md"

read_state() {
  local key="$1"
  awk -v k="^  $key:" '$0 ~ k { sub(k "[[:space:]]*", ""); gsub(/^"|"$/, ""); print; exit }' "$STATE_FILE"
}

CROSS_MODEL=$(read_state cross_reviewer)
CROSS_MODEL="${CROSS_MODEL:-lite}"

echo "=========================================="
echo "ROLE: foundry-cross-reviewer (model=$CROSS_MODEL, profile=Explore)"
echo "=========================================="
echo ""
cat "$ROLE_FILE"
echo ""
echo "=========================================="
echo "ROUND PAYLOAD"
echo "=========================================="
echo ""
cat <<EOF
INTENT_SUMMARY: $INTENT_SUMMARY
ROUND: $ROUND
TICKETS_SHIPPED: $TICKETS_STR
PROJECT_ROOT: $PROJECT_ROOT
TICKETS_DIR: $FOUNDRY_DIR/plan/stories/
REVIEWS_DIR: $REVIEWS_DIR
REVIEW_OUTPUT: $REVIEW_FILE
CROSS_REVIEWER_MODEL: $CROSS_MODEL

Begin. Read all per-ticket reviews and the cumulative diff, then execute the role prompt above.
EOF
echo ""
echo "=========================================="
echo "PER-TICKET REVIEWS"
echo "=========================================="
echo ""
for t in "${TICKETS[@]}"; do
  RF="$REVIEWS_DIR/$t.md"
  echo "--- $t ---"
  if [[ -f "$RF" ]]; then
    cat "$RF"
  else
    echo "(missing review file)"
  fi
  echo ""
done

echo "=========================================="
echo "END OF PROMPT — execute the role"
echo "=========================================="