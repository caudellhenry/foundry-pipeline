#!/usr/bin/env bash
# foundry-check-convergence.sh -- Check the 8 QA convergence gates
#
# usage:
#   foundry-check-convergence.sh           # prints gate status; exit 0 if all green, 1 otherwise
#   foundry-check-convergence.sh --strict  # also fail on medium findings (default behaviour)
#   foundry-check-convergence.sh --json    # machine-readable output
#
# Gates:
#   1. Board empty (Ready + In progress = 0)
#   2. Review empty (every Review ticket has human_approved: true in its review file)
#   3. No high findings (qa-plan.md findings.high == 0)
#   4. No medium findings (qa-plan.md findings.medium == 0; configurable)
#   5. Tests pass (latest full-suite runner JSON has failed == 0)
#   6. Coverage gate (coverage_pct >= threshold AND >= baseline - 2)
#   7. Lint + typecheck clean (both have 0 errors)
#   8. User signoff (state.md signoff.user_signed_off == true)

set -euo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
PROJECT_ROOT="${DEV_PIPELINE_PROJECT_ROOT:-$(pwd)}"
FOUNDRY_DIR="$PROJECT_ROOT/.foundry"
STATE_FILE="$FOUNDRY_DIR/state.md"
BOARD_FILE="$FOUNDRY_DIR/plan/board.md"
QA_PLAN="$FOUNDRY_DIR/qa/qa-plan.md"
TEST_RUNS_DIR="$FOUNDRY_DIR/qa/evidence/test-runs"

JSON_OUT="false"
for arg in "$@"; do
  if [[ "$arg" == "--json" ]]; then JSON_OUT="true"; fi
done

FAIL_COUNT=0

# Helper: emit gate result
emit_gate() {
  local id="$1" name="$2" status="$3" detail="${4:-}"
  if [[ "$status" != "PASS" ]]; then
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
  if [[ "$JSON_OUT" != "true" ]]; then
    if [[ "$status" == "PASS" ]]; then
      echo "  PASS $id. $name"
    else
      echo "  FAIL $id. $name -- $detail"
    fi
  fi
}

# Helper: read a state.md value (key under top-level)
read_state() {
  local key="$1"
  awk -v k="^  $key:" '$0 ~ k { sub(k "[[:space:]]*", ""); gsub(/^"|"$/, ""); print; exit }' "$STATE_FILE"
}

# --- Gate 1: Board empty ---
READY_COUNT=0
IN_PROGRESS_COUNT=0
if [[ -f "$BOARD_FILE" ]]; then
  READY_COUNT=$(awk '/^## Ready/{flag=1; next} /^## /{flag=0} flag && /^- \[ \]/{c++} END{print c+0}' "$BOARD_FILE")
  IN_PROGRESS_COUNT=$(awk '/^## In progress/{flag=1; next} /^## /{flag=0} flag && /^- \[ \]/{c++} END{print c+0}' "$BOARD_FILE")
fi
if [[ "$READY_COUNT" == "0" && "$IN_PROGRESS_COUNT" == "0" ]]; then
  emit_gate 1 "Board empty" "PASS"
else
  emit_gate 1 "Board empty" "FAIL" "ready=$READY_COUNT, in_progress=$IN_PROGRESS_COUNT"
fi

# --- Gate 2: Review empty ---
REVIEW_PENDING=0
if [[ -f "$BOARD_FILE" ]]; then
  REVIEW_TICKETS=$(awk '/^## Review/{flag=1; next} /^## /{flag=0} flag && /^- \[ \]/{print $3}' "$BOARD_FILE" | sort -u)
  for t in $REVIEW_TICKETS; do
    REVIEW_FILE="$FOUNDRY_DIR/qa/review/$t.md"
    if [[ ! -f "$REVIEW_FILE" ]]; then
      REVIEW_PENDING=$((REVIEW_PENDING + 1))
      continue
    fi
    APPROVED=$(grep -E '^human_approved:' "$REVIEW_FILE" | sed 's/^human_approved:[[:space:]]*//' | head -1 | tr -d '[:space:]')
    if [[ "$APPROVED" != "true" ]]; then
      REVIEW_PENDING=$((REVIEW_PENDING + 1))
    fi
  done
