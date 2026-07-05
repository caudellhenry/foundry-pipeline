---
phase: plan
status: ready
id: <STORY-ID>               # populated when the file is written; e.g. STORY-001
created: 2026-07-03
parent_feature: F-001
title: <story title>
estimate: S | M | L
priority: P1 | P2 | P3
blocked_by: []
blocks: []
tdd_plan: .foundry/tdd/<STORY-ID>.md
evidence_plan: .foundry/qa/evidence/<STORY-ID>.md
review_plan: .foundry/qa/review/<STORY-ID>.md
test_path: ""               # optional; if set, foundry-test-runner.sh filters to this path (e.g. src/foo/bar.test.ts)
test_runner: ""             # override state.md test.runner for this ticket
coverage_target: 0          # optional; override state.md test.coverage_threshold for this ticket
reviewer_required: true     # false = auto-Done after reviewer APPROVED; true = human gates sign-off
assigned_subagent: null     # populated when writer sub-agent spawned
started_at: null
completed_at: null
iterations: 0                # how many Ralph-loop iterations this ticket took
commit: null
branch: null                 # e.g. feat/STORY-001
verifier_exit_code: null
test_results:
  last_run: null             # ISO timestamp
  passed: null
  failed: null
  skipped: null
  coverage_pct: null
  lint_errors: null
  typecheck_errors: null
---
# <STORY-ID>: <story title>

## User story
**As a** <persona>
**I want** <behaviour>
**So that** <outcome>

## Acceptance criteria
- [ ] Given <context>, When <action>, Then <outcome>
- [ ] ...

## Vertical slice
<trace the path: UI → API → DB → test>

## TDD specs (frozen at Phase 5)
See `.foundry/tdd/<STORY-ID>.md` for the frozen test contract. Acceptance criteria above are codified into test cases there.

## Evidence plan (Phase 8)
- [ ] <what to demonstrate>
- [ ] <what to demonstrate>

## Review plan (Phase 7)
- [ ] Per-ticket reviewer sub-agent (Explore / lite) — verdict APPROVED | NEEDS-FIX | REJECT
- [ ] Cross-ticket reviewer (Explore / lite) — coherent with siblings
- [ ] Human approval (if reviewer_required: true)

## Out of scope
- <bullet>