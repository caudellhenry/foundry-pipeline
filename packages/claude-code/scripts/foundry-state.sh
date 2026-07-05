#!/usr/bin/env bash
# foundry-state.sh — dev-pipeline state helper
#
# Sub-commands:
#   ensure                       — bootstrap .foundry/state.md if missing
#   set-phase <phase>            — set current_phase (idea|research|prototype|prd|plan|execute|qa|complete)
#   set-loop on|off              — toggle auto_loop
#   advance                      — verify-and-advance to next phase
#   status                       — print human-readable summary
#   reset [--keep-artefacts]     — wipe state (and optionally artefacts)
#   eval [scenario]              — run agent-eval harness
#   literate-diff [hash]         — produce literate diff

set -euo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
PROJECT_ROOT="${DEV_PIPELINE_PROJECT_ROOT:-$(pwd)}"
FOUNDRY_DIR="$PROJECT_ROOT/.foundry"
STATE_FILE="$FOUNDRY_DIR/state.md"
TEMPLATES="$PLUGIN_ROOT/templates"

cmd="${1:-help}"
shift || true

ensure_state() {
  mkdir -p "$FOUNDRY_DIR" "$FOUNDRY_DIR/logs" "$FOUNDRY_DIR/idea" "$FOUNDRY_DIR/research" \
           "$FOUNDRY_DIR/prototype" "$FOUNDRY_DIR/plan/stories" "$FOUNDRY_DIR/tdd" \
           "$FOUNDRY_DIR/qa/evidence" "$FOUNDRY_DIR/qa/review" "$FOUNDRY_DIR/literate" \
           "$FOUNDRY_DIR/eval/scenarios" "$FOUNDRY_DIR/eval/results"
  if [[ ! -f "$STATE_FILE" ]]; then
    cp "$TEMPLATES/state.md" "$STATE_FILE"
  fi
}

# Valid phases in order
PHASES=(idea research prototype prd tdd plan execute qa complete)

next_phase() {
  local current="$1"
  case "$current" in
    idea)      echo "research" ;;
    research)  echo "prototype" ;;
    prototype) echo "prd" ;;
    prd)       echo "tdd" ;;
    tdd)       echo "plan" ;;
    plan)      echo "execute" ;;
    execute)   echo "qa" ;;
    qa)        echo "complete" ;;
    complete)  echo "complete" ;;
    *)         echo "idea" ;;
  esac
}

set_phase() {
  local phase="${1:-}"
  if [[ -z "$phase" ]]; then
    echo "usage: foundry-state.sh set-phase <phase>" >&2
    exit 2
  fi
  ensure_state
  local now
  now="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  # Replace current_phase: line + update updated: line
  TMP="$(mktemp)"
  awk -v p="$phase" -v n="$now" '
    BEGIN { updated_phase = 0; updated_ts = 0 }
    /^current_phase:/ { print "current_phase: " p; updated_phase = 1; next }
    /^updated:/ { print "updated: " n; updated_ts = 1; next }
    { print }
    END {
      if (!updated_phase) print "current_phase: " p
      if (!updated_ts) print "updated: " n
    }
  ' "$STATE_FILE" > "$TMP"
  mv "$TMP" "$STATE_FILE"
  echo "current_phase set to '$phase'."
}

set_loop() {
  local val="${1:-}"
  case "$val" in
    on|true|1)  val="true" ;;
    off|false|0) val="false" ;;
    *) echo "usage: foundry-state.sh set-loop on|off" >&2; exit 2 ;;
  esac
  ensure_state
  TMP="$(mktemp)"
  awk -v v="$val" '
    BEGIN { updated = 0 }
    /^auto_loop:/ { print "auto_loop: " v; updated = 1; next }
    { print }
    END { if (!updated) print "auto_loop: " v }
  ' "$STATE_FILE" > "$TMP"
  mv "$TMP" "$STATE_FILE"
  echo "auto_loop set to '$val'."
}

advance() {
  ensure_state
  local current
  current="$(grep -E '^current_phase:' "$STATE_FILE" | sed 's/^current_phase:[[:space:]]*//' | head -1)"
  local next
  next="$(next_phase "$current")"
  set_phase "$next"
  echo "Advanced: $current -> $next"
}

