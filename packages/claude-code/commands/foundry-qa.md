---
description: "/foundry-qa — Jump to Phase 7 (QA) of the foundry. v1.2.0 spawns per-ticket reviewer + cross-ticket reviewer + QA-planner sub-agents via the Agent tool; runs the 8-gate convergence check (machine-checkable). New findings route back to Phase 5 as NEW-### tickets."
argument-hint: ""
allowed-tools: ["Bash(${CLAUDE_PLUGIN_ROOT}/scripts/foundry-state.sh:*)", "Bash(${CLAUDE_PLUGIN_ROOT}/scripts/foundry-loop.sh:*)", "Bash(${CLAUDE_PLUGIN_ROOT}/scripts/foundry-check-convergence.sh:*)", "Bash(${CLAUDE_PLUGIN_ROOT}/scripts/foundry-test-runner.sh:*)", "Bash(${CLAUDE_PLUGIN_ROOT}/scripts/foundry-spawn-reviewer.sh:*)", "Bash(${CLAUDE_PLUGIN_ROOT}/scripts/foundry-spawn-cross-reviewer.sh:*)", "Bash(${CLAUDE_PLUGIN_ROOT}/scripts/foundry-spawn-qa-planner.sh:*)", "Agent"]
---

# /foundry-qa — Phase 7 QA (systematic, machine-checked)

Forces entry to Phase 7 of the foundry. Runs per-ticket reviewer sub-agents + cross-ticket reviewer + QA planner, then checks the 8-gate convergence.

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/foundry-state.sh" set-phase qa
```

Then invoke the skill:

```
Use the Skill tool with skill name "foundry-qa"
```

The skill will (v1.2.0):
1. List every shipped ticket from `.foundry/qa/evidence/STORY-*.md`.
2. **For each shipped ticket, spawn a fresh-context reviewer sub-agent** (Anthropic's writer/reviewer pattern):
   - `profileId = "Explore"`, `description = "Review <TICKET> (cognitive-debt + comprehension-debt)"`
   - `prompt = $(bash scripts/foundry-spawn-reviewer.sh <TICKET>)`
   - `outputFile = .foundry/qa/review/<TICKET>.md`
   - Verdict: APPROVED | NEEDS-FIX | REJECT
3. **Spawn the cross-ticket reviewer** (orphaned code, dead exports, pattern drift, cumulative coverage):
   - `profileId = "Explore"`, prompt = `$(bash scripts/foundry-spawn-cross-reviewer.sh <ROUND> <TICKETS>)`
   - `outputFile = .foundry/qa/review/CROSS-round-<N>.md`
4. **Spawn the QA planner** (synthesise all reviews into `qa-plan.md` with structured `findings:` + `convergence:` blocks):
   - `profileId = "general-purpose"`, prompt = `$(bash scripts/foundry-spawn-qa-planner.sh <ROUND> <TICKETS>)`
   - `outputFile = .foundry/qa/qa-plan.md`
5. **Run the 8-gate convergence check**:
   - `bash scripts/foundry-check-convergence.sh`
   - Gates: Board empty / Review empty / No high findings / No medium findings / Tests pass / Coverage gate / Lint+typecheck clean / User signoff.
6. **If converged**: prompt user with `/foundry-signoff` to mark signed off.
7. **If new findings exist**: route as NEW-### tickets to `.foundry/plan/board.md` `## Ready`, loop back to Phase 6.

Sub-agent role prompts (will be loaded by the spawner scripts):
- `agents/foundry-reviewer.md` (per-ticket, Explore profile)
- `agents/foundry-cross-reviewer.md` (cross-ticket, Explore profile)
- `agents/foundry-qa-planner.md` (synthesis, general-purpose profile)

See `skills/foundry-qa/SKILL.md`.