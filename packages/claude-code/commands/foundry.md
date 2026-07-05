---
description: "/foundry — Master entry point for the AI-engineering eight-phase shipping pipeline (Idea -> Research -> Prototype -> PRD -> TDD specs -> Plan/Kanban -> Execution loop -> QA). Bootstrap a new idea, continue from the current phase, or loop Dev/QA. v1.2.0: writer + reviewer sub-agents per ticket; real test runner; 8-gate convergence check."
argument-hint: "<intent-statement>"
allowed-tools: ["Bash(${CLAUDE_PLUGIN_ROOT}/scripts/foundry-init.sh:*)", "Bash(${CLAUDE_PLUGIN_ROOT}/scripts/foundry-state.sh:*)", "Bash(${CLAUDE_PLUGIN_ROOT}/scripts/verify.sh:*)", "Bash(${CLAUDE_PLUGIN_ROOT}/scripts/foundry-test-runner.sh:*)", "Bash(${CLAUDE_PLUGIN_ROOT}/scripts/foundry-check-convergence.sh:*)", "Bash(${CLAUDE_PLUGIN_ROOT}/scripts/foundry-auto-detect-test.sh:*)", "Bash(${CLAUDE_PLUGIN_ROOT}/scripts/foundry-spawn-writer.sh:*)", "Bash(${CLAUDE_PLUGIN_ROOT}/scripts/foundry-spawn-reviewer.sh:*)", "Bash(${CLAUDE_PLUGIN_ROOT}/scripts/foundry-spawn-cross-reviewer.sh:*)", "Bash(${CLAUDE_PLUGIN_ROOT}/scripts/foundry-spawn-qa-planner.sh:*)", "Agent"]
hide-from-slash-command-tool: "false"
---

# /foundry — AI-Engineering Foundry

## Usage

```
/foundry "<intent-statement>"
```

`$foundry` is an alias for `/foundry` (define in your shell: `alias $foundry='/foundry'`).

## What this command does

1. Bootstraps `.foundry/` in the current project (if not present).
2. **Auto-detects test runner** from `package.json` / `pyproject.toml` / `go.mod` / `Cargo.toml` and pre-populates the `test:` block in `state.md` (override with `/foundry-test-config`).
3. Reads `.foundry/state.md` to find the current phase.
4. Writes the user's intent statement to `.foundry/idea/intent.md` (creating the file with frontmatter).
5. Dispatches to the appropriate phase skill via the Skill tool:
   - Phase 1 (Idea / grill-me) — `skills/foundry-idea/`
   - Phase 2 (Research / conditional) — `skills/foundry-research/`
   - Phase 3 (Prototype / conditional) — `skills/foundry-prototype/`
   - Phase 4 (PRD) — `skills/foundry-prd/`
   - Phase 5 (TDD test specs) — `skills/foundry-tdd/` — **frozen before planning**
   - Phase 6 (Plan / Kanban) — `skills/foundry-plan/`
   - Phase 7 (Execution loop / Ralph, with writer sub-agent per ticket) — `skills/foundry-execute/`
   - Phase 8 (QA, with reviewer + cross-reviewer + planner sub-agents + 8-gate convergence check) — `skills/foundry-qa/`
6. Surfaces phase status to the user.

## Bootstrap step (mandatory)

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/foundry-init.sh" --intent "$ARGUMENTS"
```

This script:
- Creates `.foundry/` directory if missing.
- Creates `.foundry/state.md` from `templates/state.md` if missing.
- Creates `.foundry/idea/intent.md` from `templates/intent.md` if missing.
- Updates `state.md` with `current_phase = idea`.
- Auto-detects test runner (jest / vitest / pytest / go-test / cargo-test) and pre-populates `test:` block.
- Logs the bootstrap event to `.foundry/logs/bootstrap.log`.

## Phase dispatch

After bootstrap, invoke the phase skill:

```
Use the Skill tool with skill name "foundry-idea" (or whichever phase is current per state.md)
```

The skill owns the full ceremonial conversation for that phase. When it completes, it updates `state.md` and (if `auto_loop: true`) the stop-hook advances to the next phase.

## Auto-loop behaviour (v1.2.0 — fresh sub-agents per ticket)

If `.foundry/state.md` has `auto_loop: true` and the current phase is in the Dev/QA loop (7/8), the **stop-hook** (`hooks/stop-hook.sh`) will:
1. Run the phase verifier (`scripts/verify.sh <phase>` — for execute + qa, runs the **real** test runner + convergence check).
2. If verified, advance to the next phase.
3. Re-feed the focus prompt to the agent.

The focus prompts for Phase 7 (execute) and Phase 8 (qa) explicitly instruct the orchestrator to **spawn fresh-context sub-agents** via the Agent tool:
- **Writer** (`profileId="general-purpose"`, role from `agents/foundry-writer.md`): implements one ticket, runs TDD, commits, updates board.
- **Per-ticket Reviewer** (`profileId="Explore"`, role from `agents/foundry-reviewer.md`): reviews cognitive-debt, comprehension-debt, security, perf, a11y, error-handling, edge cases.
- **Cross-ticket Reviewer** (`profileId="Explore"`, role from `agents/foundry-cross-reviewer.md`): finds orphaned code, dead exports, pattern drift.
- **QA Planner** (`profileId="general-purpose"`, role from `agents/foundry-qa-planner.md`): synthesises all reviews into a structured `qa-plan.md` with `findings:` + `convergence:` blocks.

This produces the **Ralph loop** behaviour across fresh contexts: the model never accumulates prior-failure bias, and the 8-gate convergence check ensures shipping is gated on real test results + zero high-severity findings + human sign-off.

## Cross-cutting skills (auto-loaded)

| Trigger | Skill |
|---------|-------|
| Context > 80% of window | `foundry-context-rotate` |
| After every commit | `foundry-literate-diff` |
| Manual `/foundry-eval` | `foundry-agent-eval` |
| Auto-on-converge | `skill-improver` (after /foundry-signoff) |

## State file

All phase state lives in `.foundry/state.md` in the project root. The orchestrator, hooks, and skills all read/write this file. Key blocks:
- `test:` — test runner, cmd, coverage_cmd, lint_cmd, typecheck_cmd (auto-populated by `foundry-auto-detect-test.sh`).
- `models:` — model per sub-agent role (writer, reviewer, cross_reviewer, qa_planner). Default: sonnet/lite/lite/sonnet.
- `signoff:` — `user_signed_off: true/false`. Required for the 8th convergence gate.

## See also

- `/foundry-status` — show current pipeline state (including test config, models, signoff, convergence)
- `/foundry-loop-on` / `/foundry-loop-off` — toggle auto-loop (validates test config before enabling)
- `/foundry-reset` — reset pipeline (preserves templates; clears test config + signoff)
- `/foundry-signoff` — mark pipeline as user-signed-off (gate 8 of convergence)
- `/foundry-test-config` — view/edit the `test:` block
- `/foundry-idea`, `/foundry-research`, `/foundry-prototype`, `/foundry-prd`, `/foundry-tdd`, `/foundry-plan`, `/foundry-execute`, `/foundry-qa` — jump to a specific phase
- `/foundry-eval` — run the agent-eval harness
- `Knowledge Base/analysis/analysis_ai-engineering-practices-deep-research_2026-07-03.md` — the design source