#!/usr/bin/env bash
# foundry-eval-runner.sh — pass^k eval harness (Anthropic A14)
#
# usage:
#   foundry-eval-runner.sh [--scenario=<name>...] [--k=<N>] [--release-check] [--json]
#   foundry-eval-runner.sh --list
#
# Reads YAML scenario files from evals/scenarios/*.yaml. Each scenario has:
#   task: <description>
#   setup: <bash commands to set up the fixture>
#   test_cmd: <command to run that should pass>
#   expect_exit_code: <0=pass, non-zero=fail>
#   pass_k: <number of consecutive runs required to pass>
#
# Outputs:
#   - Human-readable summary to stdout (or JSON if --json)
#   - Per-scenario results to evals/results/<timestamp>.json
#
# Exit codes:
#   0 — all scenarios pass^k
#   1 — some scenarios failed
#   2 — invocation error
#
# v1.0.0 — foundry

set -euo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
PROJECT_ROOT="${DEV_PIPELINE_PROJECT_ROOT:-$(pwd)}"
FOUNDRY_DIR="$PROJECT_ROOT/.foundry"
SCENARIOS_DIR="$PLUGIN_ROOT/evals/scenarios"
RESULTS_DIR="$FOUNDRY_DIR/eval/results"
mkdir -p "$RESULTS_DIR"

K_DEFAULT=3
SPECIFIC_SCENARIOS=()
JSON_OUT="false"
LIST_ONLY="false"
RELEASE_CHECK="false"

for arg in "$@"; do
  case "$arg" in
    --scenario=*) SPECIFIC_SCENARIOS+=("${arg#--scenario=}") ;;
    --k=*) K_DEFAULT="${arg#--k=}" ;;
    --json) JSON_OUT="true" ;;
    --list) LIST_ONLY="true" ;;
    --release-check) RELEASE_CHECK="true" ;;
    *) echo "usage: foundry-eval-runner.sh [--scenario=<name>...] [--k=<N>] [--release-check] [--json] [--list]" >&2; exit 2 ;;
  esac
done

# Simple YAML parser (key: value lines, no nesting)
# Strips optional surrounding double or single quotes from the value.
parse_yaml() {
  local file="$1"
  awk -F: '
    /^[a-z_]+:/ {
      key = $1
      sub(/^[^:]+:[[:space:]]*/, "")
      # Strip surrounding quotes (avoiding single-quote escape hell by handling both)
      gsub(/^"|"$/, "")           # double quotes
      gsub(/^\x27|\x27$/, "")      # single quotes via octal escape
      print key "\t" $0
    }
  ' "$file"
}

# List scenarios
if [[ "$LIST_ONLY" == "true" ]]; then
  echo "Available scenarios in $SCENARIOS_DIR:"
  for f in "$SCENARIOS_DIR"/*.yaml; do
    [[ -f "$f" ]] || continue
    base=$(basename "$f" .yaml)
    desc=$(awk -F':' '/^task:/{sub(/^task: */, ""); print; exit}' "$f")
    printf "  %-30s %s\n" "$base" "$desc"
  done
  exit 0
fi