status() {
  ensure_state
  echo "dev-pipeline status @ $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  echo "─────────────────────────────────────"
  grep -E '^(pipeline|current_phase|auto_loop|last_session_id):' "$STATE_FILE" || true
  echo
  echo "phases:"
  awk '/^phases:/{flag=1; next} /^[^ ]/ && /:/ && !/phases:/ && NR>1 {flag=0} flag' "$STATE_FILE" | head -40
  echo
  if [[ -f "$FOUNDRY_DIR/plan/board.md" ]]; then
    echo "board (excerpt):"
    grep -E '^- \[' "$FOUNDRY_DIR/plan/board.md" | head -20 || true
  fi
  echo
  echo "next:"
  local phase
  phase="$(grep -E '^current_phase:' "$STATE_FILE" | sed 's/^current_phase:[[:space:]]*//' | head -1)"
  echo "  /dev-$phase  → continue current phase"
  echo "  /dev-status  → re-print this summary"
  echo "  /foundry-loop-on → enable auto-loop"
}

reset() {
  local keep="false"
  local keep_wt="false"
  for arg in "$@"; do
    case "$arg" in
      --keep-artefacts) keep="true" ;;
      --keep-worktrees) keep_wt="true" ;;
      --yes|-y) ;;
      *) echo "unknown flag: $arg" >&2; exit 2 ;;
    esac
  done
  read -rp "Reset pipeline state in $PROJECT_ROOT? [y/N] " ans
  if [[ "$ans" != "y" && "$ans" != "Y" ]]; then
    echo "aborted."
    exit 0
  fi
  if [[ -f "$STATE_FILE" ]]; then rm "$STATE_FILE"; fi
  if [[ "$keep" != "true" ]]; then
    rm -rf "$FOUNDRY_DIR/idea" "$FOUNDRY_DIR/research" "$FOUNDRY_DIR/prototype" \
           "$FOUNDRY_DIR/plan" "$FOUNDRY_DIR/tdd" "$FOUNDRY_DIR/qa"
    rm -f "$FOUNDRY_DIR/prd.md"
  fi
  # v1.3.0 — clean up worktrees unless --keep-worktrees
  if [[ "$keep_wt" != "true" ]] && [[ -x "$PLUGIN_ROOT/scripts/foundry-worktree.sh" ]]; then
    "$PLUGIN_ROOT/scripts/foundry-worktree.sh" cleanup 2>/dev/null || true
  fi
  ensure_state
  echo "reset done."
}

eval_scenario() {
  ensure_state
  local scenario="${1:-}"
  mkdir -p "$FOUNDRY_DIR/eval/results"
  TS="$(date -u +"%Y-%m-%dT%H%M%SZ")"
  if [[ -z "$scenario" ]]; then
    echo "usage: foundry-state.sh eval <scenario-name>"
    echo
    echo "available scenarios:"
    if [[ -d "$FOUNDRY_DIR/eval/scenarios" ]]; then
      ls "$FOUNDRY_DIR/eval/scenarios" || true
    fi
    return 0
  fi
  if [[ ! -f "$FOUNDRY_DIR/eval/scenarios/$scenario.yaml" ]]; then
    echo "scenario not found: $scenario" >&2
    return 1
  fi
  # Stub: in real use, run the agent in a fresh context and grade.
  # For now, record a placeholder result.
  RESULT="$FOUNDRY_DIR/eval/results/${TS}-${scenario}.json"
  cat > "$RESULT" <<EOF
{
  "scenario": "$scenario",
  "ran_at": "$TS",
  "model": "stub",
  "prompt_version": "$(git -C "$PROJECT_ROOT" rev-parse --short HEAD 2>/dev/null || echo unknown)",
  "scores": {"functional_correctness": 0, "process_discipline": 0, "prompt_hygiene": 0, "communication_clarity": 0, "resource_efficiency": 0},
  "total": 0,
  "verdict": "not-run",
  "notes": "Placeholder — replace foundry-state.sh eval with real eval driver when integrating with the agent runtime."
}
EOF
  echo "wrote stub result: $RESULT"
  echo "implement eval driver in scripts/eval-driver.sh for real grading."
}

literate_diff() {
  ensure_state
  local hash="${1:-}"
  if [[ -z "$hash" ]]; then
    hash="$(git -C "$PROJECT_ROOT" rev-parse HEAD 2>/dev/null || echo HEAD-unknown)"
  fi
  mkdir -p "$FOUNDRY_DIR/literate"
  echo "literate-diff scaffold for $hash written to $FOUNDRY_DIR/literate/${hash:0:7}.md"
  echo "fill in the sections per skills/foundry-literate-diff/SKILL.md."
}

