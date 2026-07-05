---
phase: qa
status: pending
created: 2026-07-03
updated: 2026-07-03
round: 1
findings:
  high: 0
  medium: 0
  low: 0
convergence:
  board_empty: false
  review_empty: false
  high_findings_zero: false
  medium_findings_zero: false
  tests_pass: false
  coverage_above_threshold: false
  coverage_no_regression: false
  lint_clean: false
  typecheck_clean: false
  user_signoff: false
---
# QA Plan — <intent summary> (round 1)

## Tickets in scope
- <TICKET> — <title>
- <TICKET> — <title>

## Walk-through steps (per ticket)
### <TICKET> — <title>
- [ ] Step 1: <human action>
- [ ] Step 2: <human action>
- [ ] ...

## Code review checklist (per ticket)
### <TICKET>
- [ ] Security: <checklist>
- [ ] Performance: <checklist>
- [ ] Accessibility: <checklist>
- [ ] Error handling: <checklist>
- [ ] Edge cases: <checklist>
- [ ] Cognitive debt (Litt): <notes — what's hard to understand>
- [ ] Comprehension debt (Osmani): <notes — what's hard to keep in your head>

## What the human should read carefully
- `<path/to/file>` — <why>
- `<path/to/file>` — <why>

## What we did not test
- <bullet> (and why)

## Findings (machine-checkable)

| Severity | Count | Tickets |
|----------|-------|---------|
| high | <N>   | <list>  |
| medium | <N>  | <list>  |
| low | <N>    | <list>  |

Each finding must have a corresponding `NEW-###` ticket on the board (created automatically by `foundry-check-convergence.sh` when severity ≥ medium).

## New tickets from this round
- [ ] NEW-001 — <finding> (priority P1)
- [ ] NEW-002 — <finding> (priority P2)

## Convergence criteria (machine-checked)

Run `scripts/foundry-check-convergence.sh` after this plan is written. It checks the 8 gates below; all must pass for the pipeline to be marked complete.

| # | Gate | Check |
|---|------|-------|
| 1 | Board empty | `## Ready` and `## In progress` both have 0 tickets |
| 2 | Review empty | Every ticket in `## Review` has `human_approved: true` in its review file |
| 3 | No high findings | `findings.high == 0` |
| 4 | No medium findings | `findings.medium == 0` (configurable via `qa.allow_medium_findings`) |
| 5 | Tests pass | Latest full-suite runner JSON has `failed == 0` |
| 6 | Coverage gate | `coverage_pct >= coverage_threshold` AND `coverage_pct >= coverage_baseline - 2` |
| 7 | Lint + typecheck clean | `lint_errors == 0` AND `typecheck_errors == 0` |
| 8 | User signoff | `state.md signoff.user_signed_off == true` |

## Failure routing

- Gates 1-2 fail → loop back to Phase 6 (more tickets to ship)
- Gates 3-7 fail → writer sub-agent fix; iterate
- Gate 8 fail → prompt `/foundry-signoff`

## Cross-ticket coherence report
<one paragraph from the foundry-cross-reviewer sub-agent; e.g. "Found 2 orphaned exports, 1 inconsistent error shape, 0 dead helpers.">