---
phase: execute
status: pending
created: 2026-07-03
ticket: <STORY-ID>
commit: null
branch: null
reviewer_required: true
writer_subagent: null      # agent id from sub-agent spawn (writer)
writer_model: null         # sonnet | lite | opus
test_run:
  cmd: null                # actual command run
  started_at: null
  finished_at: null
  duration_s: null
  passed: null
  failed: null
  skipped: null
  total: null
  exit_code: null
  log_path: null           # .foundry/qa/evidence/test-runs/<TICKET>-<iter>.log
  coverage_pct: null
  coverage_baseline_at_run: null
  lint_errors: null
  typecheck_errors: null
verifier_exit_code: null
verifier_reason: null
---
# Evidence — <TICKET>

## Acceptance criteria
- [x] Given ..., When ..., Then ...
- [x] Given ..., When ..., Then ...

## Test output
<paste or summary; full log at `test_run.log_path`>

| Metric | Value |
|---|---|
| tests_run | <N> |
| passed | <N> |
| failed | <N> |
| skipped | <N> |
| duration_s | <s> |
| coverage_pct | <N>% |
| lint_errors | <N> |
| typecheck_errors | <N> |

## Visual evidence (if UI)
<screenshot path or description>

## Deviations from story
- <deviation> — <rationale>

## Verifier
**Status**: PASS | FAIL
**Ran at**: <timestamp>
**By**: scripts/verify.sh execute <TICKET>
**Reason**: <structured reason from foundry-test-runner.sh JSON>

## Sub-agent metadata
**Writer**: <writer_subagent> (model=<writer_model>)
**Reviewer**: <reviewer_subagent> (model=<reviewer_model>) — verdict <verdict>