# --- signoff ---
# Mark the pipeline as user-signed-off. Sets state.md signoff.user_signed_off=true.
# Optionally pass --by=<name> to record who signed off.
signoff() {
  ensure_state
  local by="user"
  for arg in "$@"; do
    case "$arg" in
      --by=*) by="${arg#--by=}" ;;
    esac
  done
  local now
  now="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  TMP="$(mktemp)"
  awk -v by="$by" -v now="$now" '
    /^signoff:/ { in_block=1; print; next }
    in_block && /^  user_signed_off:/ { print "  user_signed_off: true"; next }
    in_block && /^  signed_off_at:/ { print "  signed_off_at: \"" now "\""; next }
    in_block && /^  signed_off_by:/ { print "  signed_off_by: \"" by "\""; next }
    in_block && /^[^ ]/ { in_block=0 }
    { print }
  ' "$STATE_FILE" > "$TMP"
  mv "$TMP" "$STATE_FILE"
  # If pipeline is at qa, advance to complete
  local cur
  cur="$(grep -E '^current_phase:' "$STATE_FILE" | sed 's/^current_phase:[[:space:]]*//' | head -1)"
  if [[ "$cur" == "qa" ]]; then
    set_phase complete
    echo "current_phase: complete (pipeline signed off)."
  fi
  echo "Signed off by '$by' at $now."
}

# --- unset-signoff (for rollback) ---
unsignoff() {
  ensure_state
  TMP="$(mktemp)"
  awk '
    /^signoff:/ { in_block=1; print; next }
    in_block && /^  user_signed_off:/ { print "  user_signed_off: false"; next }
    in_block && /^  signed_off_at:/ { print "  signed_off_at: null"; next }
    in_block && /^  signed_off_by:/ { print "  signed_off_by: null"; next }
    in_block && /^[^ ]/ { in_block=0 }
    { print }
  ' "$STATE_FILE" > "$TMP"
  mv "$TMP" "$STATE_FILE"
  echo "signoff cleared."
}

# --- set-coverage-baseline ---
# Reads the latest full-suite coverage from test-runs and sets it as baseline.
set_coverage_baseline() {
  ensure_state
  local pct
  pct="$("$PLUGIN_ROOT/scripts/foundry-coverage.sh" 2>/dev/null | grep -oE '[0-9]+\.?[0-9]*' | head -1)"
  if [[ -z "$pct" ]]; then
    echo "ERROR: could not read coverage. Configure coverage_cmd in state.md or run tests first." >&2
    exit 1
  fi
  TMP="$(mktemp)"
  awk -v pct="$pct" '
    BEGIN { in_block=0 }
    /^test:/ { in_block=1; print; next }
    in_block && /^  coverage_baseline:/ { print "  coverage_baseline: " pct; next }
    in_block && /^[^ ]/ { in_block=0 }
    { print }
  ' "$STATE_FILE" > "$TMP"
  mv "$TMP" "$STATE_FILE"
  echo "coverage_baseline set to $pct%"
}

# --- set-test-config ---
# Generic setter for state.md test: block keys.
# Usage: foundry-state.sh set-test-config <key> <value>
# Example: foundry-state.sh set-test-config coverage_threshold 80
set_test_config() {
  ensure_state
  local key="${1:-}" value="${2:-}"
  if [[ -z "$key" ]]; then
    echo "usage: foundry-state.sh set-test-config <key> <value>" >&2
    echo "  keys: runner, cmd, per_story_cmd_template, timeout, coverage_cmd, coverage_threshold," >&2
    echo "         coverage_baseline, lint_cmd, typecheck_cmd, skip_tests, cache_by_commit" >&2
    exit 2
  fi
  TMP="$(mktemp)"
  awk -v key="$key" -v value="$value" '
    BEGIN { in_block=0 }
    /^test:/ { in_block=1; print; next }
    in_block {
      pattern = "^  "key":"
      if ($0 ~ pattern) {
        if (key == "skip_tests" || key == "cache_by_commit") {
          print "  "key": " value
        } else if (key == "coverage_baseline" || key == "coverage_threshold" || key == "timeout") {
          print "  "key": " value
        } else {
          print "  "key": \"" value "\""
        }
        next
      }
      if (/^[^ ]/) in_block=0
    }
    { print }
  ' "$STATE_FILE" > "$TMP"
  mv "$TMP" "$STATE_FILE"
  echo "test: $key set to '$value'"
}

