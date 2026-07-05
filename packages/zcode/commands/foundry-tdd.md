---
description: "/foundry-tdd — Jump to Phase 5 (TDD test specs) of the foundry. Produces one .foundry/tdd/<STORY-ID>.md per PRD user story, defining the tests that must pass for Definition of Done."
argument-hint: ""
allowed-tools: ["Bash(${CLAUDE_PLUGIN_ROOT}/scripts/foundry-state.sh:*)"]
---

# /foundry-tdd — Phase 5 TDD Test Specs

Forces entry to Phase 5 of the foundry. Reads `.foundry/prd.md` and produces one `.foundry/tdd/<STORY-ID>.md` per user story, defining the tests that must pass for DoD.

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/foundry-state.sh" set-phase tdd
```

Then invoke the skill:

```
Use the Skill tool with skill name "foundry-tdd"
```

The skill will:
1. Read `.foundry/prd.md` user stories + acceptance criteria.
2. For each story, walk through acceptance criteria → test cases → test contract.
3. Write `.foundry/tdd/<STORY-ID>.md` per story.
4. Update `state.md` and advance to Phase 6 (or wait for `/foundry-plan`).

See `skills/foundry-tdd/SKILL.md`.