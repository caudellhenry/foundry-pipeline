---
name: foundry-qa
description: Phase 7 of the foundry — the QA phase. Agent produces a QA plan; human walks through it (incl. code review); new tickets flow back to Phase 5 (board). The diagnose skill produces the QA plan; writer/reviewer sub-agent (fresh context) reviews the diff. Cognitive-debt / comprehension-debt checks per Geoffrey Litt. Loops with Phases 5/6 until the product converges. Use when /foundry-qa is invoked or when the pipeline auto-advances from Phase 6.
---
foundry_version: 2.0.3

# Phase 7 — QA

> *"QA here also involves a human actually going and reading the code that's been produced."* — Matt Pocock

This phase produces a **QA plan**, has a **human walk through it** (including code review), and **routes any new tickets back to Phase 5**. Phases 5/6/7 form a convergent loop that runs until the product is verified.

## When to run

- `/foundry-qa` is invoked.
- Pipeline auto-advances from Phase 7.
- A new ticket from QA flows back to the board (loop entry).

## Ceremony (diagnose + writer/reviewer)

1. **Diagnose** — the agent reads every `.foundry/qa/evidence/<TICKET>.md` from Phase 7 and produces a QA plan.
2. **Writer/reviewer** — a fresh-context sub-agent reviews each diff (cognitive-debt check).
3. **Human walk-through** — the human (you) walks the plan: clicks, runs scripts, reads code.
4. **Ticket flow** — any new finding is a new ticket on the board (back to Phase 6).

### Diagnose step

The agent writes `.foundry/qa/qa-plan.md` with:

- For each shipped ticket: the manual walk-through steps.
- For each ticket: a code-review checklist (security, performance, accessibility, error handling, etc.).
- An explicit section "What the human should read carefully" — the files / diffs the human must understand.
- An explicit section "What we did not test" — honest gap list.

### Writer/reviewer step

A fresh-context sub-agent (the *reviewer*) reviews the diff produced by the *writer* (Phase 7). The reviewer:
- Reads `.foundry/qa/evidence/<TICKET>.md` (writer's claims).
- Reads the actual diff (`git diff <commit>^ <commit>`).
- Reads the changed files in full.
- Writes `.foundry/qa/review/<TICKET>.md` with findings.

The reviewer's fresh context catches biases the writer had (Anthropic's *writer/reviewer pattern*).

### Human walk-through

The human walks the QA plan:
- Clicks through the UI.
- Runs the test commands.
- Reads the code at the *carefully* section.
- Marks items as pass/fail.

Findings become new tickets. Pass items get ticked.

## Output artefacts

### `.foundry/qa/qa-plan.md`

```yaml
---
phase: qa
status: complete
created: <ISO timestamp>
updated: <ISO timestamp>
round: <N>
---
# QA Plan — <intent summary> (round <N>)

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

## What the human should read carefully
- `<path/to/file>` — <why>
- `<path/to/file>` — <why>

## What we did not test
- <bullet> (and why)

## New tickets from this round
- [ ] NEW-001 — <finding> (priority P1)
- [ ] NEW-002 — <finding> (priority P2)

## Convergence criteria
<when does the product converge?>
```

### `.foundry/qa/review/<TICKET>.md` (one per ticket)

```yaml
---
phase: qa
status: complete
created: <ISO timestamp>
ticket: <TICKET>
reviewer: fresh-context-subagent
---
# Review — <TICKET>

## Diff summary
<one paragraph>

## Findings
- [ ] FIND-001: <issue> — severity low/med/high
- [ ] FIND-002: <issue>

## Verdict
**Status**: APPROVED | NEEDS-FIX | REJECT
**Rationale**: <one paragraph>
```

### `.foundry/qa/evidence/<TICKET>.md` (extended from Phase 7)

Append to existing evidence file:
- Human walk-through outcomes.
- Reviewer verdict.
- Any tickets created from findings.

## Verifier