fi
if [[ "$REVIEW_PENDING" == "0" ]]; then
  emit_gate 2 "Review empty" "PASS"
else
  emit_gate 2 "Review empty" "FAIL" "$REVIEW_PENDING tickets pending human approval"
fi

# --- Gate 3 + 4: No high/medium findings ---
HIGH=0
MEDIUM=0
if [[ -f "$QA_PLAN" ]]; then
  HIGH=$(grep -E '^  high:' "$QA_PLAN" | sed 's/^  high:[[:space:]]*//' | head -1 | tr -d '[:space:]')
  MEDIUM=$(grep -E '^  medium:' "$QA_PLAN" | sed 's/^  medium:[[:space:]]*//' | head -1 | tr -d '[:space:]')
  HIGH="${HIGH:-0}"
  MEDIUM="${MEDIUM:-0}"
fi
if [[ "$HIGH" == "0" ]]; then
  emit_gate 3 "No high findings" "PASS"
else
  emit_gate 3 "No high findings" "FAIL" "$HIGH high findings in qa-plan.md"
fi
if [[ "$MEDIUM" == "0" ]]; then
  emit_gate 4 "No medium findings" "PASS"
else
  emit_gate 4 "No medium findings" "FAIL" "$MEDIUM medium findings in qa-plan.md"
fi

