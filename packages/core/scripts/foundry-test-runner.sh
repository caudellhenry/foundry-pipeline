#!/usr/bin/env bash
# foundry-test-runner.sh — run the project's test_cmd, parse results, emit JSON
#
# usage:
#   foundry-test-runner.sh <TICKET> [--full-suite] [--no-cache] [--scope=<path>]
#
# Reads .foundry/state.md `test:` block for cmd, coverage_cmd, lint_cmd,
# typecheck_cmd, timeout, coverage_threshold, coverage_baseline.
# If --scope is given, overrides per_story_cmd_template with the scope (path).
# If --full-suite is set, ignores per_story_cmd_template and runs the full cmd.
#
# Emits a structured JSON object to stdout:
#   {
#     "ticket": "STORY-001",
#     "commit": "abc1234",
#     "scope": "src/foo/bar.test.ts",
#     "cmd": "npx jest src/foo/bar.test.ts",
#     "started_at": "...",
#     "finished_at": "...",
#     "duration_s": 12.3,
#     "tests_run": 42, "passed": 42, "failed": 0, "skipped": 0,
#     "coverage_pct": 87.5, "coverage_baseline": 85.0, "coverage_threshold": 80,
#     "coverage_pass": true, "coverage_baseline_pass": true,
#     "lint_errors": 0, "typecheck_errors": 0,
#     "exit_code": 0,
#     "log_path": ".foundry/qa/evidence/test-runs/STORY-001-...log",
#     "verdict": "PASS" | "FAIL",
#     "reason": ""
#   }
#
# Side effects:
#   - Writes full stdout+stderr to log_path
#   - Updates .foundry/qa/evidence/<TICKET>.md frontmatter (test_run block)
#   - Updates .foundry/plan/stories/<TICKET>.md frontmatter (test_results block)
#   - If skip_tests=true in state.md, emits a stub PASS verdict and exits 0
#   - Caches last result per (ticket, commit) in .foundry/qa/evidence/test-runs/.cache/

set -euo pipefail

TICKET="${1:-}"
shift || true

if [[ -z "$TICKET" ]]; then
  echo "usage: foundry-test-runner.sh <TICKET> [--full-suite] [--no-cache] [--scope=<path>]" >&2
  exit 2
fi

FULL_SUITE="false"
NO_CACHE="false"
SCOPE=""
for arg in "$@"; do
  case "$arg" in
    --full-suite) FULL_SUITE="true" ;;
    --no-cache)   NO_CACHE="true"   ;;
    --scope=*)    SCOPE="${arg#--scope=}" ;;
    *) ;;
  esac
done

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
PROJECT_ROOT="${DEV_PIPELINE_PROJECT_ROOT:-$(pwd)}"
FOUNDRY_DIR="$PROJECT_ROOT/.foundry"
STATE_FILE="$FOUNDRY_DIR/state.md"
TEST_RUNS_DIR="$FOUNDRY_DIR/qa/evidence/test-runs"
mkdir -p "$TEST_RUNS_DIR" "$TEST_RUNS_DIR/.cache"

