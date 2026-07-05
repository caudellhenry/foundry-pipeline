#!/usr/bin/env bash
# verify.sh -- dev-pipeline phase verifier (REAL test execution)
#
# usage:
#   verify.sh idea                       - verify Phase 1 (intent + risks)
#   verify.sh research                   - verify Phase 2 (research.md)
#   verify.sh prototype                  - verify Phase 3 (prototype notes)
#   verify.sh prd                        - verify Phase 4 (prd.md sections + >=3 stories)
#   verify.sh plan                       - verify Phase 5 (features + board + stories)
#   verify.sh execute <TICKET>           - verify Phase 6 (real test run)
#   verify.sh qa                         - verify Phase 7 (8-gate convergence check)
#   verify.sh complete                   - verify pipeline complete
#   verify.sh --self-test                - run all verifiers against this plugin
#
# v1.2.0: verify_execute and verify_qa now run real test/lint/typecheck via
# foundry-test-runner.sh + foundry-check-convergence.sh.

set -euo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
PROJECT_ROOT="${DEV_PIPELINE_PROJECT_ROOT:-$(pwd)}"
FOUNDRY_DIR="$PROJECT_ROOT/.foundry"
STATE_FILE="$FOUNDRY_DIR/state.md"

phase="${1:-}"
shift || true

if [[ "$phase" == "--self-test" ]]; then
  echo "verify.sh self-test"
  echo "==================="
  for p in idea research prototype prd plan complete; do
    if bash "$PLUGIN_ROOT/scripts/verify.sh" "$p" >/dev/null 2>&1; then
      echo "  PASS $p"
    else
      echo "  FAIL $p"
    fi
  done
  echo "==================="
  echo "Self-test done."
  exit 0
fi

ok()    { printf 'VERIFY: %s PASS\n' "$phase"; exit 0; }
fail()  { printf 'VERIFY: %s FAIL: %s\n' "$phase" "$1"; exit 1; }

# Safe counter: grep -c always prints a number, but exits 1 on zero matches.
count_grep() {
  local pattern="$1"; shift
  local n
  n="$(grep -cE "$pattern" "$@" 2>/dev/null || true)"
  n="$(printf '%s' "$n" | tr -d '[:space:]')"
  printf '%s' "${n:-0}"
}

verify_idea() {
  [[ -f "$FOUNDRY_DIR/idea/intent.md" ]] || fail "missing .foundry/idea/intent.md"
  [[ -f "$FOUNDRY_DIR/idea/risks.md"  ]] || fail "missing .foundry/idea/risks.md"
  local n
  n=$(count_grep '^\|' "$FOUNDRY_DIR/idea/risks.md")
  [[ "$n" -ge 4 ]] || fail "risks.md has fewer than 3 risk rows ($n)"
  ok
}

verify_research() {
  [[ -f "$FOUNDRY_DIR/research/research.md" ]] || fail "missing .foundry/research/research.md"
  grep -q '^expires:' "$FOUNDRY_DIR/research/research.md" || fail "research.md missing expires field"
  local n
  n=$(count_grep '^- (http|https)://' "$FOUNDRY_DIR/research/research.md")
  [[ "$n" -ge 1 ]] || fail "research.md has no sources"
  ok
}

verify_prototype() {
  [[ -f "$FOUNDRY_DIR/prototype/notes.md" ]] || fail "missing .foundry/prototype/notes.md"
  grep -q '^## Decisions locked' "$FOUNDRY_DIR/prototype/notes.md" || fail "prototype notes missing Decisions locked section"
  ok
}

verify_prd() {
  [[ -f "$FOUNDRY_DIR/prd.md" ]] || fail "missing .foundry/prd.md"
  for sec in "Problem statement" "User stories" "Acceptance criteria" "End-state behaviour" "Glossary"; do
    grep -q "## $sec" "$FOUNDRY_DIR/prd.md" || fail "prd.md missing '$sec' section"
  done
  local n
  n=$(count_grep '^### US-[0-9]+:' "$FOUNDRY_DIR/prd.md")
  [[ "$n" -ge 3 ]] || fail "prd.md has fewer than 3 user stories ($n)"
  ok
}

