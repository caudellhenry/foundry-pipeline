---
name: foundry-prototype
description: Phase 3 of the foundry — the Prototype phase (conditional). Imposes taste on the outcome before locking the PRD — iterate a throwaway tracer bullet (UI, architecture, or external-service test), commit the winner into the codebase, and capture notes. Uses the TDD red/green discipline (mattpocock/skills/tdd pattern). Skip rule: if the work is purely mechanical with no taste decision, skip. Use when /foundry-prototype is invoked or when the pipeline auto-advances from Phase 2.
---
foundry_version: 2.0.2

# Phase 3 — Prototype (conditional)

> *"By the time we get to the PRD, it's a little bit too abstract. You really need concrete feedback first."* — Matt Pocock

This phase produces a **throwaway prototype** that locks taste — UI direction, architecture shape, or external-service interaction pattern. The winner is **committed to the codebase** so the execution agent can read it later.

## When to run

- `/foundry-prototype` is invoked.
- Pipeline auto-advances from Phase 2.
- The user wants to iterate UI or architecture before committing to a PRD.

## Skip rule

Skip if the work is **purely mechanical**:
- Library upgrade with no API surface change.
- Pure refactor (no behaviour change).
- One-line tweak.

If skipping, mark `phases.prototype.status = skipped` with reason.

## Ceremony

The prototype is a **vertical slice / tracer bullet** (Pocock's terms):
- **Vertical** = end-to-end through one path (UI → API → DB → test).
- **Tracer bullet** = the thinnest possible implementation that touches every layer.

Iterate in **2–4 sessions** max. Each session:
1. Pick a tracer bullet (e.g., "user signs up and lands on dashboard").
2. Build the thinnest end-to-end implementation.
3. Show it to the user. Get feedback.
4. Commit. Move on.

Do not gold-plate. Do not write tests beyond the tracer bullet (tests are Phase 6's job).

## Output artefacts

### `.foundry/prototype/notes.md`

```yaml
---
phase: prototype
status: complete | skipped
created: <ISO timestamp>
completed: <ISO timestamp>
sprint: <idea slug>
prototype_paths:
  - <path/to/file>
  - <path/to/file>
---
# Prototype — <intent summary>

## What we prototyped
<one-paragraph summary of the tracer bullet>

## Decisions locked
1. <decision> (e.g., "Tailwind for styling, not CSS modules")
2. <decision>
3. <decision>

## Decisions deferred
- <decision> (will be made during PRD / planning)

## Code locations
- `<path/to/file>` — <what it contains>
- `<path/to/file>` — <what it contains>

## What we threw away
- <path or approach tried and abandoned>
- <reason>

## Taste notes (for the execution agent to respect)
- "Use this colour palette, not that one"
- "Prefer this layout pattern for cards"
- "Match the voice/tone of these existing strings"
```

## Verifier

Phase 3 is **complete** when:
- `prototype/notes.md` exists and lists at least one decision locked.
- The prototype code is committed (visible via `git log` or noted path).
- The user has approved the prototype ("looks good, ship the pattern", "let's lock this in").

Or **skipped** when the work is mechanical (library bump, pure refactor).

## On completion

1. Update `.foundry/state.md`:
   - `phases.prototype.status = complete | skipped`
   - `phases.prototype.completed = <now>`
   - `phases.prototype.artifacts.notes = .foundry/prototype/notes.md`
   - `phases.prototype.artifacts.paths = [<list>]`
   - `current_phase = prd`
2. Prompt: `✓ Phase 3 (Prototype) complete. Next: Phase 4 (PRD) — non-conditional. Run /foundry-prd.`

## Cross-references

- **TDD** (mattpocock/skills/tdd) — red/green discipline is the methodology.
- **Cursor Composer** — fastest UI iteration loop in mid-2026.
- **Geoffrey Litt** — *code like a surgeon*; the prototype is primary work, not secondary.
- **`Skills/uxui-studio/`** — canonical Phase 3 UI tool. Four progressive fidelity modes (Wireframe → Design System → Hi-fi → Build Artifact). When the intent involves UI, invoke `uxui-studio` via the Skill tool. Mode 1 (wireframe) is the natural entry for Phase 3; Modes 2–4 progress to hi-fi and React artifact. Outputs land in `.foundry/prototype/studio/{wireframes,design-system,hi-fi,artifact}/`.

## UI work — invoke uxui-studio

When the intent mentions UI / frontend / screen / page / dashboard / form /
landing / app / interface / wireframe / mockup / design / component /
prototype (in the UI sense), invoke `uxui-studio` to produce the tracer
bullet. The ceremony:

1. Read `.foundry/idea/intent.md` + `.foundry/idea/risks.md`.
2. Pick the mode(s) to run based on the intent:
   - "wireframe" / "lo-fi" / "skeleton" → Mode 1 only (fast).
   - "design system" / "polish" / "polished" / "branded" → Modes 1 + 2 + 3.
   - "build" / "React" / "ship" / "production" → Modes 1 + 2 + 3 + 4.
   - Default → Modes 1 + 2 + 3 (conservative).
3. Invoke uxui-studio: `Use the Skill tool with skill name "uxui-studio"`.
4. The studio writes outputs to `.foundry/prototype/studio/`. Confirm
   each PNG thumbnail surfaces in chat (per `CLAUDE.md` rule).
5. Decisions locked (style + palette + typography + anti-slop passes) are
   written back to `.foundry/prototype/notes.md` §"Decisions locked".

The prototype is considered **complete** when the agent has shipped the
tracer-bullet wireframe(s) AND, if the intent warrants, the hi-fi version.
The user explicitly approves before advancing to Phase 4.

## Named expert inputs

- **Pocock** — *"By the time we get to the PRD, it's a little bit too abstract."* (transcript §"Phase 3 — Prototype")
- **Litt** — *autonomy slider* — the prototype is the surgeon frame: the human picks the taste, the agent implements.
- **Karpathy** — *Software 3.0* — the prototype is "build for agents" too: the agent reads it during execution.
