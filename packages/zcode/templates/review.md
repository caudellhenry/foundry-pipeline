---
phase: qa
status: complete
created: 2026-07-03
updated: 2026-07-03
ticket: <STORY-ID>
reviewer: general-purpose-subagent      # which profile id was used
reviewer_model: lite                   # sonnet | lite | opus
round: 1
verdict: APPROVED | NEEDS-FIX | REJECT
findings_count: 0
human_approved: false                  # set true after /foundry-signoff or explicit human action
human_approved_at: null
human_approved_by: null
---
# Review — <STORY-ID>

## Diff summary
<one paragraph from reviewer: what the diff does, what's notable>

## Findings

| # | Severity | Category | Location | Description | Recommendation |
|---|----------|----------|----------|-------------|----------------|
| 1 | high | security | src/auth.ts:42 | <issue> | <fix> |

Categories: security | performance | accessibility | error-handling | edge-case | cognitive-debt | comprehension-debt | style | test-coverage | documentation

## Verdict

**Status**: APPROVED | NEEDS-FIX | REJECT
**Rationale**: <one paragraph>

## Test re-run

| Metric | Value |
|---|---|
| tests_run | <N> |
| passed | <N> |
| failed | <N> |
| skipped | <N> |
| coverage_pct | <N>% |
| coverage_baseline | <N>% |
| lint_errors | <N> |
| typecheck_errors | <N> |

Full log at `.foundry/qa/evidence/test-runs/<STORY-ID>-review-<iter>.log`

## Cognitive-debt notes (per Geoffrey Litt)
<what's hard to understand about this diff? where do you have to keep too much in your head?>

## Comprehension-debt notes (per Addy Osmani)
<what's hard to *use* correctly? what's the API surface that requires too much context?>

## Out-of-scope observations (not blocking)
- <observation> — not part of this ticket's acceptance criteria; route as NEW-### if you want to track