Phase 8 is **complete for this round** when:
- `qa/qa-plan.md` exists for this round.
- Every shipped ticket has a `qa/review/<TICKET>.md`.
- Every ticket has human walk-through outcomes recorded.
- New findings have been routed to the board as tickets.

**Convergence**: the product is *done* when:
- All `ready` and `in_progress` tickets are `done`.
- QA plan's `round N+1` is empty (no new findings).
- The reviewer has approved all tickets.
- The user has signed off ("ship it", "merge it").

## Loop termination

When the board is empty AND the latest QA round is clean AND the user has signed off:
1. Update `.foundry/state.md`:
   - `phases.qa.status = complete`
   - `phases.qa.completed = <now>`
   - `phases.qa.rounds = <N>`
   - `phases.qa.verdict = converged | halted`
   - `pipeline.status = complete`
2. Prompt: `✓ Pipeline complete. Product converged in <N> QA rounds.`

Otherwise: route new tickets back to Phase 6 (board), loop.

## v1.2.0 — Three sub-agents + 8-gate convergence check

### What changed

In v1.2.0, Phase 7 is no longer a single conversation. Instead, the orchestrator spawns **three sub-agents per QA round** plus runs the **8-gate convergence check** as the source of truth.

### The three sub-agents

| Sub-agent | `profileId` | Model (default) | Spawner script | Output |
|-----------|-------------|-----------------|----------------|--------|
| Per-ticket reviewer | `Explore` | lite | `scripts/foundry-spawn-reviewer.sh <TICKET>` | `.foundry/qa/review/<TICKET>.md` |
| Cross-ticket reviewer | `Explore` | lite | `scripts/foundry-spawn-cross-reviewer.sh <ROUND> <TICKETS>` | `.foundry/qa/review/CROSS-round-<N>.md` |
| QA planner (synthesise) | `general-purpose` | sonnet | `scripts/foundry-spawn-qa-planner.sh <ROUND> <TICKETS>` | `.foundry/qa/qa-plan.md` |

