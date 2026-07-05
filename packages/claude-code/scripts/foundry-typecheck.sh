#!/usr/bin/env bash
# foundry-typecheck.sh — run typecheck command from state.md and report error count
#
# usage:
#   foundry-typecheck.sh          # prints "TYPECHECK: N errors"

set -euo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
PROJECT_ROOT="${DEV_PIPELINE_PROJECT_ROOT:-$(pwd)}"
FOUNDRY_DIR="$PROJECT_ROOT/.foundry"
STATE_FILE="$FOUNDRY_DIR/state.md"
TEST_RUNS_DIR="$FOUNDRY_DIR/qa/evidence/test-runs"
mkdir -p "$TEST_RUNS_DIR"

TYPECHECK_CMD="$(awk -v k="^  typecheck_cmd:" '$0 ~ k { sub(k "[[:space:]]*", ""); gsub(/^"|"$/, ""); print; exit }' "$STATE_FILE")"
TIMEOUT="$(awk -v k="^  timeout:" '$0 ~ k { sub(k "[[:space:]]*", ""); print; exit }' "$STATE_FILE")"
TIMEOUT="${TIMEOUT:-300}"

if [[ -z "$TYPECHECK_CMD" ]]; then
  echo "TYPECHECK: 0 (no typecheck_cmd configured)"
  exit 0
fi

LOG="$TEST_RUNS_DIR/typecheck-$(date +%s).log"
EXIT=0
# shellcheck disable=SC2086
timeout "${TIMEOUT}" bash -c "$TYPECHECK_CMD" >"$LOG" 2>&1 || EXIT=$?

# tsc: "Found N errors"
if grep -qE 'Found [0-9]+ errors?' "$LOG"; then
  ERRORS="$(grep -oE 'Found [0-9]+ errors?' "$LOG" | head -1 | grep -oE '[0-9]+' | head -1)"
  echo "TYPECHECK: $ERRORS errors"
  exit "$ERRORS"
fi
# mypy: "Found N errors"
if grep -qE 'Found [0-9]+ errors?' "$LOG"; then
  ERRORS="$(grep -oE 'Found [0-9]+ errors?' "$LOG" | head -1 | grep -oE '[0-9]+' | head -1)"
  echo "TYPECHECK: $ERRORS errors"
  exit "$ERRORS"
fi
# Generic: error TSNNNN / error: lines
ERRORS="$(grep -cE '^(error|.*\.ts\([0-9]+,[0-9]+\): error)' "$LOG" 2>/dev/null || true)"
ERRORS="$(printf '%s' "$ERRORS" | tr -d '[:space:]')"
ERRORS="${ERRORS:-0}"
echo "TYPECHECK: $ERRORS errors"
exit "$EXIT"