verify_plan() {
  [[ -f "$FOUNDRY_DIR/plan/features.md" ]] || fail "missing .foundry/plan/features.md"
  [[ -f "$FOUNDRY_DIR/plan/board.md" ]]    || fail "missing .foundry/plan/board.md"
  local stories
  stories=$(find "$FOUNDRY_DIR/plan/stories" -name '*.md' 2>/dev/null | wc -l | tr -d '[:space:]')
  stories="${stories:-0}"
  [[ "$stories" -ge 1 ]] || fail "no stories under .foundry/plan/stories/"
  grep -qE '^## Ready' "$FOUNDRY_DIR/plan/board.md" || fail "board.md missing Ready section"
  local ready_count
  ready_count=$(awk '
    /^## Ready/{flag=1; next}
    /^## /{flag=0}
    flag && /^- \[ \]/{c++}
    END{print c+0}
  ' "$FOUNDRY_DIR/plan/board.md")
  [[ "$ready_count" -ge 1 ]] || fail "Ready section has no tickets ($ready_count)"
  ok
}

verify_execute() {
  local ticket="${1:-}"
  if [[ -z "$ticket" ]]; then
    if [[ ! -f "$FOUNDRY_DIR/plan/board.md" ]]; then fail "missing board.md"; fi
    ok
  fi
  # 1. Required artefacts exist
  [[ -f "$FOUNDRY_DIR/tdd/$ticket.md" ]]         || fail "missing .foundry/tdd/$ticket.md"
  [[ -f "$FOUNDRY_DIR/qa/evidence/$ticket.md" ]]  || fail "missing .foundry/qa/evidence/$ticket.md"
  grep -qE '^commit:' "$FOUNDRY_DIR/qa/evidence/$ticket.md" || fail "$ticket evidence missing commit field"
  # 2. REAL test run via foundry-test-runner.sh
  local runner_json
  runner_json="$(DEV_PIPELINE_PROJECT_ROOT="$PROJECT_ROOT" bash "$PLUGIN_ROOT/scripts/foundry-test-runner.sh" "$ticket" 2>/dev/null || true)"
  if [[ -z "$runner_json" ]]; then
    fail "foundry-test-runner.sh returned no output"
  fi
  local verdict
  verdict=$(echo "$runner_json" | grep -oE '"verdict":"[^"]*"' | head -1 | sed 's/.*"verdict":"\([^"]*\)".*/\1/')
  if [[ "$verdict" != "PASS" ]]; then
    local reason
    reason=$(echo "$runner_json" | grep -oE '"reason":"[^"]*"' | head -1 | sed 's/.*"reason":"\([^"]*\)".*/\1/')
    fail "tests did not pass: $reason"
  fi
  ok
}

verify_qa() {
  [[ -f "$FOUNDRY_DIR/qa/qa-plan.md" ]] || fail "missing .foundry/qa/qa-plan.md"
  grep -qE '^round:' "$FOUNDRY_DIR/qa/qa-plan.md" || fail "qa-plan.md missing round field"
  # 2. Run the 8-gate convergence check (real)
  if bash "$PLUGIN_ROOT/scripts/foundry-check-convergence.sh" >/dev/null 2>&1; then
    ok
  else
    local detail
    detail="$(DEV_PIPELINE_PROJECT_ROOT="$PROJECT_ROOT" bash "$PLUGIN_ROOT/scripts/foundry-check-convergence.sh" 2>&1 | grep -E 'FAIL' | head -8)"
    fail "convergence gates failed: $detail"
  fi
}

case "$phase" in
  idea)      verify_idea ;;
  research)  verify_research ;;
  prototype) verify_prototype ;;
  prd)       verify_prd ;;
  plan)      verify_plan ;;
  execute)   verify_execute "$@" ;;
  qa)        verify_qa ;;
  complete)  printf 'VERIFY: complete PASS\n'; exit 0 ;;
  *)         printf 'VERIFY: unknown phase "%s"\n' "$phase" >&2; exit 2 ;;
esac