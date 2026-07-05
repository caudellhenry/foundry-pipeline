#!/usr/bin/env bash
# evals/run.sh — Monorepo-level pass^k eval runner.
#
# Reads YAML scenarios from evals/scenarios/*.yaml, executes each `test_cmd`,
# compares exit code against `expected_exit`, repeats k times, records pass^k.
# Writes per-scenario results JSON to evals/results/.
#
# Usage:
#   bash evals/run.sh                          # all scenarios, k=default (from YAML)
#   bash evals/run.sh --scenario 01-hello      # one scenario
#   bash evals/run.sh --k 3                    # override k for all
#   bash evals/run.sh --list                   # print scenarios + exit
#   bash evals/run.sh --release-check          # exit 1 if any release_gating scenario fails
#   bash evals/run.sh --json                   # machine-readable summary

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCENARIOS_DIR="$REPO_ROOT/evals/scenarios"
RESULTS_DIR="$REPO_ROOT/evals/results"

mkdir -p "$RESULTS_DIR"

SCENARIO_FILTER=""
K_OVERRIDE=""
LIST_ONLY=0
RELEASE_CHECK=0
JSON_OUTPUT=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --scenario) SCENARIO_FILTER="$2"; shift 2 ;;
    --k)        K_OVERRIDE="$2"; shift 2 ;;
    --list)     LIST_ONLY=1; shift ;;
    --release-check) RELEASE_CHECK=1; shift ;;
    --json)     JSON_OUTPUT=1; shift ;;
    *) echo "Unknown flag: $1" >&2; exit 2 ;;
  esac
done

if [[ ! -d "$SCENARIOS_DIR" ]]; then
  echo "No scenarios dir at $SCENARIOS_DIR" >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "jq required." >&2
  exit 1
fi

# List mode
if [[ "$LIST_ONLY" -eq 1 ]]; then
  echo "Scenarios:"
  for f in "$SCENARIOS_DIR"/*.yaml; do
    [[ -f "$f" ]] || continue
    name="$(basename "$f" .yaml)"
    desc="$(grep -E '^description:' "$f" | head -1 | sed 's/description: *//' | tr -d '"')"
    exp="$(grep -E '^expected_exit:' "$f" | head -1 | awk '{print $2}')"
    pk="$(grep -E '^pass_k:' "$f" | head -1 | awk '{print $2}')"
    rg="$(grep -E '^release_gating:' "$f" | head -1 | awk '{print $2}')"
    printf '  %-40s exit=%s k=%s release_gating=%s — %s\n' "$name" "$exp" "$pk" "$rg" "$desc"
  done
  exit 0
fi

declare -i TOTAL=0 PASS=0 FAIL=0 RELEASE_GATING_FAIL=0
declare -a SCENARIO_RESULTS=()

for scenario_file in "$SCENARIOS_DIR"/*.yaml; do
  [[ -f "$scenario_file" ]] || continue
  name="$(basename "$scenario_file" .yaml)"

  if [[ -n "$SCENARIO_FILTER" && "$name" != *"$SCENARIO_FILTER"* ]]; then
    continue
  fi

  TOTAL+=1
  expected_exit="$(grep -E '^expected_exit:' "$scenario_file" | head -1 | awk '{print $2}')"
  expected_exit="${expected_exit:-0}"
  test_cmd="$(awk '/^test_cmd: \|/{flag=1; next} flag && /^[^ ]/{flag=0} flag{print}' "$scenario_file" | sed 's/^  //')"
  pass_k="$(grep -E '^pass_k:' "$scenario_file" | head -1 | awk '{print $2}')"
  pass_k="${pass_k:-1}"
  release_gating="$(grep -E '^release_gating:' "$scenario_file" | head -1 | awk '{print $2}')"
  release_gating="${release_gating:-false}"

  if [[ -n "$K_OVERRIDE" ]]; then
    pass_k="$K_OVERRIDE"
  fi

  if [[ -z "$test_cmd" ]]; then
    echo "  SKIP  $name (no test_cmd)"
    SCENARIO_RESULTS+=("{\"name\":\"$name\",\"verdict\":\"SKIP\",\"reason\":\"no test_cmd\"}")
    continue
  fi

  # Run k times (disable set -u for the eval — user-supplied commands may
  # reference unset variables without quoting, which would otherwise fail on
  # macOS bash 3.2 with nounset).
  declare -i k_pass=0
  for ((i=1; i<=pass_k; i++)); do
    set +u
    if eval "$test_cmd" >/dev/null 2>&1; then
      actual_exit=0
    else
      actual_exit=$?
    fi
    set -u
    if [[ "$actual_exit" == "$expected_exit" ]]; then
      k_pass+=1
    fi
  done

  if [[ "$k_pass" -eq "$pass_k" ]]; then
    verdict="PASS"
    PASS+=1
  else
    verdict="FAIL"
    FAIL+=1
    if [[ "$release_gating" == "true" ]]; then
      RELEASE_GATING_FAIL+=1
    fi
  fi

  ts="$(date -u +%Y%m%dT%H%M%SZ)"
  result_file="$RESULTS_DIR/${ts}-${name}.json"
  {
    echo "{"
    echo "  \"scenario\": \"$name\","
    echo "  \"verdict\": \"$verdict\","
    echo "  \"expected_exit\": $expected_exit,"
    echo "  \"pass_k\": $pass_k,"
    echo "  \"k_pass\": $k_pass,"
    echo "  \"release_gating\": $release_gating,"
    echo "  \"ran_at\": \"$ts\""
    echo "}"
  } > "$result_file"

  SCENARIO_RESULTS+=("{\"name\":\"$name\",\"verdict\":\"$verdict\",\"pass_k\":$pass_k,\"k_pass\":$k_pass,\"release_gating\":$release_gating}")

  if [[ "$JSON_OUTPUT" -eq 0 ]]; then
    printf '  %-7s %-40s k=%d/%d  release_gating=%s\n' "$verdict" "$name" "$k_pass" "$pass_k" "$release_gating"
  fi
done

summary_file="$RESULTS_DIR/$(date -u +%Y%m%dT%H%M%SZ)-summary.json"
{
  echo "{"
  echo "  \"total\": $TOTAL,"
  echo "  \"pass\": $PASS,"
  echo "  \"fail\": $FAIL,"
  echo "  \"release_gating_fail\": $RELEASE_GATING_FAIL,"
  echo "  \"scenarios\": [$(IFS=,; echo "${SCENARIO_RESULTS[*]}")]"
  echo "}"
} > "$summary_file"

if [[ "$JSON_OUTPUT" -eq 1 ]]; then
  cat "$summary_file"
  echo ""
fi

if [[ "$JSON_OUTPUT" -eq 0 ]]; then
  echo ""
  echo "Total: $TOTAL, Pass: $PASS, Fail: $FAIL, Release-gating fails: $RELEASE_GATING_FAIL"
fi

if [[ "$FAIL" -gt 0 && "$RELEASE_CHECK" -eq 1 ]]; then
  echo "RELEASE CHECK FAILED: $RELEASE_GATING_FAIL release-gating scenarios failed."
  exit 1
fi

if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi
exit 0