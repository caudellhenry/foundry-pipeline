---
description: "/foundry-plan — Jump to Phase 5 (Plan / Kanban) of the foundry. Decomposes the PRD into Features + User Stories + Board."
argument-hint: ""
allowed-tools: ["Bash(${CLAUDE_PLUGIN_ROOT}/scripts/foundry-state.sh:*)"]
---

# /foundry-plan — Phase 5 Plan / Kanban

Forces entry to Phase 5 of the foundry. Reads the PRD and decomposes it into Features (parent), User Stories (children) with vertical slices, and a Kanban board with blocking relationships.

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/foundry-state.sh" set-phase plan
```

Then invoke the skill:

```
Use the Skill tool with skill name "foundry-plan"
```

The skill will:
1. Read `.foundry/prd.md`.
2. Identify Features (2–7) and derive User Stories from each.
3. Write `.foundry/plan/features.md`.
4. Write `.foundry/plan/stories/<STORY-ID>.md` (one per story).
5. Write `.foundry/plan/board.md` with status and blocking relationships.
6. Update `state.md` and advance to Phase 6 (or wait for `/foundry-execute`).

See `skills/foundry-plan/SKILL.md`.