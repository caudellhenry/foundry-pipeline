#!/usr/bin/env bash
# foundry-coverage.sh — run coverage command and report percentage
#
# usage:
#   foundry-coverage.sh           # runs coverage_cmd from state.md, prints "COVERAGE: NN.NN%"
#
# This is a thin wrapper. The real coverage parsing happens inside foundry-test-runner.sh.
# Use this script when you want to set the coverage_baseline on first run.

set -euo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
PROJECT_ROOT="${DEV_PIPELINE_PROJECT_ROOT:-$(pwd)}"
FOUNDRY_DIR="$PROJECT_ROOT/.foundry"
STATE_FILE="$FOUNDRY_DIR/state.md"
TEST_RUNS_DIR="$FOUNDRY_DIR/qa/evidence/test-runs"
mkdir -p "$TEST_RUNS_DIR"

COVERAGE_CMD="$(awk -v k="^  coverage_cmd:" '$0 ~ k { sub(k "[[:space:]]*", ""); gsub(/^"|"$/, ""); print; exit }' "$STATE_FILE")"
TIMEOUT="$(awk -v k="^  timeout:" '$0 ~ k { sub(k "[[:space:]]*", ""); print; exit }' "$STATE_FILE")"
TIMEOUT="${TIMEOUT:-300}"

if [[ -z "$COVERAGE_CMD" ]]; then
  echo "COVERAGE: 0 (no coverage_cmd configured in state.md)" >&2
  exit 0
fi

LOG="$TEST_RUNS_DIR/coverage-$(date +%s).log"
# shellcheck disable=SC2086
timeout "${TIMEOUT}" bash -c "$COVERAGE_CMD" >"$LOG" 2>&1 || true

# Parse: jest/vitest "All files | NN.NN"  or  pytest "TOTAL.*NN%"
PCT="$(grep -oE 'All files[^|]*\|[^|]*([0-9]+\.?[0-9]*)' "$LOG" | head -1 | grep -oE '[0-9]+\.?[0-9]*$' | head -1)"
if [[ -z "$PCT" ]]; then
  PCT="$(grep -oE 'TOTAL[^|]*[0-9]+%' "$LOG" | head -1 | grep -oE '[0-9]+%' | tr -d '%' | head -1)"
fi
if [[ -z "$PCT" ]]; then
  PCT="$(grep -oE 'coverage:[^0-9]*([0-9]+\.?[0-9]*)%' "$LOG" | head -1 | sed -E 's/.*([0-9]+\.?[0-9]*)%.*/\1/')"
fi

if [[ -n "$PCT" ]]; then
  echo "COVERAGE: $PCT%"
  echo "$PCT" > "$FOUNDRY_DIR/qa/evidence/.coverage-baseline" 2>/dev/null || true
  exit 0
fi
echo "COVERAGE: 0 (could not parse coverage from log; see $LOG)" >&2
exit 1