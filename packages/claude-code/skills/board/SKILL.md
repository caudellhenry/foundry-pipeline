---
name: foundry-plan
description: Phase 5 of the foundry — the Plan / Kanban phase (non-conditional). Reads the PRD and decomposes it into Features (parent) and User Stories (children), then lays out a kanban board with blocking relationships. Local-first: all tickets, dependencies, and status live in .foundry/plan/{features,board,stories/}.md. Linear / GitHub Issues integration is a future improvement. Use when /foundry-plan is invoked or when the pipeline auto-advances from Phase 4.
---
foundry_version: 2.0.0

# Phase 5 — Plan / Kanban

> *"Break the PRD into tickets with blocking relationships; the board becomes the source of truth for what the agent is allowed to pick up next."* — Matt Pocock

This phase turns the PRD into a **kanban board** with Features (parent) and User Stories (children) plus blocking relationships. Local-first: tickets live in markdown files. Linear / GitHub Issues integration is a *future* improvement (per the user's brief).

## When to run

- `/foundry-plan` is invoked.
- Pipeline auto-advances from Phase 4.

## Inputs

- `.foundry/prd.md`
- `.foundry/tdd/*.md` — **frozen test specs from Phase 5** (one per PRD user story)
- `.foundry/idea/intent.md`
- `.foundry/research/research.md` (if exists)
- `.foundry/prototype/notes.md` (if exists)

## Ceremony

1. Read the PRD.
2. Identify **Features** — top-level chunks of capability that map to one or more user stories. 2–7 features per PRD typically.
3. For each Feature, derive **User Stories** that realise it. Stories should be vertical slices (end-to-end through UI → API → DB → test).
4. For each Story, write the **ticket body**: title, description, acceptance criteria, dependencies, estimate (S/M/L), parent feature, TDD test plan, evidence expectations.
5. Lay out the **board** — assign each story a status (`backlog`, `ready`, `in_progress`, `review`, `done`, `blocked`), identify the blocking relationships, and pick the *unblocked ready* set as the parallelisable top of the queue.
6. Validate: every user story in the PRD must appear in a ticket; every ticket must trace to a PRD story.

## Output artefacts

### `.foundry/plan/features.md`

```yaml
---
phase: plan
status: complete
created: <ISO timestamp>
---
# Features — <intent summary>

## F-001: <feature title>
**Description**: <one paragraph>
**User stories**: US-001, US-002, US-003
**Estimate**: M
**Priority**: P1

## F-002: ...
```

### `.foundry/plan/stories/<STORY-ID>.md` (one per story)

```yaml
---
phase: plan
status: ready
created: <ISO timestamp>
parent_feature: F-001
title: <story title>
estimate: S | M | L
priority: P1 | P2 | P3
blocked_by: []   # list of STORY-IDs that must complete first
blocks: []
tdd_plan: .foundry/tdd/<STORY-ID>.md
evidence_plan: .foundry/qa/evidence/<STORY-ID>.md
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

## TDD test plan (Phase 6)
- [ ] <test name> — <one-line description>
- [ ] <test name> — <one-line description>

## Evidence plan (Phase 7)
- [ ] <what to demonstrate>
- [ ] <what to demonstrate>

## Out of scope
- <bullet>
```

### `.foundry/plan/board.md`

```yaml
---
phase: plan
status: complete
created: <ISO timestamp>
updated: <ISO timestamp>
---
# Board — <intent summary>

## Backlog (not yet ready)
- [ ] STORY-005 — <title> (blocked by STORY-003)

## Ready (unblocked, available for Phase 6)
- [ ] STORY-001 — <title> (parent F-001, M)
- [ ] STORY-002 — <title> (parent F-001, M)
- [ ] STORY-004 — <title> (parent F-002, S)

## In progress
- [ ] <story-id> — <title>

## Review
- [ ] <story-id>

## Done
- [x] <story-id>

## Blocked
- [ ] STORY-003 — <reason>

## Parallelisable now (independent tickets)
STORY-001, STORY-002, STORY-004
```

## Verifier

Phase 6 is **complete** when:
- `features.md` exists with ≥ 1 feature.
- `stories/*.md` exists with ≥ 1 story.
- Every PRD user story has a ticket.
- **Every ticket references a frozen TDD spec at `.foundry/tdd/<STORY-ID>.md`** (the contract that execution will implement against).
- `board.md` exists and has at least one `ready` ticket (or the user explicitly accepts an empty queue).
- Blocking relationships are consistent (no cycles) — blocking can be inferred from TDD spec dependencies (e.g., a story whose tests import another story's API is blocked by that story).

## On completion

1. Update `.foundry/state.md`:
   - `phases.plan.status = complete`
   - `phases.plan.completed = <now>`
   - `phases.plan.artifacts.features = .foundry/plan/features.md`
   - `phases.plan.artifacts.board = .foundry/plan/board.md`
   - `phases.plan.artifacts.stories = .foundry/plan/stories/*.md`
   - `board.file = .foundry/plan/board.md`
   - `current_phase = execute`
2. Prompt: `✓ Phase 6 (Plan) complete. Next: Phase 7 (Execution loop). Run /foundry-execute or /foundry-loop-on.`

## Cross-references

- **GitHub Issues / Linear** — future MCP integration (the board schema mirrors both).
- **MCP servers** — `github mcp`, `linear mcp` (when connected, the board can be synced).
- **spec-kit `/tasks`** — analogous output (`tasks.md`).

## Named expert inputs

- **Pocock** — *"GitHub Issues for both PRD and board, but Linear is better for true blocking."* (transcript §"Phase 5")
- **Goedecke** — *"Throw every bug at an LLM"* — the board is also where diagnostic questions land after QA.
- **Willison** — *"Delegate coding tasks to subagents in worktrees, driven from the board."* (3 Jul 2026)
