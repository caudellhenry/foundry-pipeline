---
description: "/foundry-prd — Jump to Phase 4 (PRD) of the foundry. Produces the destination document at .foundry/prd.md describing end-state behaviour."
argument-hint: ""
allowed-tools: ["Bash(${CLAUDE_PLUGIN_ROOT}/scripts/foundry-state.sh:*)"]
---

# /foundry-prd — Phase 4 PRD

Forces entry to Phase 4 of the foundry. Runs the **to-prd** ceremony and produces `.foundry/prd.md` — the destination document describing end-state behaviour (NOT implementation).

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/foundry-state.sh" set-phase prd
```

Then invoke the skill:

```
Use the Skill tool with skill name "foundry-prd"
```

The skill will:
1. Read `.foundry/idea/intent.md`, `risks.md`, optional research and prototype notes.
2. Run the to-prd ceremony: grill-me through each PRD section (problem statement, personas, goals, non-goals, user stories, acceptance criteria, end-state behaviour, edge cases, open questions, glossary).
3. Produce `.foundry/prd.md` with spec-kit-compatible structure.
4. Update `state.md` and advance to Phase 5 (TDD specs, `/foundry-tdd`) — or wait for the next phase.

See `skills/foundry-prd/SKILL.md`.