**Per-ticket reviewer** (role: `agents/foundry-reviewer.md`):
- Fresh-context `Explore` profile (Anthropic's writer/reviewer pattern — *"a fresh context improves code review since Claude won't be biased toward code it just wrote"*).
- Reads the writer's evidence, the story, the TDD spec, and the diff.
- Re-runs `scripts/foundry-test-runner.sh <TICKET>` to verify the writer's claims.
- Reviews for 9 categories (security, perf, a11y, error-handling, edge cases, cognitive-debt, comprehension-debt, test-coverage, documentation).
- Severity each finding (high/medium/low); emits verdict APPROVED | NEEDS-FIX | REJECT.
- Writes to `.foundry/qa/review/<TICKET>.md`.

**Cross-ticket reviewer** (role: `agents/foundry-cross-reviewer.md`):
- Fresh-context `Explore` profile, runs once per QA round.
- Reads all per-ticket reviews + the cumulative diff.
- Looks for: orphaned code, dead exports, pattern drift (error shape, naming, async style), missing integration tests, cumulative coverage drop > 2%.
- Writes to `.foundry/qa/review/CROSS-round-<N>.md`.

**QA planner** (role: `agents/foundry-qa-planner.md`):
- Fresh-context `general-purpose` profile, runs once after both reviewers.
- Reads all per-ticket reviews + the cross-review.
- Tallies findings into `findings: { high, medium, low }` block.
- Routes findings as `NEW-###` tickets to `## Ready` on the board.
- Updates `.foundry/qa/qa-plan.md` (the machine-readable convergence artefact).
- End-of-message JSON tail: `{"verdict": "CONVERGED | NEEDS-FIX", "gates": {...}, "next_action": ...}`.

### The 8-gate convergence check (machine-checkable)

After the planner updates qa-plan.md, the orchestrator runs `scripts/foundry-check-convergence.sh`:

| # | Gate | Check |
|---|------|-------|
| 1 | Board empty | `## Ready` + `## In progress` both have 0 tickets |
| 2 | Review empty | Every Review ticket has `human_approved: true` in its review file |
| 3 | No high findings | `qa-plan.md findings.high == 0` |
| 4 | No medium findings | `qa-plan.md findings.medium == 0` |
| 5 | Tests pass | Latest full-suite runner JSON has `failed == 0` |
| 6 | Coverage gate | `coverage_pct >= coverage_threshold` AND `coverage_pct >= coverage_baseline - 2` |
| 7 | Lint + typecheck clean | Both have 0 errors |
| 8 | User signoff | `state.md signoff.user_signed_off == true` |

**Failure routing**:
- Gates 1-2 fail → loop back to Phase 6 (more tickets to ship).
- Gates 3-7 fail → writer sub-agent spawned to fix; iterate.
- Gate 8 fail → prompt `/foundry-signoff` to the user; await their confirmation.

### The orchestrator's per-QA-round flow

```
1. List shipped tickets from .foundry/qa/evidence/STORY-*.md

2. For each shipped ticket, spawn per-ticket reviewer:
     Agent(profileId=Explore, prompt=$(scripts/foundry-spawn-reviewer.sh TICKET), outputFile=.foundry/qa/review/TICKET.md)

3. Spawn cross-ticket reviewer:
     Agent(profileId=Explore, prompt=$(scripts/foundry-spawn-cross-reviewer.sh ROUND TICKETS...), outputFile=.foundry/qa/review/CROSS-round-ROUND.md)

4. Spawn QA planner:
     Agent(profileId=general-purpose, prompt=$(scripts/foundry-spawn-qa-planner.sh ROUND TICKETS...), outputFile=.foundry/qa/qa-plan.md)

5. Run 8-gate check:
     bash scripts/foundry-check-convergence.sh
     - exit 0 (CONVERGED) → stop-hook surfaces "Ready for /foundry-signoff"
     - exit 1 (NOT_CONVERGED) → loop back to Phase 6 if there are NEW-### tickets

6. If user signs off:
     bash scripts/foundry-state.sh signoff
     → state.md signoff.user_signed_off=true, current_phase=complete
```

### Why sub-agents for QA?

- **Fresh context for the reviewer** — Anthropic's writer/reviewer pattern: a fresh context catches what the writer can't see (Karpathy's anterograde amnesia).
- **Lower-power model for review** — Willison: *"use your judgement to decide an appropriate lower power model"*; review is pattern-matching, not generation. Default to `lite` (= haiku).
- **Cross-ticket coherence** — per-ticket reviewers have scope bias; the cross-reviewer sees the cumulative diff and looks for issues that emerge from the combination.
- **Synthesis** — the QA planner is `sonnet` because synthesis (counting, routing, updating structured fields) is reasoning-heavy.
- **Machine-checkable gates** — the 8 gates replace human judgement-as-orchestrator. The human still signs off (gate 8) but the agent doesn't auto-complete without them.

## Cross-references

- **mattpocock/skills/diagnose** — the original QA-plan skill.
- **Anthropic writer/reviewer** — *"a fresh context improves code review since Claude won't be biased toward code it just wrote."*
- **/clear, /compact, /rewind** — context-reset primitives for the reviewer.
- **Longpre** — *third-party AI evaluation*; treat the writer as vendor and the reviewer as the eval programme.
- **Geoffrey Litt** — *cognitive debt*, *literate diff*, *quiz as speed regulator*. The writer/reviewer step is the cognitive-debt check.
- **Addy Osmani** — *comprehension debt*, *intent debt*. Same failure mode, different name.

## Named expert inputs

- **Pocock** — *"QA must include a human."* (transcript §"Phase 8")
- **Litt** — *cognitive debt*, *literate diff*, *quiz as speed regulator*. The writer/reviewer step is the cognitive-debt check.
- **Willison** — *cognitive-debt tag*; the reviewer sub-agent is the operationalisation.
- **Osmani** — *comprehension debt*, *intent debt*. Same failure mode, different name.
- **Anthropic** — *90% wall-time cut on research when agents parallel-call tools with verifier re-checks*. Apply to QA.
