#!/usr/bin/env bash
# foundry-loop.sh — Ralph loop driver for Phase 7 (execute) and Phase 8 (qa)
#
# usage: foundry-loop.sh <phase>
#   phase=execute  → loop over board tickets until empty / max iter
#   phase=qa       → loop QA rounds until convergence / max iter
#
# The loop body is delegated to the agent via the Skill tool; this script
# just maintains iteration state, picks the next ticket, and surfaces
# the focus prompt for the agent to act on.

set -euo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
PROJECT_ROOT="${DEV_PIPELINE_PROJECT_ROOT:-$(pwd)}"
FOUNDRY_DIR="$PROJECT_ROOT/.foundry"
STATE_FILE="$FOUNDRY_DIR/state.md"

phase="${1:-execute}"
MAX_ITER="${DEV_PIPELINE_MAX_ITER:-50}"

increment_iter() {
  local key="$1"
  # Read current value, increment, write back. Default to 0 if missing/garbage.
  local current
  current="$(grep -E "^  ${key}:" "$STATE_FILE" 2>/dev/null | sed -E "s/^  ${key}:[[:space:]]*//" | head -1 | tr -d '[:space:]')"
  current="${current:-0}"
  # Validate it's an integer; otherwise reset to 0
  if ! [[ "$current" =~ ^[0-9]+$ ]]; then current=0; fi
  local next=$((current + 1))
  awk -v k="$key" -v n="$next" '
    $0 ~ "^  "k":" { sub(/[0-9]+$/, n); print; next }
    { print }
  ' "$STATE_FILE" > "$STATE_FILE.tmp"
  mv "$STATE_FILE.tmp" "$STATE_FILE"
}

pick_next_ticket() {
  # Returns the first "ready" ticket id from board.md, but ONLY from the
  # "## Ready" section (not Backlog / Blocked). Uses awk so it's section-aware.
  awk '
    /^## Ready/{flag=1; next}
    /^## /{flag=0}
    flag && /^- \[ \] .*STORY-/ {
      match($0, /STORY-[0-9]+/);
      if (RSTART > 0) { print substr($0, RSTART, RLENGTH); exit }
    }
  ' "$FOUNDRY_DIR/plan/board.md" 2>/dev/null
}

pick_qa_round_action() {
  # Returns a focus prompt for the current QA round
  if [[ -f "$FOUNDRY_DIR/qa/qa-plan.md" ]]; then
    echo "Continue QA round $(grep -E '^round:' "$FOUNDRY_DIR/qa/qa-plan.md" | sed 's/round:[[:space:]]*//' | head -1). Walk the plan; route new findings as tickets."
  else
    echo "Start QA round 1. Read .foundry/qa/evidence/*.md from Phase 6, then write .foundry/qa/qa-plan.md."
  fi
}

