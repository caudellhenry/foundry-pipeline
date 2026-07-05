---
description: "/foundry-idea — Jump to Phase 1 (Idea) of the foundry. Runs the grill-me interview to capture intent and risks."
argument-hint: "[intent-statement]"
allowed-tools: ["Bash(${CLAUDE_PLUGIN_ROOT}/scripts/foundry-state.sh:*)"]
---

# /foundry-idea — Phase 1 Idea

Forces entry to Phase 1 of the foundry. Runs the **grill-me** interview ceremony and produces `.foundry/idea/{intent,risks}.md`.

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/foundry-state.sh" set-phase idea
```

Then invoke the skill:

```
Use the Skill tool with skill name "foundry-idea"
```

The skill will:
1. Confirm Phase 1 is current in `state.md`.
2. Run the grill-me interview.
3. Produce `intent.md` and `risks.md`.
4. Update `state.md` and advance to Phase 2 (or wait for `/foundry-research`).

See `skills/foundry-idea/SKILL.md` for the full ceremony.