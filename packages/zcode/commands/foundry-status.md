---
description: "/foundry-status — Show the current state of the foundry (current phase, board progress, QA cycle, loop state, test config, models, signoff, 8-gate convergence). v1.2.0."
argument-hint: ""
allowed-tools: ["Bash(${CLAUDE_PLUGIN_ROOT}/scripts/foundry-state.sh:*)", "Bash(${CLAUDE_PLUGIN_ROOT}/scripts/foundry-check-convergence.sh:*)"]
---

# /foundry-status — Pipeline state (v1.2.0)

Reads `.foundry/state.md` + runs the 8-gate convergence check; prints a one-page summary.

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/foundry-state.sh" status
```

The script prints:

```
foundry status @ 2026-07-04 12:30
─────────────────────────────────────
pipeline: dev v1.2.0
current_phase: qa
auto_loop: true

test config:
  runner: vitest
  cmd: npx vitest run
  coverage_cmd: npx vitest run --coverage
  coverage_threshold: 80
  coverage_baseline: 84.5
  lint_cmd: npx eslint .
  typecheck_cmd: npx tsc --noEmit
  skip_tests: false

models:
  writer: sonnet
  reviewer: lite
  cross_reviewer: lite
  qa_planner: sonnet

phases:
  idea      [complete]  2026-07-03 22:10
  research  [skipped]   reason: no external APIs
  prototype [complete]  2026-07-03 22:45
  prd       [complete]  2026-07-03 23:00
  plan      [complete]  2026-07-04 09:15
  execute   [complete]  iteration 7 / 50
  qa        [in_progress]  round 1

board:
  ready       : 0
  in_progress : 0
  review      : 2 (STORY-002, STORY-005)
  done        : 5 (STORY-001, STORY-003, STORY-004, STORY-006, STORY-007)
  blocked     : 0

qa:
  plan       : .foundry/qa/qa-plan.md  (round 1)
  findings   : 0 high / 1 medium / 3 low
  reviews    : 7/7 per-ticket + cross

convergence (8 gates):
  1. Board empty       : FAIL (review has 2)
  2. Review empty      : FAIL (2 awaiting human_approved)
  3. No high findings  : PASS
  4. No medium findings: FAIL (1 medium)
  5. Tests pass        : PASS
  6. Coverage gate     : PASS (87.5% >= 80% threshold; >= 82.5% baseline - 2)
  7. Lint+typecheck    : PASS
  8. User signoff      : FAIL (run /foundry-signoff after fixing 1, 2, 4)

signoff:
  user_signed_off: false

loop_state:
  phase5_active: false
  phase6_iteration: 7
  phase7_round: 1

next:
  /foundry-signoff <TICKET>  → approve a per-ticket review (gate 2)
  /foundry-qa                → continue QA round 2 (fix the 1 medium finding first)
```

Useful when resuming after `/foundry-loop-off` or after a new session.

To view the 8-gate convergence check in JSON (machine-readable):

```bash
bash scripts/foundry-check-convergence.sh --json
```

Returns:

```json
{"gates":{"1":"FAIL","2":"FAIL","3":"PASS","4":"FAIL","5":"PASS","6":"PASS","7":"PASS","8":"FAIL"},"failed_count":4,"verdict":"NOT_CONVERGED"}
```