# Ship PR Until Green — sub-loop detection.
# If any ticket has a PR URL registered in state.md
# (phases.execute.prs.<TICKET>: <URL>) but its pr-state file is NOT marked
# `## Status: green`, return "<TICKET> <URL>". Otherwise empty.
# Gated on `phases.execute.platform` — if platform is `none` (the default),
# no sub-loop ever fires, regardless of stale entries in `phases.execute.prs`.
pr_subloop_active() {
  local platform
  platform="$(read_platform)"
  # GitLab (`mr-green`) is structurally identical to GitHub (`pr-green`); for now
  # the sub-loop is gated to `github` and `gitlab`. Any other platform → silent.
  [[ "$platform" == "github" || "$platform" == "gitlab" ]] || return 1
  # Whitespace-tolerant: state.md may have `  prs:` (2-space) or `    prs:` (4-space)
  # depending on YAML nesting depth. We match any leading whitespace then the key.
  awk '
    /^[[:space:]]+prs:[[:space:]]*$/ { f=1; next }
    f && /^[[:space:]]+[a-z]/ && !/^[[:space:]]+[a-z][a-z]*-[a-z]/ { f=0 }
    f && /^[[:space:]]+STORY-[0-9]+:/ {
      match($0, /STORY-[0-9]+/)
      tid = substr($0, RSTART, RLENGTH)
      sub(/^[[:space:]]*STORY-[0-9]+:[[:space:]]*/, "")
      gsub(/[[:space:]]+$/, "")
      # Strip any inline comment (# ...) that may be glued to the URL value.
      # This is a defensive measure — users may add inline YAML comments to
      # the prs:<ticket> line, and we never want them to leak into a CLI call.
      # Require at least one whitespace before `#` so URL fragments like
      # `https://.../pull/42#discussion` are preserved.
      sub(/[[:space:]]+#.*$/, "")
      url = $0
      if (url != "") print tid " " url
    }
  ' "$STATE_FILE" 2>/dev/null | while IFS=' ' read -r ticket url; do
    [[ -z "$ticket" || -z "$url" ]] && continue
    pr_file="$FOUNDRY_DIR/pr-state/$ticket.md"
    if [[ ! -f "$pr_file" ]] || ! grep -qE '^## Status:[[:space:]]*green' "$pr_file"; then
      echo "$ticket $url"
      return 0
    fi
  done
  return 1
}

pr_subloop_iteration() {
  local ticket="$1"
  awk -v t="$ticket" '
    /^[[:space:]]+prs:[[:space:]]*$/ { f=1; next }
    f && /^[[:space:]]+[a-z]/ && !/^[[:space:]]+[a-z][a-z]*-[a-z]/ { f=0 }
    f && /^[[:space:]]+STORY-[0-9]+:/ {
      match($0, /STORY-[0-9]+/)
      tid = substr($0, RSTART, RLENGTH)
      if (tid == t) {
        match($0, /iteration:[[:space:]]*[0-9]+/)
        if (RSTART > 0) {
          n = substr($0, RSTART+10)
          sub(/[^0-9].*/, "", n)
          print n+0
          exit
        }
        print 0
        exit
      }
    }
  ' "$STATE_FILE" 2>/dev/null
}

increment_pr_iteration() {
  # Increment pr-state/<ticket>.md iteration counter; cap at 10.
  local ticket="$1"
  local pr_file="$FOUNDRY_DIR/pr-state/$ticket.md"
  [[ -f "$pr_file" ]] || return 0
  awk '
    /^iteration:[[:space:]]*[0-9]+/ {
      n = $2 + 1
      sub(/[0-9]+$/, n)
    }
    { print }
  ' "$pr_file" > "$pr_file.tmp" && mv "$pr_file.tmp" "$pr_file"
}

# Read phases.execute.platform from state.md. Defaults to `none`.
# Strips inline comments (anything after `#`) before returning.
read_platform() {
  local p
  p="$(grep -E '^[[:space:]]+platform:' "$STATE_FILE" 2>/dev/null | head -1 | sed -E 's/^[[:space:]]+platform:[[:space:]]*//' | sed -E 's/[[:space:]]*#.*$//' | tr -d '[:space:]')"
  printf '%s' "${p:-none}"
}

case "$phase" in
  execute)
    # Only loop if we're actually in execute phase
    CUR_PHASE="$(grep -E '^current_phase:' "$STATE_FILE" 2>/dev/null | sed 's/^current_phase:[[:space:]]*//' | head -1)"
    if [[ "$CUR_PHASE" != "execute" ]]; then
      echo "EXECUTE: skipping (current_phase=$CUR_PHASE, expected execute). Run /foundry-execute first."
      exit 0
    fi
    if [[ ! -f "$FOUNDRY_DIR/plan/board.md" ]]; then
      echo "ERROR: missing .foundry/plan/board.md; run /foundry-plan first" >&2
      exit 1
    fi
    # CONNECTOR-FAILURE gate. If the user opted into a review platform
    # (platform != none), the corresponding CLI must be on PATH. If it isn't,
    # emit a HALT focus prompt so the agent surfaces the issue to the user
    # instead of blindly iterating. The loop will not emit next-ticket or
    # PR sub-loop focus prompts until the user resolves the connector.
    cur_platform="$(read_platform)"
    if [[ "$cur_platform" != "none" ]]; then
      cur_cli=""
      case "$cur_platform" in
        github) cur_cli="gh" ;;
        gitlab) cur_cli="glab" ;;
      esac
      if [[ -n "$cur_cli" ]] && ! command -v "$cur_cli" >/dev/null 2>&1; then
        cat <<EOF
EXECUTE: HALT — connector failure (phases.execute.platform is "$cur_platform" but the $cur_cli CLI is not installed).

