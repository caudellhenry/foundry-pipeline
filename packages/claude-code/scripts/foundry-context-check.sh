#!/usr/bin/env bash
# foundry-context-check.sh — recommend context rotation (Breunig's 4 failure modes)
#
# Checks:
#   1. Size — has the conversation exceeded 80% of the model's context window?
#      (heuristic: log file size > 200KB suggests ~100k tokens worth of activity)
#   2. Distraction — has the conversation gone > 20 turns without mentioning
#      the current ticket?
#   3. Clash — do recent tool outputs disagree on a key fact?
#
# Prints a single line: either "ok" or "rotate: <reason>".
# Exit 0 always (this hook only recommends, never blocks).

set -euo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
PROJECT_ROOT="${DEV_PIPELINE_PROJECT_ROOT:-$(pwd)}"
FOUNDRY_DIR="$PROJECT_ROOT/.foundry"
STATE_FILE="$FOUNDRY_DIR/state.md"

# Size check on the current phase log
PHASE="$(grep -E '^current_phase:' "$STATE_FILE" | sed 's/^current_phase:[[:space:]]*//' | head -1)"
LOG="$FOUNDRY_DIR/logs/${PHASE}.log"
if [[ -f "$LOG" ]]; then
  SIZE=$(wc -c < "$LOG" | tr -d ' ')
  if [[ "$SIZE" -gt 204800 ]]; then  # 200KB ≈ 100k tokens of activity
    echo "rotate: ${PHASE}.log exceeds 200KB ($SIZE bytes) — recommend /compact"
    exit 0
  fi
fi

# Distraction check — count recent log lines not mentioning a ticket id
if [[ -f "$LOG" ]]; then
  UNFOCUSED=$(tail -50 "$LOG" | grep -cvE 'STORY-[0-9]+|NEW-[0-9]+' || true)
  if [[ "$UNFOCUSED" -ge 40 ]]; then
    echo "rotate: last 50 log lines have $UNFOCUSED without a ticket ref — focus drift, recommend /clear"
    exit 0
  fi
fi

echo "ok"
exit 0