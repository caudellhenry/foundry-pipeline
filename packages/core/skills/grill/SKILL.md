---
name: foundry-idea
description: Phase 1 of the foundry — the Idea phase. Runs a relentless interview to sharpen a plan or design (grill-me), captures the *intent* (not the implementation) into .foundry/idea/intent.md, surfaces risks into .foundry/idea/risks.md, and advances the pipeline to Phase 2. Use when /foundry-idea is invoked or when the pipeline is at Phase 1.
---
foundry_version: 2.0.2

# Phase 1 — Idea

> *"Idea size doesn't matter — the same process scales from a one-line tweak to a multi-week build."* — Matt Pocock

The Idea phase captures **intent**, not implementation. The output is a short note that any downstream agent (research, prototype, PRD, execution) can read and act on without re-interviewing the user.

## When to run

- `/foundry-idea` is invoked.
- `/foundry "<intent>"` is invoked (boots Phase 1).
- The pipeline is at Phase 1 and needs to be advanced.

## Ceremony (grill-me)

Run the relentless interview (the **grill-me** ceremony from `mattpocock/skills/grill-me`, re-implemented locally):

1. Read `.foundry/state.md` to confirm Phase 1 is current.
2. Read the user's intent statement (one short paragraph). If `/foundry "<intent>"` was called, parse the argument; if `/foundry-idea` was called standalone, ask the user to state the intent.
3. **Interview** — ask 5–10 sharp questions, one at a time, until the intent is sharp. Use `AskUserQuestion` for structured choices where helpful. The questions should cover:
   - **Who** is the user? (persona, role, context)
   - **What** do they need to see / do? (end-state behaviour, not implementation)
   - **Why** now? (trigger, urgency, opportunity cost)
   - **How big** is this? (size estimate: tweak / small / medium / large / epic)
   - **What is explicitly out of scope?** (negative space)
   - **What assumptions** are we making? (call them out so they can be falsified)
   - **What does success look like?** (measurable, verifiable condition)
   - **What does failure look like?** (so we know when to stop)
   - **Are there constraints?** (stack, infra, budget, timeline, regulatory)
   - **What would change your mind?** (pre-mortem)
4. Capture the answers — do **not** re-ask questions already answered in the session.
5. Stop when the user says they are ready, or when the intent is sharp enough to act on.

## Output artefacts

Write to `.foundry/idea/` (created if missing):

### `.foundry/idea/intent.md`

```yaml
---
phase: idea
status: complete
created: <ISO timestamp>
updated: <ISO timestamp>
interview_rounds: <N>
---
# Intent — <one-line summary>

## Who
<persona, role, context>

## What
<end-state behaviour; user-facing, not implementation>

## Why now
<trigger, urgency, opportunity cost>

## Size
<tweak | small | medium | large | epic>

## Out of scope
- <bullet>
- <bullet>

## Assumptions
- <bullet>
- <bullet>

## Success criteria (verifiable)
1. <measurable condition>
2. <measurable condition>

## Failure modes
- <bullet>

## Constraints
- <bullet>

## Pre-mortem
If this fails, the most likely reasons will be: ...
```

### `.foundry/idea/risks.md`

```yaml
---
phase: idea
status: complete
created: <ISO timestamp>
---
# Risks — <intent summary>

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| <risk> | low / med / high | low / med / high | <mitigation> |
```

## Verifier

Phase 1 is **complete** when:
- `intent.md` exists and is non-empty.
- `risks.md` exists and has at least 3 rows.
- All ten interview topics above are addressed (or explicitly skipped by user).
- The user has confirmed intent ("looks good", "ship it", "next phase", etc.).

## On completion

1. Update `.foundry/state.md`:
   - `phases.idea.status = complete`
   - `phases.idea.completed = <now>`
   - `phases.idea.artifacts.intent = .foundry/idea/intent.md`
   - `phases.idea.artifacts.risks = .foundry/idea/risks.md`
   - `current_phase = research`
2. If `auto_loop` is on and Phase 2 (Research) is not skipped, prompt the user to confirm running it (Research is conditional). If they say skip, mark Phase 2 as `skipped` and advance to Phase 3.
3. Print a one-line summary: `✓ Phase 1 (Idea) complete. Next: Phase 2 (Research) — conditional. Run /foundry-research, /foundry-skip-research, or /foundry-prototype.`

## Skip rule

Phase 1 is **non-conditional** in Pocock's framework. There is no `/foundry-skip-idea`. If the user is confident the intent is sharp, run the ceremony anyway with a shorter interview (1–2 questions) and capture the intent note. Do not skip the artefact.

## Cross-references

- `Skills/grill-me/SKILL.md` — the upstream grill-me skill (re-used as the interview pattern)
- `templates/intent.md`, `templates/risks.md` — templates for the artefacts
- `scripts/verify.sh idea` — programmatic verifier

## Named expert inputs

- **Pocock** — *"Idea size doesn't matter."* (transcript §"Phase 1 — Idea")
- **Geoffrey Litt** — *"Understand to participate."* The interview exists so the agent has a *rich set of concepts* to work with.
- **Karpathy** — *vibe coding* is the *input style* to this phase: relax, capture the vision, defer implementation detail.