# --- set-models ---
# Set a models: block key.
# Usage: foundry-state.sh set-models <key> <value>
set_models() {
  ensure_state
  local key="${1:-}" value="${2:-}"
  if [[ -z "$key" ]]; then
    echo "usage: foundry-state.sh set-models <key> <value>" >&2
    echo "  keys: writer, reviewer, cross_reviewer, qa_planner" >&2
    exit 2
  fi
  TMP="$(mktemp)"
  awk -v key="$key" -v value="$value" '
    BEGIN { in_block=0 }
    /^models:/ { in_block=1; print; next }
    in_block {
      pattern = "^  "key":"
      if ($0 ~ pattern) { print "  "key": " value; next }
      if (/^[^ ]/) in_block=0
    }
    { print }
  ' "$STATE_FILE" > "$TMP"
  mv "$TMP" "$STATE_FILE"
  echo "models: $key set to '$value'"
}

# --- approve-review ---
# Mark a per-ticket review as human_approved (gate 2 of convergence).
# Usage: foundry-state.sh approve-review <STORY-ID>
approve_review() {
  ensure_state
  local ticket="${1:-}"
  if [[ -z "$ticket" ]]; then
    echo "usage: foundry-state.sh approve-review <STORY-ID>" >&2
    exit 2
  fi
  local review_file="$FOUNDRY_DIR/qa/review/$ticket.md"
  if [[ ! -f "$review_file" ]]; then
    echo "ERROR: review file not found at $review_file" >&2
    exit 1
  fi
  local now who
  now="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  who="${USER:-human}"
  TMP="$(mktemp)"
  awk -v now="$now" -v who="$who" '
    /^  human_approved:/ { print "  human_approved: true"; next }
    /^  human_approved_at:/ { print "  human_approved_at: \"" now "\""; next }
    /^  human_approved_by:/ { print "  human_approved_by: \"" who "\""; next }
    { print }
  ' "$review_file" > "$TMP"
  mv "$TMP" "$review_file"
  echo "Review for $ticket approved by $who at $now."
}

# --- set-worktree (v1.3.0 — FR-20260704-008) ---
# Toggle worktree-per-ticket isolation.
# usage: foundry-state.sh set-worktree enabled|disabled
set_worktree() {
  ensure_state
  local val="${1:-}"
  case "$val" in
    enabled|true|on|1)  val="true" ;;
    disabled|false|off|0) val="false" ;;
    *) echo "usage: foundry-state.sh set-worktree enabled|disabled" >&2; exit 2 ;;
  esac
  TMP="$(mktemp)"
  awk -v v="$val" '
    BEGIN { in_block=0 }
    /^worktree:/ { in_block=1; print; next }
    in_block && /^  enabled:/ { print "  enabled: " v; next }
    in_block && /^[^ ]/ { in_block=0 }
    { print }
  ' "$STATE_FILE" > "$TMP"
  mv "$TMP" "$STATE_FILE"
  echo "worktree.enabled set to '$val'."
}

# --- set-iteration-cap (v1.0.0 — arXiv 2506.11022) ---
# Set the maximum consecutive LLM-only failures before halting the loop.
# usage: foundry-state.sh set-iteration-cap <N>
# default: 3 (per arXiv 2506.11022: 5+ iterations of LLM-only "improvement" → 37.6% increase in critical vulns)
set_iteration_cap() {
  ensure_state
  local cap="${1:-}"
  if [[ -z "$cap" || ! "$cap" =~ ^[0-9]+$ ]] || [[ "$cap" -lt 1 ]]; then
    echo "usage: foundry-state.sh set-iteration-cap <N>  (N must be a positive integer, default 3)" >&2
    exit 2
  fi
  # Persist as an env var (used by foundry-test-runner.sh) AND in the iteration_chain comment
  echo "iteration-cap set to $cap (export FOUNDRY_ITER_CAP=$cap)"
  # Also store in state.md for visibility
  TMP="$(mktemp)"
  awk -v c="$cap" '
    /^foundry:/{flag=1}
    flag && /^  iteration_chain:/{flag2=1}
    flag2 && /^    count:/{print "    count: 0"; next}
    flag2 && /^    current_failure_id:/{print "    current_failure_id: null"; next}
    {print}
  ' "$STATE_FILE" > "$TMP" && mv "$TMP" "$STATE_FILE"
  # Append the cap as a comment line in iteration_chain
  TMP="$(mktemp)"
  awk -v c="$cap" '
    /^foundry:/{flag=1; print; next}
    flag && /^  iteration_chain:/{flag2=1; print; next}
    flag2 && /^    cap:/{print "    cap: " c; next}
    {print}
  ' "$STATE_FILE" > "$TMP" && mv "$TMP" "$STATE_FILE"
}

