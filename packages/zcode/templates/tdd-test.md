---
phase: tdd
status: pending
created: 2026-07-03
ticket: <STORY-ID>
parent_feature: <FEATURE-ID>
parent_prd_story: <US-XXX>
commit: null
test_runner: ""             # optional override (jest|vitest|pytest|go-test|mocha|node-test|bun)
test_path: ""               # optional filter for verify.sh; e.g. src/foo/bar.test.ts
coverage_target: 0          # optional; override state.md test.coverage_threshold for this story
---
# TDD — <TICKET>

## Story reference
**As a** <persona> **I want** <behaviour> **So that** <outcome>
*(from .foundry/prd.md §User stories)*

## Acceptance criteria → Test cases (Phase 5: spec'd here)
| AC # | Given / When / Then | Test name | Test layer |
|------|---------------------|-----------|------------|
| 1 | Given ..., When ..., Then ... | `test_<name>` | unit / integration / e2e |

## Test contract
For each test case above:
- **Inputs**: <preconditions + inputs>
- **Expected output**: <exact assertion>
- **Edge cases covered**: <list from PRD>
- **Mocking strategy**: <what's mocked vs real>

## Vertical slice implications
- UI: <element>
- API: <endpoint>
- DB: <schema/table>
- Test runner: <jest / vitest / playwright / etc.>
- Test path (filter): <glob or path used by test runner to run only this story's tests>

## Definition of Done (Phase 7 execute)
- [ ] All test cases above pass (green) — verified by `scripts/foundry-test-runner.sh <TICKET>`
- [ ] No tests skipped
- [ ] Coverage of this story's acceptance criteria: 100% (or `coverage_target` if set)
- [ ] Evidence recorded at `.foundry/qa/evidence/<TICKET>.md`
- [ ] Per-ticket reviewer sub-agent report at `.foundry/qa/review/<TICKET>.md` with verdict ≥ APPROVED

## Open ambiguities
- [ ] <criterion that wasn't testable as written — owner: human>

## Red (failing tests) — filled by Phase 7 execute
_(to be filled during execution)_

## Green (implementation) — filled by Phase 7 execute
_(to be filled during execution)_

## Refactor — filled by Phase 7 execute
_(to be filled during execution)_

## Verification — filled by Phase 7 execute
_(to be filled during execution; populated by foundry-test-runner.sh JSON)_