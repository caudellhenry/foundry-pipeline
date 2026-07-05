---
name: foundry-tdd
description: Phase 5 of the foundry — the TDD test specs phase (non-conditional). Reads the PRD and writes one .foundry/tdd/<STORY-ID>.md per user story, defining the tests that must pass for that story to meet its Definition of Done. Specs are written BEFORE the kanban plan so that plan tickets can reference concrete test expectations and the execution loop has a frozen contract. Use when /foundry-tdd is invoked or when the pipeline auto-advances from Phase 4.
---
foundry_version: 2.0.1

# Phase 5 — TDD Test Specs

> *"A test is the contract. Specs freeze the contract; implementation proves it."*

This phase turns PRD acceptance criteria into **explicit, testable specs** — one file per user story. These specs are the contract that the Plan phase organises into tickets and the Execute phase implements against. They are written **before** planning so dependency analysis has concrete deliverables to reason about.

## When to run

- `/foundry-tdd` is invoked.
- Pipeline auto-advances from Phase 4 (PRD).

## Inputs

- `.foundry/prd.md` — destination document, source of user stories + acceptance criteria
- (optional) `.foundry/idea/intent.md` — original intent
- (optional) `.foundry/prototype/notes.md` — concept prototype artefacts

## Ceremony (one PRD story at a time)

For each user story in the PRD (US-001 through US-NNN), the agent walks the story and produces a spec:

1. **Read** the user story and its acceptance criteria from `prd.md`.
2. **For each Given/When/Then** in the acceptance criteria, draft one or more concrete test cases. The test name should encode the **behaviour**, not the implementation. Example: `should_reveal_mechanic_phone_after_mechanic_accepts_booking`.
3. **Define the test contract**: inputs, expected outputs, edge cases from the PRD's Edge Cases section that apply.
4. **Identify the test layer**: unit, integration, or end-to-end. The vertical slice in the plan phase will follow this.
5. **Surface ambiguities**: if an acceptance criterion cannot be turned into a testable contract (e.g., "feels fast"), the agent surfaces this via grill-me — the user must either sharpen the criterion or accept that the test will check the proxy (e.g., p95 latency < 200ms).

The agent does NOT write code. It writes specs that an implementation agent (Phase 7) will turn into failing tests, then green code, then refactor.

## Output artefacts

### `.foundry/tdd/<STORY-ID>.md` (one per PRD user story)

```yaml
---
phase: tdd
status: complete
created: <ISO timestamp>
ticket: <STORY-ID>
parent_prd_story: US-XXX
---
# TDD Spec — <STORY-ID>

## Story reference
**As a** <persona> **I want** <behaviour> **So that** <outcome>
*(from .foundry/prd.md §User stories)*

## Acceptance criteria → Test cases
| AC # | Given / When / Then | Test name | Test layer |
|------|---------------------|-----------|------------|
| 1 | Given ..., When ..., Then ... | `test_<name>` | unit / integration / e2e |
| 2 | ... | ... | ... |

## Test contract
For each test case:
- **Inputs**: <preconditions + inputs>
- **Expected output**: <exact assertion>
- **Edge cases covered**: <list from PRD>
- **Mocking strategy**: <what's mocked vs real>

## Vertical slice implications
- UI: <what UI element this drives>
- API: <what endpoint this drives>
- DB: <what schema/table this drives>
- Test runner: <jest / vitest / playwright / etc.>

## Definition of Done (for Phase 7 execute)
- [ ] All test cases above pass (green)
- [ ] No tests skipped
- [ ] Coverage of this story's acceptance criteria: 100%
- [ ] Evidence recorded at `.foundry/qa/evidence/<STORY-ID>.md`

## Open ambiguities
- [ ] <criterion that wasn't testable as written — owner: human>

## Red (failing tests) — filled by Phase 7 execute
_(to be filled during execution)_

## Green (implementation) — filled by Phase 7 execute
_(to be filled during execution)_

## Refactor — filled by Phase 7 execute
_(to be filled during execution)_

## Verification — filled by Phase 7 execute
_(to be filled during execution)_
```

## Verifier

Phase 5 is **complete** when:
- One `.foundry/tdd/<STORY-ID>.md` exists per `US-XXX` in `prd.md`.
- Every acceptance criterion in every PRD story has at least one test case row.
- The vertical slice implications section is filled (UI / API / DB / runner).
- Open ambiguities list is either empty or has an action owner.
- The user has signed off ("specs approved, plan it", "next phase").

## On completion

1. Update `.foundry/state.md`:
   - `phases.tdd.status = complete`
   - `phases.tdd.completed = <now>`
   - `phases.tdd.specs = .foundry/tdd/*.md`
   - `current_phase = plan`
2. Prompt: `✓ Phase 5 (TDD specs) complete. <N> test specs written. Next: Phase 6 (Plan / Kanban). Run /foundry-plan.`

## Cross-references

- **mattpocock/skills/tdd** — red/green/refactor discipline.
- **GitHub spec-kit `/tasks`** — TDD specs are analogous to the per-task acceptance contract.
- **Kent Beck** — *"Test-driven development: by example."* Specs are the design.

## Named expert inputs

- **Beck** — TDD discipline (red → green → refactor); tests are the design.
- **Fowler** — *"Specification is the source of truth; the code is a generated artefact."*
- **Pocock** — Phase 4 (PRD) + Phase 5 (TDD specs) give execution everything it needs.
- **Karpathy** — *Software 3.0*: *"Prompts are now Programs."* The TDD spec lives in the prompt space; the discipline (auto-generated tests, hooks, separating intent from mechanism) is the same.
