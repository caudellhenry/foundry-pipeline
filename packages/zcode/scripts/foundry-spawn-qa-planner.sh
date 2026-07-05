#!/usr/bin/env bash
# foundry-spawn-qa-planner.sh — Build the Agent-tool prompt for the QA round planner
#
# usage:
#   foundry-spawn-qa-planner.sh <ROUND> <TICKET-1> [TICKET-2 ...] [--intent=<summary>]
#
# Emits prompt body to stdout. Orchestrator passes it to Agent with profileId="general-purpose".

set -euo pipefail

ROUND=""
TICKETS=()
INTENT_SUMMARY=""

# Parse args
for arg in "$@"; do
  case "$arg" in
    --intent=*) INTENT_SUMMARY="${arg#--intent=}" ;;
    *)
      if [[ -z "$ROUND" ]]; then
        ROUND="$arg"
      else
        TICKETS+=("$arg")
      fi
      ;;
  esac
done

if [[ -z "$ROUND" || "${#TICKETS[@]}" -eq 0 ]]; then
  echo "usage: foundry-spawn-qa-planner.sh <ROUND> <TICKET-1> [TICKET-2 ...] [--intent=<summary>]" >&2
  exit 2
fi

INTENT_SUMMARY="${INTENT_SUMMARY:-round-$ROUND}"

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
PROJECT_ROOT="${DEV_PIPELINE_PROJECT_ROOT:-$(pwd)}"
FOUNDRY_DIR="$PROJECT_ROOT/.foundry"
STATE_FILE="$FOUNDRY_DIR/state.md"

ROLE_FILE="$PLUGIN_ROOT/agents/foundry-qa-planner.md"
REVIEWS_DIR="$FOUNDRY_DIR/qa/review"
QA_PLAN_PATH="$FOUNDRY_DIR/qa/qa-plan.md"
BOARD_PATH="$FOUNDRY_DIR/plan/board.md"

TICKETS_STR=$(IFS=,; echo "${TICKETS[*]}")

read_state() {
  local key="$1"
  awk -v k="^  $key:" '$0 ~ k { sub(k "[[:space:]]*", ""); gsub(/^"|"$/, ""); print; exit }' "$STATE_FILE"
}

QA_PLANNER_MODEL=$(read_state qa_planner)
QA_PLANNER_MODEL="${QA_PLANNER_MODEL:-sonnet}"

echo "=========================================="
echo "ROLE: foundry-qa-planner (model=$QA_PLANNER_MODEL, profile=general-purpose)"
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
REVIEWS_DIR: $REVIEWS_DIR
QA_PLAN_PATH: $QA_PLAN_PATH
BOARD_PATH: $BOARD_PATH
QA_PLANNER_MODEL: $QA_PLANNER_MODEL

Begin. Read all per-ticket reviews and the cross-review, then execute the role prompt above.
EOF
echo ""
echo "=========================================="
echo "ALL REVIEWS (per-ticket + cross)"
echo "=========================================="
echo ""
for t in "${TICKETS[@]}"; do
  RF="$REVIEWS_DIR/$t.md"
  echo "--- $t ---"
  if [[ -f "$RF" ]]; then cat "$RF"; else echo "(missing)"; fi
  echo ""
done

CROSS_FILE=$(ls -t "$REVIEWS_DIR"/CROSS-*-round-"$ROUND".md 2>/dev/null | head -1 || true)
if [[ -n "$CROSS_FILE" && -f "$CROSS_FILE" ]]; then
  echo "--- $(basename "$CROSS_FILE") ---"
  cat "$CROSS_FILE"
  echo ""
fi

echo "=========================================="
echo "CURRENT QA-PLAN.MD (you will rewrite this)"
echo "=========================================="
echo ""
if [[ -f "$QA_PLAN_PATH" ]]; then
  cat "$QA_PLAN_PATH"
fi
echo ""
echo "=========================================="
echo "BOARD (you will append NEW-### tickets)"
echo "=========================================="
echo ""
if [[ -f "$BOARD_PATH" ]]; then
  cat "$BOARD_PATH"
fi
echo ""
echo "=========================================="
echo "STATE (for convergence gate values)"
echo "=========================================="
echo ""
if [[ -f "$STATE_FILE" ]]; then
  cat "$STATE_FILE"
fi
echo ""
echo "=========================================="
echo "END OF PROMPT — execute the role"
echo "=========================================="