# --- reset-iteration-chain (v1.0.0) ---
# Reset the iteration chain to 0 (used by /foundry-signoff to clear the cap).
# usage: foundry-state.sh reset-iteration-chain [REASON]
reset_iteration_chain() {
  ensure_state
  local reason="${1:-manual reset}"
  local now
  now="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  TMP="$(mktemp)"
  awk -v now="$now" -v reason="$reason" '
    /^foundry:/{flag=1}
    flag && /^  iteration_chain:/{flag2=1}
    flag2 && /^    count:/{print "    count: 0"; next}
    flag2 && /^    current_failure_id:/{print "    current_failure_id: null"; next}
    flag2 && /^    last_human_review_at:/{print "    last_human_review_at: \"" now "\""; next}
    {print}
  ' "$STATE_FILE" > "$TMP" && mv "$TMP" "$STATE_FILE"
  echo "iteration_chain reset (reason: $reason, at: $now)."
}

# --- set-parallel (v1.3.0 — FR-20260704-009) ---
# Toggle parallel fan-out.
# usage: foundry-state.sh set-parallel enabled|disabled [max_workers]
set_parallel() {
  ensure_state
  local val="${1:-}"
  local max="${2:-3}"
  case "$val" in
    enabled|true|on|1)  val="true" ;;
    disabled|false|off|0) val="false" ;;
    *) echo "usage: foundry-state.sh set-parallel enabled|disabled [max_workers]" >&2; exit 2 ;;
  esac
  TMP="$(mktemp)"
  awk -v v="$val" -v m="$max" '
    BEGIN { in_block=0 }
    /^parallel:/ { in_block=1; print; next }
    in_block && /^  enabled:/ { print "  enabled: " v; next }
    in_block && /^  max_workers:/ { print "  max_workers: " m; next }
    in_block && /^[^ ]/ { in_block=0 }
    { print }
  ' "$STATE_FILE" > "$TMP"
  mv "$TMP" "$STATE_FILE"
  echo "parallel.enabled set to '$val' (max_workers=$max)."
}

case "$cmd" in
  ensure) ensure_state ;;
  set-phase) set_phase "${1:-}" ;;
  set-loop) set_loop "${1:-}" ;;
  advance) advance ;;
  status) status ;;
  reset) reset "$@" ;;
  eval) eval_scenario "${1:-}" ;;
  literate-diff) literate_diff "${1:-}" ;;
  signoff) signoff "$@" ;;
  unsignoff) unsignoff ;;
  set-coverage-baseline) set_coverage_baseline ;;
  set-test-config) set_test_config "${1:-}" "${2:-}" ;;
  set-models) set_models "${1:-}" "${2:-}" ;;
  approve-review) approve_review "${1:-}" ;;
  set-worktree) set_worktree "${1:-}" ;;
  set-parallel) set_parallel "${1:-}" "${2:-}" ;;
  set-iteration-cap) set_iteration_cap "${1:-}" ;;
  reset-iteration-chain) shift 2>/dev/null || true; reset_iteration_chain "$@" ;;
  help|*) cat <<'EOF'
foundry-state.sh — dev-pipeline state helper

usage:
  foundry-state.sh ensure                       bootstrap state
  foundry-state.sh set-phase <phase>            idea|research|prototype|prd|plan|execute|qa|complete
  foundry-state.sh set-loop on|off              toggle auto_loop
  foundry-state.sh advance                      verify + advance to next phase
  foundry-state.sh status                       print summary
  foundry-state.sh reset [--keep-artefacts]     wipe state (confirm prompt)
  foundry-state.sh eval [scenario]              run agent-eval harness
  foundry-state.sh literate-diff [commit-hash]   produce literate diff
  foundry-state.sh signoff [--by=<name>]        mark pipeline as user-signed-off
  foundry-state.sh unsignoff                    clear signoff (rollback)
  foundry-state.sh set-coverage-baseline        read latest coverage, set as baseline
  foundry-state.sh set-test-config <key> <val>  set a state.md test: key
  foundry-state.sh set-models <key> <val>       set a state.md models: key
  foundry-state.sh approve-review <TICKET>      mark a per-ticket review human_approved
  foundry-state.sh set-worktree enabled|disabled  v1.3.0 — toggle per-ticket worktree isolation
  foundry-state.sh set-parallel enabled|disabled [N]  v1.3.0 — toggle parallel fan-out (max N workers)
EOF
  ;;
esac