# --- Gate 5: Tests pass ---
LATEST_JSON=""
if [[ -d "$TEST_RUNS_DIR" ]]; then
  LATEST_JSON=$(ls -t "$TEST_RUNS_DIR"/*.json 2>/dev/null | grep -v '.cache' | head -1 || true)
  if [[ -z "$LATEST_JSON" ]]; then
    LATEST_JSON=$(ls -t "$TEST_RUNS_DIR"/*full*.json 2>/dev/null | head -1 || true)
  fi
fi
TESTS_PASS="true"
TESTS_DETAIL="no test runs yet"
if [[ -n "$LATEST_JSON" && -f "$LATEST_JSON" ]]; then
  FAILED=$(grep -oE '"failed":[0-9]+' "$LATEST_JSON" | head -1 | grep -oE '[0-9]+' || echo "0")
  VERDICT=$(grep -oE '"verdict":"[^"]*"' "$LATEST_JSON" | head -1 | sed 's/.*"verdict":"\([^"]*\)".*/\1/')
  if [[ "${FAILED:-0}" -gt 0 || "$VERDICT" == "FAIL" ]]; then
    TESTS_PASS="false"
    TESTS_DETAIL="$FAILED test failures in $(basename "$LATEST_JSON")"
  else
    TESTS_DETAIL="$(basename "$LATEST_JSON") -- all passed"
  fi
fi
if [[ "$TESTS_PASS" == "true" ]]; then
  emit_gate 5 "Tests pass" "PASS" "$TESTS_DETAIL"
else
  emit_gate 5 "Tests pass" "FAIL" "$TESTS_DETAIL"
fi

# --- Gate 6: Coverage gate ---
COV_THRESHOLD=$(read_state coverage_threshold)
COV_BASELINE=$(read_state coverage_baseline)
COV_THRESHOLD="${COV_THRESHOLD:-0}"
COV_BASELINE="${COV_BASELINE:-null}"
COV_PCT=""
if [[ -n "$LATEST_JSON" && -f "$LATEST_JSON" ]]; then
  COV_PCT=$(grep -oE '"coverage_pct":[0-9.]+' "$LATEST_JSON" | head -1 | grep -oE '[0-9.]+' || echo "")
fi
COV_PASS="true"
COV_DETAIL=""
if [[ -n "$COV_THRESHOLD" && "$COV_THRESHOLD" != "0" && -n "$COV_PCT" ]]; then
  COV_PASS_ABOVE=$(awk -v a="$COV_PCT" -v b="$COV_THRESHOLD" 'BEGIN{print (a+0 >= b+0) ? "true" : "false"}')
  if [[ "$COV_PASS_ABOVE" != "true" ]]; then
    COV_PASS="false"
    COV_DETAIL="$COV_PCT% < threshold $COV_THRESHOLD%"
  fi
fi
if [[ "$COV_BASELINE" != "null" && -n "$COV_BASELINE" && -n "$COV_PCT" ]]; then
  MIN_ACCEPTABLE=$(awk -v b="$COV_BASELINE" 'BEGIN{print b-2}')
  COV_NO_REG=$(awk -v a="$COV_PCT" -v b="$MIN_ACCEPTABLE" 'BEGIN{print (a+0 >= b+0) ? "true" : "false"}')
  if [[ "$COV_NO_REG" != "true" ]]; then
    COV_PASS="false"
    COV_DETAIL="${COV_DETAIL:+${COV_DETAIL}; }$COV_PCT% regressed > 2% from baseline $COV_BASELINE%"
  fi
fi
if [[ -z "$COV_DETAIL" ]]; then
  if [[ -n "$COV_PCT" ]]; then
    COV_DETAIL="$COV_PCT% (threshold=$COV_THRESHOLD, baseline=$COV_BASELINE)"
  else
    COV_DETAIL="no coverage data; threshold=$COV_THRESHOLD (0 = no gate)"
  fi
fi
if [[ "$COV_PASS" == "true" ]]; then
  emit_gate 6 "Coverage gate" "PASS" "$COV_DETAIL"
else
  emit_gate 6 "Coverage gate" "FAIL" "$COV_DETAIL"
fi

# --- Gate 7: Lint + typecheck clean ---
LINT_ERR=0
TC_ERR=0
if [[ -n "$LATEST_JSON" && -f "$LATEST_JSON" ]]; then
  LINT_ERR=$(grep -oE '"lint_errors":[0-9]+' "$LATEST_JSON" | head -1 | grep -oE '[0-9]+' || echo "0")
  TC_ERR=$(grep -oE '"typecheck_errors":[0-9]+' "$LATEST_JSON" | head -1 | grep -oE '[0-9]+' || echo "0")
fi
if [[ "$LINT_ERR" == "0" && "$TC_ERR" == "0" ]]; then
  emit_gate 7 "Lint + typecheck clean" "PASS" "lint=$LINT_ERR, typecheck=$TC_ERR"
else
  emit_gate 7 "Lint + typecheck clean" "FAIL" "lint=$LINT_ERR, typecheck=$TC_ERR"
fi

# --- Gate 8: User signoff ---
SIGNED_OFF=$(read_state user_signed_off)
SIGNED_OFF="${SIGNED_OFF:-false}"
if [[ "$SIGNED_OFF" == "true" ]]; then
  emit_gate 8 "User signoff" "PASS"
else
    emit_gate 8 "User signoff" "FAIL" "run /foundry-signoff to mark signed off"
fi

# --- Emit ---
if [[ "$JSON_OUT" == "true" ]]; then
  # Emit JSON via tmpfile (avoid complex printf escaping)
  TMP=$(mktemp)
  {
    echo "{"
    echo "  \"failed_count\": $FAIL_COUNT,"
    echo "  \"verdict\": \"$([ "$FAIL_COUNT" -eq 0 ] && echo CONVERGED || echo NOT_CONVERGED)\""
    echo "}"
  } > "$TMP"
  cat "$TMP"
  rm "$TMP"
else
  echo ""
  if [[ "$FAIL_COUNT" -eq 0 ]]; then
    echo "OK All 8 gates pass -- pipeline CONVERGED."
  else
    echo "FAIL $FAIL_COUNT gate(s) failed -- pipeline NOT converged."
  fi
fi

[[ "$FAIL_COUNT" -eq 0 ]] && exit 0 || exit 1