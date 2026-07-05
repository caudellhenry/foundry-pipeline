---
name: foundry-prd
description: Phase 4 of the foundry — the PRD phase (non-conditional). Produces the destination document at .foundry/prd.md describing the end state (what the user sees, how it behaves) — NOT the implementation. Interrogates the user via grill-me to remove ambiguity. Modeled on mattpocock/skills/to-prd + spec-kit's /specify + /plan + /tasks ceremony. Use when /foundry-prd is invoked or when the pipeline auto-advances from Phase 3.
---
foundry_version: 2.0.1

# Phase 4 — PRD

> *"The specification is the single source of truth; the code is a generated artefact."* — Allegro, Microsoft, Thoughtworks, Fowler consensus on SDD

This phase produces a **destination document** — what the user sees, how it behaves — not the implementation. The PRD is non-conditional: every AI-coded project gets one.

## When to run

- `/foundry-prd` is invoked.
- Pipeline auto-advances from Phase 3.

## Inputs

- `.foundry/idea/intent.md`
- `.foundry/idea/risks.md`
- `.foundry/research/research.md` (if exists)
- `.foundry/prototype/notes.md` (if exists)

## Ceremony (to-prd)

The PRD is the agent's chance to **interrogate the user** through the decision tree (the **to-prd** ceremony from `mattpocock/skills/to-prd`, re-implemented locally). The agent should grill-me through each section of the PRD template until every cell is filled in.

### Sections of the PRD (in order)

1. **Problem statement** — one sentence. What user problem are we solving?
2. **Users & personas** — who is this for? What is their context?
3. **Goals** — measurable. What does success look like? (3–5 bullets)
4. **Non-goals** — explicit. What is out of scope? (3–5 bullets)
5. **User stories** — As a [persona], I want [behaviour], so that [outcome]. (5–15 stories)
6. **Acceptance criteria** — Given/When/Then for each story.
7. **End-state behaviour** — what the user sees (screens, flows, states). NO implementation detail.
8. **Edge cases & error states** — what happens when things fail.
9. **Open questions** — anything unresolved at PRD time.
10. **Glossary** — domain terms the agent must use consistently.

For each section, the agent asks **one clarifying question at a time** if anything is ambiguous. Do not skip the ceremony — ambiguity here becomes bugs later.

### spec-kit compatibility

The PRD output is compatible with the **GitHub spec-kit** artefact structure:
- `prd.md` ↔ spec-kit `spec.md` (the destination doc)
- `plan/features.md` ↔ spec-kit `plan.md` (produced in Phase 5)
- `plan/board.md` ↔ spec-kit `tasks.md` (produced in Phase 5)

This means the PRD can be lifted into a spec-kit project without translation.

## Output artefact

### `.foundry/prd.md`

```yaml
---
phase: prd
status: complete
created: <ISO timestamp>
updated: <ISO timestamp>
spec_kit_compatible: true
---
# PRD — <one-line summary>

> Destination document. Describes end-state behaviour, NOT implementation.

## Problem statement
<one sentence>

## Users & personas
- **<persona>**: <context>

## Goals (measurable)
1. <goal>
2. <goal>
3. <goal>

## Non-goals (explicit)
- <non-goal>
- <non-goal>

## User stories
### US-001: <title>
**As a** <persona>
**I want** <behaviour>
**So that** <outcome>

**Acceptance criteria**
- Given <context>, When <action>, Then <outcome>
- ...

### US-002: ...

## End-state behaviour
<screens, flows, states. NO implementation detail.>

## Edge cases & error states
| Edge case | Expected behaviour |
|-----------|--------------------|
| <edge>    | <behaviour>        |

## Open questions
- [ ] <question>
- [ ] <question>

## Glossary
- **<term>**: <definition>
```

## Verifier

Phase 4 is **complete** when:
- `prd.md` exists and every section is filled.
- At least 3 user stories with Given/When/Then acceptance criteria.
- Open questions list is either empty or has action owners.
- The user has signed off ("PRD approved, ship it", "next phase").

## On completion

1. Update `.foundry/state.md`:
   - `phases.prd.status = complete`
   - `phases.prd.completed = <now>`
   - `phases.prd.artifact = .foundry/prd.md`
   - `current_phase = plan`
2. Prompt: `✓ Phase 4 (PRD) complete. Next: Phase 5 (TDD test specs). Run /foundry-tdd.`

## Cross-references

- `mattpocock/skills/to-prd` (original)
- `mattpocock/skills/grill-me` (used inside PRD ceremony)
- **GitHub spec-kit** — `/specify`, `/plan`, `/tasks` map onto Phases 4/5
- **Kiro** — spec → design → code lifecycle (Phases 4 → 5 → 6)
- **Tessl** — spec-first code generation (Phases 4 → 6)
- **Claude Code plan mode** — analogous to PRD exploration

## Named expert inputs

- **Fowler** — *"Understanding spec-driven development: Kiro, spec-kit, and Tessl."*
- **Microsoft** — *"Define intent → remove ambiguity → plan with constraints → implement with AI → validate against the spec."*
- **Karpathy** — *Software 3.0*: *"Prompts are now Programs."* The PRD lives in the prompt space, not the file space — but the discipline (auto-generated tests, hooks, separating intent from mechanism) is the same.
- **Pocock** — PRD is non-conditional. (transcript §"Phase 4 — PRD")