This is a connector failure that requires human intervention. The loop has paused and will NOT emit next-ticket or PR-sub-loop focus prompts until the user resolves it.

To resolve (pick one):
  (a) Install the $cur_cli CLI and ensure it is on PATH:
        $cur_cli --version  # must succeed
  (b) Edit .foundry/state.md: change
        'platform: $cur_platform'  →  'platform: none'
      (local-only mode; the PR sub-loop will not run)
  (c) Edit the affected ticket stories to set
        'exit_criterion: local-only'   # instead of pr-green / mr-green

After resolution, re-enable the loop: /foundry-loop-on
EOF
        exit 0
      fi
    fi
    # Ship PR Until Green sub-loop takes precedence over picking the next ticket.
    PR_LINE="$(pr_subloop_active || true)"
    if [[ -n "$PR_LINE" ]]; then
      PR_TICKET="${PR_LINE%% *}"
      PR_URL="${PR_LINE#* }"
      PR_ITER="$(pr_subloop_iteration "$PR_TICKET")"
      PR_ITER="${PR_ITER:-0}"
      if [[ "$PR_ITER" -ge 10 ]]; then
        cat <<EOF
EXECUTE: PR sub-loop max iterations (10) reached for $PR_TICKET — paused.
URL: $PR_URL
Surface blockers via .foundry/pr-state/$PR_TICKET.md §Blockers, then route a NEW-### ticket back to the board. Run /foundry-loop-off to stop the loop.
EOF
        exit 0
      fi
      increment_pr_iteration "$PR_TICKET"
      cat <<EOF
EXECUTE: PR sub-loop active for $PR_TICKET iteration=$((PR_ITER+1))/10

Focus prompt:
  1. Run: gh pr checks $PR_URL
  2. If any check is FAILING: read logs (gh run view --log-failed), fix locally, commit, push.
  3. If all checks pass: write .foundry/pr-state/$PR_TICKET.md with '## Status: green' + commit hash + check rollup.
  4. If stuck, write '## Blockers' section and route a NEW-### ticket back to the board.

Anti-gaming rules:
  - Do NOT modify the check command or exit criteria to force success.
  - Do NOT skip, disable, or bypass checks.
  - Do NOT loop forever (max 10 iterations per PR; if reached, stop and report).
