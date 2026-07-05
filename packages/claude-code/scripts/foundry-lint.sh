#!/usr/bin/env bash
# foundry-lint.sh — run lint command from state.md and report error count
#
# usage:
#   foundry-lint.sh               # prints "LINT: N errors"
#
# Used by verify_execute as part of the gate. Also callable directly.

set -euo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
PROJECT_ROOT="${DEV_PIPELINE_PROJECT_ROOT:-$(pwd)}"
FOUNDRY_DIR="$PROJECT_ROOT/.foundry"
STATE_FILE="$FOUNDRY_DIR/state.md"
TEST_RUNS_DIR="$FOUNDRY_DIR/qa/evidence/test-runs"
mkdir -p "$TEST_RUNS_DIR"

LINT_CMD="$(awk -v k="^  lint_cmd:" '$0 ~ k { sub(k "[[:space:]]*", ""); gsub(/^"|"$/, ""); print; exit }' "$STATE_FILE")"
TIMEOUT="$(awk -v k="^  timeout:" '$0 ~ k { sub(k "[[:space:]]*", ""); print; exit }' "$STATE_FILE")"
TIMEOUT="${TIMEOUT:-300}"

if [[ -z "$LINT_CMD" ]]; then
  echo "LINT: 0 (no lint_cmd configured)"
  exit 0
fi

LOG="$TEST_RUNS_DIR/lint-$(date +%s).log"
# shellcheck disable=SC2086
timeout "${TIMEOUT}" bash -c "$LINT_CMD" >"$LOG" 2>&1 || EXIT=$?
EXIT=${EXIT:-0}

# ESLint: "✖ N problems"
if grep -qE '[0-9]+ problems?' "$LOG"; then
  ERRORS="$(grep -oE '[0-9]+ problems?' "$LOG" | head -1 | grep -oE '[0-9]+' | head -1)"
  echo "LINT: $ERRORS errors"
  exit "$ERRORS"
fi
# Generic: count lines starting with "error"
ERRORS="$(grep -cE '^(error|✖)' "$LOG" 2>/dev/null || true)"
ERRORS="$(printf '%s' "$ERRORS" | tr -d '[:space:]')"
ERRORS="${ERRORS:-0}"
echo "LINT: $ERRORS errors"
exit "$EXIT"