# Determine scenarios to run
declare -a TO_RUN=()
if [[ ${#SPECIFIC_SCENARIOS[@]} -gt 0 ]]; then
  TO_RUN=("${SPECIFIC_SCENARIOS[@]}")
else
  for f in "$SCENARIOS_DIR"/*.yaml; do
    [[ -f "$f" ]] || continue
    TO_RUN+=("$(basename "$f" .yaml)")
  done
fi

# Release check filter
if [[ "$RELEASE_CHECK" == "true" ]]; then
  declare -a FILTERED=()
  for s in "${TO_RUN[@]}"; do
    f="$SCENARIOS_DIR/$s.yaml"
    [[ -f "$f" ]] || continue
    is_release=$(awk -F':' '/^release_gating:/{print $2; exit}' "$f")
    if [[ "$is_release" == "true" ]]; then
      FILTERED+=("$s")
    fi
  done
  TO_RUN=("${FILTERED[@]}")
  echo "Release check: ${#TO_RUN[@]} release-gating scenarios"
fi

[[ ${#TO_RUN[@]} -gt 0 ]] || { echo "No scenarios to run." >&2; exit 2; }

TS_START="$(date -u +"%Y%m%dT%H%M%SZ")"
RESULTS_FILE="$RESULTS_DIR/${TS_START}-results.json"

# Run each scenario
declare -a SUMMARY
PASS_COUNT=0
FAIL_COUNT=0
TOTAL_SCENARIOS=${#TO_RUN[@]}

for scenario in "${TO_RUN[@]}"; do
  f="$SCENARIOS_DIR/$scenario.yaml"
  if [[ ! -f "$f" ]]; then
    SUMMARY+=("{\"scenario\":\"$scenario\",\"status\":\"SKIP\",\"reason\":\"file not found\"}")
    FAIL_COUNT=$((FAIL_COUNT + 1))
    continue
  fi

  # Parse
  TASK=$(awk -F':' '/^task:/{sub(/^task: */, ""); print; exit}' "$f")
  TEST_CMD=$(awk -F':' '/^test_cmd:/{sub(/^test_cmd: */, ""); print; exit}' "$f")
  SETUP=$(awk -F':' '/^setup:/{sub(/^setup: */, ""); print; exit}' "$f")
  EXPECT_EXIT=$(awk -F':' '/^expect_exit_code:/{sub(/^expect_exit_code: */, ""); print; exit}' "$f")
  EXPECT_EXIT="${EXPECT_EXIT:-0}"
  PASS_K=$(awk -F':' '/^pass_k:/{sub(/^pass_k: */, ""); print; exit}' "$f")
  PASS_K="${PASS_K:-$K_DEFAULT}"

  if [[ -z "$TEST_CMD" ]]; then
    SUMMARY+=("{\"scenario\":\"$scenario\",\"status\":\"SKIP\",\"reason\":\"no test_cmd\"}")
    continue
  fi

  # Run pass^k trials
  k_pass=0
  for trial in $(seq 1 "$PASS_K"); do
    # Run setup in a temp dir
    TRIAL_DIR="$(mktemp -d)"
    pushd "$TRIAL_DIR" >/dev/null
    if [[ -n "$SETUP" ]]; then
      eval "$SETUP" 2>/dev/null || true
    fi
    # Run the test
    EXIT_CODE=0
    eval "$TEST_CMD" >/dev/null 2>&1 || EXIT_CODE=$?
    popd >/dev/null
    rm -rf "$TRIAL_DIR"

    if [[ "$EXIT_CODE" == "$EXPECT_EXIT" ]]; then
      k_pass=$((k_pass + 1))
    fi
  done

  if [[ "$k_pass" == "$PASS_K" ]]; then
    STATUS="PASS"
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    STATUS="FAIL"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
  SUMMARY+=("{\"scenario\":\"$scenario\",\"status\":\"$STATUS\",\"k_pass\":$k_pass,\"pass_k\":$PASS_K,\"expect_exit_code\":$EXPECT_EXIT,\"task\":\"$TASK\"}")
done

# Output
if [[ "$JSON_OUT" == "true" ]]; then
  echo "{"
  echo "  \"timestamp\": \"$TS_START\","
  echo "  \"scenarios_total\": $TOTAL_SCENARIOS,"
  echo "  \"passed\": $PASS_COUNT,"
  echo "  \"failed\": $FAIL_COUNT,"
  echo "  \"verdict\": \"$([ "$FAIL_COUNT" -eq 0 ] && echo PASS || echo FAIL)\","
  echo "  \"results\": ["
  printf "    %s\n" "${SUMMARY[@]}" | sed 's/$/,/' | sed '$ s/,$//'
  echo "  ]"
  echo "}"
else
  echo "============================================="
  echo "foundry-eval-runner: $TS_START"
  echo "============================================="
  for entry in "${SUMMARY[@]}"; do
    name=$(echo "$entry" | python3 -c "import sys,json; print(json.loads(sys.stdin.read())['scenario'])" 2>/dev/null)
    status=$(echo "$entry" | python3 -c "import sys,json; print(json.loads(sys.stdin.read())['status'])" 2>/dev/null)
    kp=$(echo "$entry" | python3 -c "import sys,json; print(json.loads(sys.stdin.read())['k_pass'])" 2>/dev/null)
    pk=$(echo "$entry" | python3 -c "import sys,json; print(json.loads(sys.stdin.read())['pass_k'])" 2>/dev/null)
    if [[ "$status" == "PASS" ]]; then
      echo "  ✅ $name ($kp/$pk)"
    elif [[ "$status" == "FAIL" ]]; then
      echo "  ❌ $name ($kp/$pk)"
    else
      echo "  ⊘ $name ($status)"
    fi
  done
  echo "---------------------------------------------"
  echo "Total: $TOTAL_SCENARIOS | Passed: $PASS_COUNT | Failed: $FAIL_COUNT"
  echo "Verdict: $([ "$FAIL_COUNT" -eq 0 ] && echo PASS || echo FAIL)"
fi

# Persist results
{
  echo "{"
  echo "  \"timestamp\": \"$TS_START\","
  echo "  \"scenarios_total\": $TOTAL_SCENARIOS,"
  echo "  \"passed\": $PASS_COUNT,"
  echo "  \"failed\": $FAIL_COUNT,"
  echo "  \"verdict\": \"$([ "$FAIL_COUNT" -eq 0 ] && echo PASS || echo FAIL)\","
  echo "  \"results\": ["
  printf "    %s\n" "${SUMMARY[@]}" | sed 's/$/,/' | sed '$ s/,$//'
  echo "  ]"
  echo "}"
} > "$RESULTS_FILE"

# v1.0.0 — Set last-eval-run timestamp via Python (avoids bash quoting hell)
if [[ -d "$FOUNDRY_DIR" && -f "$FOUNDRY_DIR/state.md" ]]; then
  python3 -c "
import re, sys
fp = '$FOUNDRY_DIR/state.md'
with open(fp) as f: content = f.read()
# Find foundry: -> evals: -> last_run: block, replace last_run value
new = re.sub(
    r'(foundry:\n  evals:\n    last_run: )[^\n]*',
    r'\\g<1>\"$TS_START\"',
    content
)
with open(fp, 'w') as f: f.write(new)
" 2>/dev/null || true
fi

[[ "$FAIL_COUNT" -eq 0 ]]