EOF
      exit 0
    fi
    NEXT="$(pick_next_ticket)"
    if [[ -z "$NEXT" ]]; then
      echo "EXECUTE: board empty (ready=0). Phase 7 complete; advance to QA."
      exit 0
    fi
    ITER="$(grep -E '^  phase6_iteration:' "$STATE_FILE" | sed 's/.*phase6_iteration:[[:space:]]*//' | head -1)"
    ITER="${ITER:-0}"
    if [[ "$ITER" -ge "$MAX_ITER" ]]; then
      echo "EXECUTE: max iterations reached ($MAX_ITER). Pausing loop; run /foundry-loop-off."
      exit 0
    fi
    increment_iter phase6_iteration
    WRITER_MODEL=$(awk -v k="^  writer:" '$0 ~ k { sub(k "[[:space:]]*", ""); print; exit }' "$STATE_FILE")
    WRITER_MODEL="${WRITER_MODEL:-sonnet}"
    EXPLORER_MODEL=$(awk -v k="^  explorer:" '$0 ~ k { sub(k "[[:space:]]*", ""); print; exit }' "$STATE_FILE")
    EXPLORER_MODEL="${EXPLORER_MODEL:-lite}"
    PLANNER_MODEL=$(awk -v k="^  planner:" '$0 ~ k { sub(k "[[:space:]]*", ""); print; exit }' "$STATE_FILE")
    PLANNER_MODEL="${PLANNER_MODEL:-lite}"
    COMMITTER_MODEL=$(awk -v k="^  committer:" '$0 ~ k { sub(k "[[:space:]]*", ""); print; exit }' "$STATE_FILE")
    COMMITTER_MODEL="${COMMITTER_MODEL:-lite}"
    TESTER_MODEL=$(awk -v k="^  tester:" '$0 ~ k { sub(k "[[:space:]]*", ""); print; exit }' "$STATE_FILE")
    TESTER_MODEL="${TESTER_MODEL:-lite}"
    SPAWNER="$PLUGIN_ROOT/scripts/foundry-spawn-writer.sh"
    WT_SCRIPT="$PLUGIN_ROOT/scripts/foundry-worktree.sh"
    # Read v1.3.0 worktree + parallel config (strip inline comments + whitespace)
    WT_ENABLED=$(awk '
      /^worktree:/{flag=1; next}
      flag && /^  enabled:/{sub(/^  enabled:[[:space:]]*/,""); sub(/[[:space:]]*#.*$/,""); gsub(/[[:space:]]/,""); print; exit}
      flag && /^[^ ]/{exit}
    ' "$STATE_FILE")
    WT_ENABLED="${WT_ENABLED:-true}"
    PAR_ENABLED=$(awk '
      /^parallel:/{flag=1; next}
      flag && /^  enabled:/{sub(/^  enabled:[[:space:]]*/,""); sub(/[[:space:]]*#.*$/,""); gsub(/[[:space:]]/,""); print; exit}
      flag && /^[^ ]/{exit}
    ' "$STATE_FILE")
    PAR_ENABLED="${PAR_ENABLED:-false}"
    PAR_MAX=$(awk '
      /^parallel:/{flag=1; next}
      flag && /^  max_workers:/{sub(/^  max_workers:[[:space:]]*/,""); sub(/[[:space:]]*#.*$/,""); gsub(/[[:space:]]/,""); print; exit}
      flag && /^[^ ]/{exit}
    ' "$STATE_FILE")
    PAR_MAX="${PAR_MAX:-3}"
    # Read parallelisable-now tickets from board
    PARALLEL_NOW="$(awk '/^## Parallelisable now/{flag=1; next} /^## /{flag=0} flag' "$FOUNDRY_DIR/plan/board.md" 2>/dev/null | tr ',' '\n' | sed -E 's/^[[:space:]]+//;s/[[:space:]]+$//' | grep -E '^STORY-[0-9]+' | head -n "$PAR_MAX")"
    PARALLEL_COUNT=0
    if [[ -n "$PARALLEL_NOW" ]]; then
      PARALLEL_COUNT=$(echo "$PARALLEL_NOW" | wc -l | tr -d '[:space:]')
    fi
    PARALLEL_LIST_HUMAN=$(echo "$PARALLEL_NOW" | tr '\n' ',' | sed 's/,$//')
    USE_PARALLEL="false"
    if [[ "$PAR_ENABLED" == "true" && "${PARALLEL_COUNT:-0}" -gt 1 ]]; then
      USE_PARALLEL="true"
    fi
    # Build the parallel fan-out section in a variable (avoids nested heredocs)
    PARALLEL_SECTION=""
    if [[ "$USE_PARALLEL" == "true" ]]; then
      PARALLEL_TICKET_LIST=$(echo "$PARALLEL_NOW" | sed 's/^/  - /')
      PARALLEL_SECTION="=== v1.0.0 — PARALLEL 4-SPAWN FAN-OUT ENABLED ===
Spawn up to $PAR_MAX tickets in PARALLEL. Each ticket runs the 4-spawn ceremony
in its own worktree on its own branch. Merge serially after.

Tickets to spawn in parallel (each with its own 4-spawn ceremony):
${PARALLEL_TICKET_LIST}

For EACH ticket in the list above:
  0. WT_PATH = \$($WT_SCRIPT create \$TICKET)
  1. Explorer:    PROMPT_BODY = \$($PLUGIN_ROOT/scripts/foundry-spawn-explorer.sh \$TICKET)     ; Agent(profileId=Explore, prompt=PROMPT_BODY, outputFile=.foundry/tdd/\$TICKET.explorer.json)
  2. Planner:     PROMPT_BODY = \$($PLUGIN_ROOT/scripts/foundry-spawn-planner.sh \$TICKET)      ; Agent(profileId=Explore, prompt=PROMPT_BODY, outputFile=.foundry/tdd/\$TICKET.planner.json)
  3. Implementer: PROMPT_BODY = \$($PLUGIN_ROOT/scripts/foundry-spawn-implementer.sh \$TICKET --worktree-path=\$($WT_SCRIPT path \$TICKET)); Agent(profileId=general-purpose, prompt=PROMPT_BODY, outputFile=.foundry/tdd/\$TICKET.md)
  4. Committer:   PROMPT_BODY = \$($PLUGIN_ROOT/scripts/foundry-spawn-committer.sh \$TICKET --worktree-path=\$($WT_SCRIPT path \$TICKET)); Agent(profileId=general-purpose, prompt=PROMPT_BODY, outputFile=.foundry/qa/evidence/\$TICKET.committed.json)
  5. Tester:      PROMPT_BODY = \$($PLUGIN_ROOT/scripts/foundry-spawn-tester.sh \$TICKET)     ; Agent(profileId=Explore, prompt=PROMPT_BODY, outputFile=.foundry/qa/review/\$TICKET.tester.json)

After ALL parallel ticket ceremonies complete:
  6. Merge each ticket back serially:
       for ticket in $PARALLEL_NOW; do
         bash $WT_SCRIPT merge \$ticket
         bash $WT_SCRIPT remove \$ticket
       done

  7. Run real verification per ticket:
       for ticket in $PARALLEL_NOW; do
         bash $PLUGIN_ROOT/scripts/verify.sh execute \$ticket
       done

  8. Update board: move each ticket from In progress to Review or Done.

  9. If any sub-agent FAILed: don't merge that worktree; route the failure as a NEW-### finding.

Concurrency note: ZCode's Agent tool may not support true concurrent invocations.
If you hit that limit, run the parallel tickets sequentially in one turn — TodoWrite
each as in_progress, invoke Agent for each, advance to completed. The worktree
isolation ensures no on-disk conflicts even in serial execution.
"
    else
      WT_BLOCK=""
      if [[ "$WT_ENABLED" == "true" ]]; then
        WT_BLOCK="  0. (Worktree setup) WT_PATH = \$($WT_SCRIPT create $NEXT)
       (To skip worktrees, run: foundry-state.sh set-worktree disabled)
"
      else
        WT_BLOCK=""
      fi
      WT_CLEANUP=""
      if [[ "$WT_ENABLED" == "true" ]]; then
        WT_CLEANUP="  7. After all 4 succeed: merge worktree, clean up:
       bash $WT_SCRIPT merge $NEXT
       bash $WT_SCRIPT remove $NEXT
"
      fi
      PARALLEL_SECTION="=== v1.0.0 — 4-SPAWN ANTHROPIC A2 CEREMONY (default) ===
One ticket at a time. Each ticket runs through 4 sub-agents in sequence
(explorer -> planner -> implementer -> committer) plus an adversarial tester.

${WT_BLOCK}
  1. EXPLORER (read-only, Explore profile, model=lite)
     PROMPT_BODY = \$($PLUGIN_ROOT/scripts/foundry-spawn-explorer.sh $NEXT)
     Agent(
       profileId = \"Explore\",
       description = \"Explore $NEXT (read ticket + TDD + code)\",
       prompt = PROMPT_BODY,
       outputFile = \".foundry/tdd/$NEXT.explorer.json\"
     )

  2. PLANNER (pure plan-mode, Explore profile, model=lite)
     input: explorer report (read the outputFile above)
     PROMPT_BODY = \$($PLUGIN_ROOT/scripts/foundry-spawn-planner.sh $NEXT)
     Agent(
       profileId = \"Explore\",
       description = \"Plan $NEXT (or skip_plan: true for one-sentence diffs)\",
       prompt = PROMPT_BODY,
       outputFile = \".foundry/tdd/$NEXT.planner.json\"
     )
     if skip_plan == true: skip to step 4 with one-sentence directive

  3. IMPLEMENTER (TDD, general-purpose, model=sonnet, worktree-isolated)
     input: planner report
     PROMPT_BODY = \$($PLUGIN_ROOT/scripts/foundry-spawn-implementer.sh $NEXT ${WT_ENABLED:+--worktree-path=\$($WT_SCRIPT path $NEXT)})
     Agent(
       profileId = \"general-purpose\",
       description = \"Implement $NEXT via TDD (red->green->refactor)\",
       prompt = PROMPT_BODY,
       outputFile = \".foundry/tdd/$NEXT.md\"
     )
     - red -> green -> refactor -> evidence -> commit
     - iteration-cap: 3 consecutive failures on same failure_id = ITERATION_CAP (halt + human review)
     if status == ITERATION_CAP: surface halt, require human review
     if status == FAIL: re-feed failure JSON to next implementer attempt (Ralph re-entry)

  4. COMMITTER (mechanical, general-purpose, model=lite)
     input: implementer JSON tail (commit hash)
     PROMPT_BODY = \$($PLUGIN_ROOT/scripts/foundry-spawn-committer.sh $NEXT ${WT_ENABLED:+--worktree-path=\$($WT_SCRIPT path $NEXT)})
     Agent(
       profileId = \"general-purpose\",
       description = \"Commit $NEXT (board update + frontmatter + log)\",
       prompt = PROMPT_BODY,
       outputFile = \".foundry/qa/evidence/$NEXT.committed.json\"
     )

  5. ADVERSARIAL TESTER (Explore profile, model=lite, forked context)
     input: implementer + committer outputs
     PROMPT_BODY = \$($PLUGIN_ROOT/scripts/foundry-spawn-tester.sh $NEXT)
     Agent(
       profileId = \"Explore\",
       description = \"Adversarial test of $NEXT (try to break it)\",
       prompt = PROMPT_BODY,
       outputFile = \".foundry/qa/review/$NEXT.tester.json\"
     )
     verdict PASS/FAIL
     if FAIL: route findings as NEW-### tickets to .foundry/plan/board.md

  6. Run real verification (real test_cmd + coverage + lint + typecheck):
       bash $PLUGIN_ROOT/scripts/verify.sh execute $NEXT

${WT_CLEANUP}  8. Update board: move $NEXT from In progress to Review (or Done if reviewer_required: false)
     on the board at .foundry/plan/board.md

Failure routing:
  - Implementer FAIL: feed test-runner JSON reason back to next implementer spawn
  - ITERATION_CAP: surface halt, require /foundry-signoff for human review
  - Tester FAIL: route findings as NEW-### tickets, loop back to /foundry-execute
"
    fi
    cat <<EOF
EXECUTE: next ticket=$NEXT iteration=$((ITER+1))/$MAX_ITER

worktree.enabled: $WT_ENABLED
parallel.enabled: $PAR_ENABLED (max_workers=$PAR_MAX)
parallelisable-now: ${PARALLEL_COUNT:-0} ticket(s) [$PARALLEL_LIST_HUMAN]

=== FOUNDRY 4-SPAWN ANTHROPIC A2 CEREMONY (v1.0.0) ===
$PARALLEL_SECTION

When the board's Ready section is empty:

  set-phase qa
  /foundry-qa

Sub-agent models (per role, configurable via foundry-state.sh set-models <role> <model>):
  explorer:    ${EXPLORER_MODEL:-lite}
  planner:     ${PLANNER_MODEL:-lite}
  implementer: ${WRITER_MODEL:-sonnet}    # alias: "writer" in state.md
  committer:   ${COMMITTER_MODEL:-lite}
  tester:      ${TESTER_MODEL:-lite}
EOF
    ;;
  qa)
    CUR_PHASE="$(grep -E '^current_phase:' "$STATE_FILE" 2>/dev/null | sed 's/^current_phase:[[:space:]]*//' | head -1)"
    if [[ "$CUR_PHASE" != "qa" ]]; then
      echo "QA: skipping (current_phase=$CUR_PHASE, expected qa). Run /foundry-qa first."
      exit 0
    fi
    ITER="$(grep -E '^  phase7_round:' "$STATE_FILE" | sed 's/.*phase7_round:[[:space:]]*//' | head -1)"
    ITER="${ITER:-0}"
    if [[ "$ITER" -ge "$MAX_ITER" ]]; then
      echo "QA: max rounds reached ($MAX_ITER). Pausing loop; run /foundry-loop-off."
      exit 0
    fi
    # Check whether new tickets exist on the board (from previous round)
    NEW_TICKETS="$(grep -cE '^- \[ \] NEW-' "$FOUNDRY_DIR/plan/board.md" 2>/dev/null || true)"
    NEW_TICKETS="$(printf '%s' "$NEW_TICKETS" | tr -d '[:space:]')"
    NEW_TICKETS="${NEW_TICKETS:-0}"
    if [[ "$NEW_TICKETS" -gt 0 ]]; then
      echo "QA: $NEW_TICKETS new tickets routed back to board. Phase 8 should re-route to Phase 6/7."
      # In Ralph loop semantics, this means loop back to plan/execute
      # The orchestrator handles the back-flow; we just surface the message.
    fi
    ACTION="$(pick_qa_round_action)"
    SHIPPED_TICKETS=$(find "$FOUNDRY_DIR/qa/evidence" -maxdepth 1 -name 'STORY-*.md' 2>/dev/null | xargs -I{} basename {} .md | sort -u | tr '\n' ' ')
    REVIEWER_MODEL=$(awk -v k="^  reviewer:" '$0 ~ k { sub(k "[[:space:]]*", ""); print; exit }' "$STATE_FILE")
    REVIEWER_MODEL="${REVIEWER_MODEL:-lite}"
    CROSS_MODEL=$(awk -v k="^  cross_reviewer:" '$0 ~ k { sub(k "[[:space:]]*", ""); print; exit }' "$STATE_FILE")
    CROSS_MODEL="${CROSS_MODEL:-lite}"
    QA_PLANNER_MODEL=$(awk -v k="^  qa_planner:" '$0 ~ k { sub(k "[[:space:]]*", ""); print; exit }' "$STATE_FILE")
    QA_PLANNER_MODEL="${QA_PLANNER_MODEL:-sonnet}"
    increment_iter phase7_round
    cat <<EOF
QA: round $((ITER+1))/$MAX_ITER

Shipped tickets: $SHIPPED_TICKETS
New tickets from previous round: $NEW_TICKETS

$ACTION

=== PER-TICKET REVIEWER SUB-AGENT(S) (v1.2.0 — fresh context per review) ===

For each shipped ticket, spawn a fresh-context reviewer (Anthropic's writer/reviewer pattern):

  PROMPT_BODY = \$($PLUGIN_ROOT/scripts/foundry-spawn-reviewer.sh TICKET)
  Agent(
    profileId = "Explore",
    description = "Review TICKET (cognitive-debt + comprehension-debt)",
    prompt = PROMPT_BODY,
    outputFile = ".foundry/qa/review/TICKET.md"
  )

=== CROSS-TICKET REVIEWER ===

Once all per-ticket reviewers are done, spawn the cross-reviewer:

  PROMPT_BODY = \$($PLUGIN_ROOT/scripts/foundry-spawn-cross-reviewer.sh $((ITER+1)) $SHIPPED_TICKETS)
  Agent(
    profileId = "Explore",
    description = "Cross-ticket coherence review (round $((ITER+1)))",
    prompt = PROMPT_BODY,
    outputFile = ".foundry/qa/review/CROSS-round-$((ITER+1)).md"
  )

=== QA PLANNER (synthesise) ===

After both reviews complete, spawn the QA planner to update qa-plan.md:

  PROMPT_BODY = \$($PLUGIN_ROOT/scripts/foundry-spawn-qa-planner.sh $((ITER+1)) $SHIPPED_TICKETS)
  Agent(
    profileId = "general-purpose",
    description = "Synthesise QA round $((ITER+1)) into qa-plan.md",
    prompt = PROMPT_BODY,
    outputFile = ".foundry/qa/qa-plan.md"
  )

=== CONVERGENCE CHECK (machine-checked, 8 gates) ===

Run the convergence check:

  bash "$PLUGIN_ROOT/scripts/foundry-check-convergence.sh"

  CONVERGED (exit 0) -> prompt user with /dev-signoff, await their confirmation
  NOT_CONVERGED (exit 1) -> loop back to /foundry-execute for any new tickets

The 8 gates (see scripts/foundry-check-convergence.sh):
  1. Board empty
  2. Review empty (every Review ticket has human_approved: true)
  3. No high findings
  4. No medium findings
  5. Tests pass (full suite)
  6. Coverage gate (>= threshold AND >= baseline - 2)
  7. Lint + typecheck clean
  8. User signoff

Models: reviewer=$REVIEWER_MODEL cross_reviewer=$CROSS_MODEL qa_planner=$QA_PLANNER_MODEL
        (configurable via: foundry-state.sh set-models <writer|reviewer|cross_reviewer|qa_planner> <model>)
EOF
    ;;
  *)
    echo "usage: foundry-loop.sh <execute|qa>" >&2
    exit 2
    ;;
esac