# Read test: block from state.md
# Strips inline comments (anything from # onwards) AND trims whitespace.
# v1.0.0 — needed because state.md frontmatter has many inline comments.
read_state() {
  local key="$1"
  awk -v k="^  $key:" '
    $0 ~ k {
      sub(k "[[:space:]]*", "")
      # Strip inline comments (# to end of line) BEFORE stripping quotes
      sub(/[[:space:]]*#.*$/, "")
      gsub(/^"|"$/, "")
      gsub(/[[:space:]]+$/, "")
      print
      exit
    }
  ' "$STATE_FILE"
}

TEST_CMD="$(read_state cmd)"
TEST_SCOPE_TEMPLATE="$(read_state per_story_cmd_template)"
TEST_TIMEOUT="$(read_state timeout)"
TEST_TIMEOUT="${TEST_TIMEOUT:-300}"
COVERAGE_CMD="$(read_state coverage_cmd)"
COVERAGE_THRESHOLD="$(read_state coverage_threshold)"
COVERAGE_THRESHOLD="${COVERAGE_THRESHOLD:-0}"
COVERAGE_BASELINE="$(read_state coverage_baseline)"
COVERAGE_BASELINE="${COVERAGE_BASELINE:-null}"
LINT_CMD="$(read_state lint_cmd)"
TYPECHECK_CMD="$(read_state typecheck_cmd)"
SKIP_TESTS="$(read_state skip_tests)"
SKIP_TESTS="${SKIP_TESTS:-false}"
CACHE_BY_COMMIT="$(read_state cache_by_commit)"
CACHE_BY_COMMIT="${CACHE_BY_COMMIT:-true}"

# Get current commit hash (short)
COMMIT="$(git -C "$PROJECT_ROOT" rev-parse --short HEAD 2>/dev/null || echo "no-commit")"

# --- Skip tests: stub PASS ---
if [[ "$SKIP_TESTS" == "true" ]]; then
  cat <<EOF
{"ticket":"$TICKET","commit":"$COMMIT","scope":"","cmd":"","started_at":"","finished_at":"","duration_s":0,"tests_run":0,"passed":0,"failed":0,"skipped":0,"coverage_pct":null,"coverage_baseline":null,"coverage_threshold":0,"coverage_pass":true,"coverage_baseline_pass":true,"lint_errors":0,"typecheck_errors":0,"exit_code":0,"log_path":"","verdict":"PASS","reason":"skip_tests=true (explicit opt-out)"}
EOF
  exit 0
fi

# --- Build the cmd to run ---
RUN_CMD=""
if [[ "$FULL_SUITE" == "true" || -z "$SCOPE" || -z "$TEST_SCOPE_TEMPLATE" ]]; then
  RUN_CMD="$TEST_CMD"
  EFFECTIVE_SCOPE=""
else
  # Substitute {path} placeholder
  RUN_CMD="${TEST_SCOPE_TEMPLATE/\{path\}/$SCOPE}"
  EFFECTIVE_SCOPE="$SCOPE"
fi

# --- Check cache ---
CACHE_KEY="${TICKET}_${COMMIT}_${EFFECTIVE_SCOPE}_${RUN_CMD//[\/ ]/_}"
CACHE_FILE="$TEST_RUNS_DIR/.cache/${CACHE_KEY}.json"
if [[ "$CACHE_BY_COMMIT" == "true" && "$NO_CACHE" != "true" && -f "$CACHE_FILE" ]]; then
  cat "$CACHE_FILE"
  exit 0
fi

# --- Run ---
TS_START="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
EPOCH_START="$(date +%s)"
LOG_FILE="$TEST_RUNS_DIR/${TICKET}-${COMMIT}-${EPOCH_START}.log"

EXIT_CODE=0
if [[ -n "$RUN_CMD" ]]; then
  # shellcheck disable=SC2086
  timeout "${TEST_TIMEOUT}" bash -c "$RUN_CMD" >"$LOG_FILE" 2>&1 || EXIT_CODE=$?
fi
EPOCH_END="$(date +%s)"
DURATION=$((EPOCH_END - EPOCH_START))
TS_END="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

# --- Parse results from the log ---
TESTS_RUN=0
PASSED=0
FAILED=0
SKIPPED=0

# Try Jest/Vitest format: "Tests: X passed, Y failed, Z total"
if grep -qE '^Tests:' "$LOG_FILE" 2>/dev/null; then
  LINE="$(grep -E '^Tests:' "$LOG_FILE" | head -1)"
  PASSED="$(echo "$LINE" | grep -oE '[0-9]+ passed' | grep -oE '[0-9]+' | head -1)"
  FAILED="$(echo "$LINE" | grep -oE '[0-9]+ failed' | grep -oE '[0-9]+' | head -1)"
  SKIPPED="$(echo "$LINE" | grep -oE '[0-9]+ skipped' | grep -oE '[0-9]+' | head -1)"
  TESTS_RUN="$(echo "$LINE" | grep -oE '[0-9]+ total' | grep -oE '[0-9]+' | head -1)"
  PASSED="${PASSED:-0}"
  FAILED="${FAILED:-0}"
  SKIPPED="${SKIPPED:-0}"
  TESTS_RUN="${TESTS_RUN:-0}"
fi

# Try pytest format: "X passed, Y failed in Zs"
if [[ "$TESTS_RUN" == "0" ]] && grep -qE 'passed|failed' "$LOG_FILE" 2>/dev/null; then
  LINE="$(grep -E '[0-9]+ (passed|failed)' "$LOG_FILE" | tail -1)"
  PASSED="$(echo "$LINE" | grep -oE '[0-9]+ passed' | grep -oE '[0-9]+' | head -1)"
  FAILED="$(echo "$LINE" | grep -oE '[0-9]+ failed' | grep -oE '[0-9]+' | head -1)"
  TESTS_RUN=$(( ${PASSED:-0} + ${FAILED:-0} ))
fi

# Try go test format: "PASS" or "FAIL" + "ok" lines
if [[ "$TESTS_RUN" == "0" ]] && grep -qE '^(ok|FAIL|---)' "$LOG_FILE" 2>/dev/null; then
  OK_COUNT="$(grep -cE '^ok' "$LOG_FILE" 2>/dev/null || true)"
  FAIL_COUNT="$(grep -cE '^FAIL' "$LOG_FILE" 2>/dev/null || true)"
  OK_COUNT="$(printf '%s' "$OK_COUNT" | tr -d '[:space:]')"
  FAIL_COUNT="$(printf '%s' "$FAIL_COUNT" | tr -d '[:space:]')"
  OK_COUNT="${OK_COUNT:-0}"
  FAIL_COUNT="${FAIL_COUNT:-0}"
  PASSED="${OK_COUNT:-0}"
  FAILED="${FAIL_COUNT:-0}"
  TESTS_RUN=$(( PASSED + FAILED ))
fi

# --- Coverage ---
COVERAGE_PCT="null"
COVERAGE_LOG=""
if [[ -n "$COVERAGE_CMD" && "$FULL_SUITE" == "true" ]]; then
  COVERAGE_LOG="$TEST_RUNS_DIR/${TICKET}-${COMMIT}-${EPOCH_START}-coverage.log"
  # shellcheck disable=SC2086
  timeout "${TEST_TIMEOUT}" bash -c "$COVERAGE_CMD" >"$COVERAGE_LOG" 2>&1 || true
  # Parse: jest/vitest "All files | NN.NN"  or  pytest "TOTAL.*NN%"
  PCT="$(grep -oE 'All files[^|]*\|[^|]*([0-9]+\.?[0-9]*)' "$COVERAGE_LOG" | head -1 | grep -oE '[0-9]+\.?[0-9]*$' | head -1)"
  if [[ -z "$PCT" ]]; then
    PCT="$(grep -oE 'TOTAL[^|]*[0-9]+%' "$COVERAGE_LOG" | head -1 | grep -oE '[0-9]+%' | tr -d '%' | head -1)"
  fi
  if [[ -z "$PCT" ]]; then
    PCT="$(grep -oE 'coverage:[^0-9]*([0-9]+\.?[0-9]*)%' "$COVERAGE_LOG" | head -1 | sed -E 's/.*([0-9]+\.?[0-9]*)%.*/\1/')"
  fi
  if [[ -n "$PCT" ]]; then
    COVERAGE_PCT="$PCT"
  fi
fi

# --- Coverage gates ---
COVERAGE_PASS="true"
if [[ -n "$COVERAGE_THRESHOLD" ]] && [[ "$COVERAGE_THRESHOLD" != "0" ]] && [[ "$COVERAGE_PCT" != "null" ]]; then
  # awk comparison
  COVERAGE_PASS="$(awk -v a="$COVERAGE_PCT" -v b="$COVERAGE_THRESHOLD" 'BEGIN{print (a+0 >= b+0) ? "true" : "false"}')"
fi

COVERAGE_BASELINE_PASS="true"
if [[ "$COVERAGE_BASELINE" != "null" && "$COVERAGE_BASELINE" != "" && "$COVERAGE_PCT" != "null" ]]; then
  MIN_ACCEPTABLE="$(awk -v b="$COVERAGE_BASELINE" 'BEGIN{print b-2}')"
  COVERAGE_BASELINE_PASS="$(awk -v a="$COVERAGE_PCT" -v b="$MIN_ACCEPTABLE" 'BEGIN{print (a+0 >= b+0) ? "true" : "false"}')"
fi

# --- Lint ---
LINT_ERRORS=0
if [[ -n "$LINT_CMD" ]]; then
  LINT_LOG="$TEST_RUNS_DIR/${TICKET}-${COMMIT}-${EPOCH_START}-lint.log"
  # shellcheck disable=SC2086
  bash -c "$LINT_CMD" >"$LINT_LOG" 2>&1 || LINT_ERRORS=$?
  LINT_LOG_TAIL="$LINT_LOG"
  # ESLint summary line "✖ N problems"
  if grep -qE '[0-9]+ problems?' "$LINT_LOG"; then
    LINT_ERRORS="$(grep -oE '[0-9]+ problems?' "$LINT_LOG" | head -1 | grep -oE '[0-9]+' | head -1)"
  fi
  LINT_ERRORS="${LINT_ERRORS:-0}"
fi

# --- Typecheck ---
TYPECHECK_ERRORS=0
if [[ -n "$TYPECHECK_CMD" ]]; then
  TC_LOG="$TEST_RUNS_DIR/${TICKET}-${COMMIT}-${EPOCH_START}-typecheck.log"
  # shellcheck disable=SC2086
  bash -c "$TYPECHECK_CMD" >"$TC_LOG" 2>&1 || TYPECHECK_ERRORS=$?
  # tsc: "Found N errors"
  if grep -qE 'Found [0-9]+ errors?' "$TC_LOG"; then
    TYPECHECK_ERRORS="$(grep -oE 'Found [0-9]+ errors?' "$TC_LOG" | head -1 | grep -oE '[0-9]+' | head -1)"
  fi
  TYPECHECK_ERRORS="${TYPECHECK_ERRORS:-0}"
fi

# --- Verdict ---
VERDICT="PASS"
REASON=""
if [[ "$EXIT_CODE" -ne 0 || "${FAILED:-0}" -gt 0 ]]; then
  VERDICT="FAIL"
  REASON="tests failed ($FAILED of $TESTS_RUN)"
fi
if [[ "$COVERAGE_PASS" == "false" ]]; then
  VERDICT="FAIL"
  REASON="${REASON:+$REASON; }coverage $COVERAGE_PCT% < threshold $COVERAGE_THRESHOLD%"
fi
if [[ "$COVERAGE_BASELINE_PASS" == "false" ]]; then
  VERDICT="FAIL"
  REASON="${REASON:+$REASON; }coverage $COVERAGE_PCT% regressed > 2% from baseline $COVERAGE_BASELINE%"
fi
if [[ "${LINT_ERRORS:-0}" -gt 0 ]]; then
  VERDICT="FAIL"
  REASON="${REASON:+$REASON; }$LINT_ERRORS lint errors"
fi
if [[ "${TYPECHECK_ERRORS:-0}" -gt 0 ]]; then
  VERDICT="FAIL"
  REASON="${REASON:+$REASON; }$TYPECHECK_ERRORS typecheck errors"
fi

# --- v1.0.0 — Security iteration-cap (arXiv 2506.11022) ---
# Read the current iteration_chain from state.md
ITER_COUNT=$(awk '
  /^foundry:/{flag=1; next}
  flag && /^  iteration_chain:/{flag2=1; next}
  flag2 && /^    count:/{sub(/^    count:[[:space:]]*/,""); sub(/[[:space:]]*#.*$/,""); gsub(/[[:space:]]/,""); print; exit}
' "$STATE_FILE" 2>/dev/null)
ITER_COUNT="${ITER_COUNT:-0}"
ITER_FAILURE_ID=$(awk '
  /^foundry:/{flag=1; next}
  flag && /^  iteration_chain:/{flag2=1; next}
  flag2 && /^    current_failure_id:/{sub(/^    current_failure_id:[[:space:]]*/,""); sub(/[[:space:]]*#.*$/,""); gsub(/^"|"$/,""); gsub(/[[:space:]]/,""); print; exit}
' "$STATE_FILE" 2>/dev/null)
# Default cap is 3 consecutive LLM-only failures on the same failure_id
ITER_CAP="${FOUNDRY_ITER_CAP:-3}"

if [[ "$VERDICT" == "PASS" ]]; then
  # On pass: reset iteration_chain (count -> 0, current_failure_id -> null)
  NEW_COUNT=0
  NEW_FAILURE_ID="null"
  TMP="$(mktemp)"
  awk '
    /^foundry:/{flag=1}
    flag && /^  iteration_chain:/{flag2=1}
    flag2 && /^    count:/{print "    count: 0"; next}
    flag2 && /^    current_failure_id:/{print "    current_failure_id: null"; next}
    {print}
  ' "$STATE_FILE" > "$TMP" && mv "$TMP" "$STATE_FILE"
else
  # On fail: compute new failure_id (hash of ticket + first failing test name)
  # First failing test name: extract from log if possible, else use ticket
  FIRST_FAILING_TEST="$TICKET:unknown_test"
  if [[ -f "$LOG_FILE" ]]; then
    # jest: "FAIL src/foo.test.ts > suite > test name"
    # pytest: "FAILED tests/test_foo.py::test_bar"
    # go test: "--- FAIL: TestName"
    JEST_FAIL=$(grep -oE '✕\s+[^[:space:]]+(\s+[a-zA-Z][^[:space:]]+)*' "$LOG_FILE" 2>/dev/null | head -1 | sed 's/✕//' | tr ' ' '_' | tr -d '"' | tr -d "'" | head -c 80 || true)
    PYTEST_FAIL=$(grep -oE 'FAILED [^:]+::[^[:space:]]+' "$LOG_FILE" 2>/dev/null | head -1 | sed 's/FAILED //' || true)
    GO_FAIL=$(grep -oE '--- FAIL: [A-Za-z0-9_]+' "$LOG_FILE" 2>/dev/null | head -1 | sed 's/--- FAIL: //' || true)
    DETECTED="${JEST_FAIL:-${PYTEST_FAIL:-${GO_FAIL:-}}}"
    if [[ -n "$DETECTED" ]]; then
      FIRST_FAILING_TEST="$TICKET:$DETECTED"
    fi
  fi
  # Hash for stable comparison (use shasum; fall back to md5; fall back to plain text)
  FAILURE_HASH=""
  if command -v shasum >/dev/null 2>&1; then
    FAILURE_HASH=$(printf '%s' "$FIRST_FAILING_TEST" | shasum -a 256 2>/dev/null | cut -c1-12 || true)
  fi
  if [[ -z "$FAILURE_HASH" ]] && command -v md5 >/dev/null 2>&1; then
    FAILURE_HASH=$(printf '%s' "$FIRST_FAILING_TEST" | md5 2>/dev/null | cut -c1-12 || true)
  fi
  if [[ -z "$FAILURE_HASH" ]]; then
    FAILURE_HASH="$FIRST_FAILING_TEST"
  fi
  if [[ "$ITER_FAILURE_ID" == "$FAILURE_HASH" ]]; then
    # Same failure — increment count
    NEW_COUNT=$((ITER_COUNT + 1))
  else
    # Different failure — reset
    NEW_COUNT=1
  fi
  NEW_FAILURE_ID="\"$FAILURE_HASH\""
  # Check cap
  if [[ "$NEW_COUNT" -ge "$ITER_CAP" ]]; then
    VERDICT="ITERATION_CAP"
    REASON="${REASON:+$REASON; }iteration_cap_exceeded: $NEW_COUNT consecutive failures on $FAILURE_HASH (cap=$ITER_CAP). Stop and request human review via /foundry-signoff."
  fi
  # Update state.md
  TMP="$(mktemp)"
  awk -v new_count="$NEW_COUNT" -v new_id="$NEW_FAILURE_ID" '
    /^foundry:/{flag=1}
    flag && /^  iteration_chain:/{flag2=1}
    flag2 && /^    count:/{print "    count: " new_count; next}
    flag2 && /^    current_failure_id:/{print "    current_failure_id: " new_id; next}
    {print}
  ' "$STATE_FILE" > "$TMP" && mv "$TMP" "$STATE_FILE"
fi

# --- Emit JSON ---
JSON=$(cat <<EOF
{"ticket":"$TICKET","commit":"$COMMIT","scope":"$EFFECTIVE_SCOPE","cmd":"$RUN_CMD","started_at":"$TS_START","finished_at":"$TS_END","duration_s":$DURATION,"tests_run":$TESTS_RUN,"passed":$PASSED,"failed":$FAILED,"skipped":$SKIPPED,"coverage_pct":${COVERAGE_PCT:-null},"coverage_baseline":${COVERAGE_BASELINE:-null},"coverage_threshold":${COVERAGE_THRESHOLD:-0},"coverage_pass":$COVERAGE_PASS,"coverage_baseline_pass":$COVERAGE_BASELINE_PASS,"lint_errors":$LINT_ERRORS,"typecheck_errors":$TYPECHECK_ERRORS,"exit_code":$EXIT_CODE,"log_path":"$LOG_FILE","verdict":"$VERDICT","reason":"$REASON","iteration_chain":{"count":$NEW_COUNT,"current_failure_id":$NEW_FAILURE_ID,"cap":$ITER_CAP}}
EOF
)
echo "$JSON"

# Cache (v1.0.0 — write defensively; old code crashed on shell metacharacters in RUN_CMD)
if [[ "$CACHE_BY_COMMIT" == "true" ]]; then
  mkdir -p "$TEST_RUNS_DIR/.cache" 2>/dev/null || true
  echo "$JSON" | (cat > "$CACHE_FILE" 2>/dev/null) || true
fi

# Update story frontmatter
STORY_FILE="$FOUNDRY_DIR/plan/stories/$TICKET.md"
if [[ -f "$STORY_FILE" ]]; then
  TS_NOW="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  TMP="$(mktemp)"
  awk -v json="$JSON" -v ts="$TS_NOW" -v ticket="$TICKET" '
    /^test_results:/ { in_tr=1; print; next }
    in_tr && /^  last_run:/ { print "  last_run: \"" ts "\""; next }
    in_tr && /^  passed:/ { match($0, /[0-9]+/); print "  passed: " substr($0, RSTART, RLENGTH); next }
    in_tr && /^  failed:/ { match($0, /[0-9]+/); print "  failed: " substr($0, RSTART, RLENGTH); next }
    in_tr && /^  skipped:/ { match($0, /[0-9]+/); print "  skipped: " substr($0, RSTART, RLENGTH); next }
    in_tr && /^  coverage_pct:/ { print "  coverage_pct: " (match($0, /[0-9.]+/) ? substr($0, RSTART, RLENGTH) : "null"); next }
    in_tr && /^  lint_errors:/ { match($0, /[0-9]+/); print "  lint_errors: " substr($0, RSTART, RLENGTH); next }
    in_tr && /^  typecheck_errors:/ { match($0, /[0-9]+/); print "  typecheck_errors: " substr($0, RSTART, RLENGTH); next }
    { print }
  ' "$STORY_FILE" > "$TMP" || true
  mv "$TMP" "$STORY_FILE"
fi

# Exit code reflects verdict
if [[ "$VERDICT" == "PASS" ]]; then exit 0; else exit 1; fi