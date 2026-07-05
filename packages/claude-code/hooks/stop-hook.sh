#!/usr/bin/env bash
# stop-hook.sh — dev-pipeline Stop hook
#
# The main loop driver. Reads .foundry/state.md, decides whether to
# block the agent's exit (to continue the loop) or allow exit.
#
# Behaviour matrix:
#
#   phase         auto_loop=true    auto_loop=false
#   ──────────    ──────────────    ───────────────
#   idea          block (verify)    exit (user resumes)
#   research      block (verify)    exit
#   prototype     block (verify)    exit
#   prd           block (verify)    exit
#   tdd           block (verify)    exit
#   plan          block (verify)    exit
#   execute       block (loop)      exit after current ticket
#   qa            block (loop)      exit after current round
#
#   complete      exit              exit
#
# Verifier: scripts/verify.sh <phase> [args]
# Loop controller: scripts/foundry-loop.sh <phase>

set -euo pipefail

HOOK_INPUT="$(cat)"
SESSION_ID="$(printf '%s' "$HOOK_INPUT" | jq -r '.session_id // ""' 2>/dev/null || true)"

PROJECT_ROOT="${DEV_PIPELINE_PROJECT_ROOT:-$(pwd)}"
FOUNDRY_DIR="$PROJECT_ROOT/.foundry"
STATE_FILE="$FOUNDRY_DIR/state.md"
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"

# Fast path: no state file => nothing to loop on
if [[ ! -f "$STATE_FILE" ]]; then
  exit 0
fi

PHASE="$(grep -E '^current_phase:' "$STATE_FILE" | sed 's/^current_phase:[[:space:]]*//' | head -1)"
AUTO="$(grep -E '^auto_loop:' "$STATE_FILE" | sed 's/^auto_loop:[[:space:]]*//' | head -1)"

# Pipeline complete? exit cleanly.
if [[ "$PHASE" == "complete" || "$PHASE" == "done" ]]; then
  exit 0
fi

# Auto-loop off => allow exit (user resumes).
if [[ "$AUTO" != "true" ]]; then
  printf 'dev-pipeline: stop allowed (auto_loop=false, phase=%s)\n' "$PHASE" >> "$FOUNDRY_DIR/logs/stop.log"
  exit 0
fi

# Verify the current phase
VERIFY_OUT=""
if [[ -x "$PLUGIN_ROOT/scripts/verify.sh" ]]; then
  VERIFY_OUT="$(bash "$PLUGIN_ROOT/scripts/verify.sh" "$PHASE" 2>&1 || true)"
fi

# v1.0.0 — Security iteration-cap check (arXiv 2506.11022)
# Read iteration_chain from state.md. If count >= cap and we're in execute/qa, HALT.
ITER_COUNT=$(awk '
  /^foundry:/{flag=1; next}
  flag && /^  iteration_chain:/{flag2=1; next}
  flag2 && /^    count:/{sub(/^    count:[[:space:]]*/, ""); sub(/[[:space:]]*#.*$/, ""); gsub(/[[:space:]]/, ""); print; exit}
' "$STATE_FILE" 2>/dev/null)
ITER_COUNT="${ITER_COUNT:-0}"
ITER_FAILURE_ID=$(awk '
  /^foundry:/{flag=1; next}
  flag && /^  iteration_chain:/{flag2=1; next}
  flag2 && /^    current_failure_id:/{sub(/^    current_failure_id:[[:space:]]*/, ""); sub(/[[:space:]]*#.*$/, ""); gsub(/^"|"$/, ""); gsub(/[[:space:]]/, ""); print; exit}
' "$STATE_FILE" 2>/dev/null)
ITER_CAP="${FOUNDRY_ITER_CAP:-3}"
ITER_HALTED="false"
if [[ "$PHASE" == "execute" || "$PHASE" == "qa" ]]; then
  if [[ "${ITER_COUNT:-0}" -ge "${ITER_CAP}" ]]; then
    ITER_HALTED="true"
  fi
fi

# Decide: continue (block exit) or advance (still block, with new focus prompt)
DECISION=""

case "$PHASE" in
  idea|research|prototype|prd|tdd|plan)
    # Single-pass phases: verify, then advance to next phase
    if printf '%s' "$VERIFY_OUT" | grep -qE '^VERIFY:.*PASS'; then
      bash "$PLUGIN_ROOT/scripts/foundry-state.sh" advance >/dev/null 2>&1 || true
      NEW_PHASE="$(grep -E '^current_phase:' "$STATE_FILE" | sed 's/^current_phase:[[:space:]]*//' | head -1)"
      DECISION="Phase $PHASE verified. Advanced to $NEW_PHASE. Continue with the $NEW_PHASE skill."
    else
      DECISION="Phase $PHASE not yet verified ($VERIFY_OUT). Continue the ceremony."
    fi
    ;;
  execute)
    # Loop within phase until board is empty
    LOOP_OUT="$(bash "$PLUGIN_ROOT/scripts/foundry-loop.sh" execute 2>&1 || true)"
    DECISION="$LOOP_OUT"
    ;;
  qa)
    # Special handling for convergence: if all 8 gates pass and only signoff
    # is missing, surface a "ready for signoff" decision (don't keep looping).
    CONVERGENCE_OUT="$(bash "$PLUGIN_ROOT/scripts/foundry-check-convergence.sh" 2>&1 || true)"
    CONVERGENCE_RC=$?
    if [[ $CONVERGENCE_RC -eq 0 ]]; then
      DECISION="All 8 QA convergence gates pass. Pipeline is CONVERGED. Awaiting user sign-off. Run /dev-signoff to complete (or /dev-status for details)."
    else
      # Not converged — emit the loop driver output (per-ticket reviewer, cross-reviewer, planner)
      LOOP_OUT="$(bash "$PLUGIN_ROOT/scripts/foundry-loop.sh" qa 2>&1 || true)"
      DECISION="$LOOP_OUT

Convergence check detail:
$CONVERGENCE_OUT"
    fi
    ;;
  *)
    DECISION="Unknown phase $PHASE. Pausing auto-loop."
    bash "$PLUGIN_ROOT/scripts/foundry-state.sh" set-loop off >/dev/null 2>&1 || true
    ;;
esac

# v1.0.0 — Override decision with ITERATION_CAP HALT if the cap was hit
# The HALT surfaces the iteration-chain state to the human and asks for signoff
# to clear the cap (reset-iteration-chain).
if [[ "$ITER_HALTED" == "true" ]]; then
  DECISION="🔴 ITERATION_CAP HALT (arXiv 2506.11022):
  $ITER_COUNT consecutive failures on the same failure_id (cap=$ITER_CAP)
  failure_id: $ITER_FAILURE_ID
  last successful review: see state.md foundry.iteration_chain.last_human_review_at

  Per arXiv 2506.11022, critical vulnerabilities rise 37.6% after 5+ rounds of unreviewed LLM 'improvement'. The cap forces human review.

  Action: Run /foundry-signoff to clear the cap and reset the chain (after reviewing the failure).
  Or run 'foundry-state.sh set-iteration-cap <N>' to override the cap for this run."
fi

TS="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
printf '%s\tphase=%s\tauto=%s\tdecision=%s\n' "$TS" "$PHASE" "$AUTO" "$DECISION" >> "$FOUNDRY_DIR/logs/stop.log"

# Block the agent's exit by emitting a non-empty decision
if [[ -n "$DECISION" ]]; then
  jq -nc --arg d "$DECISION" '{
    decision: "block",
    reason: $d
  }'
  exit 0
fi

# Allow exit
exit 0