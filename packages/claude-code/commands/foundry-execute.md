---
description: "/foundry-execute — Jump to Phase 6 (Execution loop / Ralph) of the foundry. Drives the coding agent through the board, one ticket per iteration. v1.2.0 spawns a fresh-context writer sub-agent per ticket via the Agent tool."
argument-hint: ""
allowed-tools: ["Bash(${CLAUDE_PLUGIN_ROOT}/scripts/foundry-state.sh:*)", "Bash(${CLAUDE_PLUGIN_ROOT}/scripts/foundry-loop.sh:*)", "Bash(${CLAUDE_PLUGIN_ROOT}/scripts/verify.sh:*)", "Bash(${CLAUDE_PLUGIN_ROOT}/scripts/foundry-test-runner.sh:*)", "Bash(${CLAUDE_PLUGIN_ROOT}/scripts/foundry-spawn-writer.sh:*)", "Agent"]
---

# /foundry-execute — Phase 6 Execution loop (Ralph)

Forces entry to Phase 6 of the foundry. Starts the Ralph loop that drives the coding agent through the kanban board, one ticket per iteration.

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/foundry-state.sh" set-phase execute
bash "${CLAUDE_PLUGIN_ROOT}/scripts/foundry-loop.sh" execute
```

Then invoke the skill:

```
Use the Skill tool with skill name "foundry-execute"
```

The skill will (v1.2.0):
1. Read `.foundry/plan/board.md` and pick the next unblocked ticket.
2. **Spawn a fresh-context writer sub-agent** via the Agent tool:
   - `profileId = "general-purpose"`, `description = "Implement <TICKET> via TDD"`
   - `prompt = $(bash scripts/foundry-spawn-writer.sh <TICKET>)` (role-prompt + per-ticket payload)
   - `outputFile = .foundry/tdd/<TICKET>.md`
3. After writer returns, **run real verification**:
   - `scripts/verify.sh execute <TICKET>` — actually runs the project's test_cmd + coverage_cmd + lint_cmd + typecheck_cmd via `scripts/foundry-test-runner.sh <TICKET>`. Caches by commit.
4. If verified: move ticket from In progress to Review (or Done if `reviewer_required: false`).
5. If not verified: re-feed the test-runner JSON's `reason` back to the next writer spawn (Ralph re-entry).
6. Loop until board empty or `auto_loop: false` or `DEV_PIPELINE_MAX_ITER` reached.

For AFK behaviour, also run `/foundry-loop-on` so the stop-hook continues the loop.

The writer sub-agent's role prompt is at `agents/foundry-writer.md` (will be loaded into the prompt body by `scripts/foundry-spawn-writer.sh`).

See `skills/foundry-execute/SKILL.md`.