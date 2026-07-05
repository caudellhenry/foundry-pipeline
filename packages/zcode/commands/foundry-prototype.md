---
description: "/foundry-prototype — Jump to Phase 3 (Prototype) of the foundry. Imposes taste with a tracer bullet before locking the PRD."
argument-hint: ""
allowed-tools: ["Bash(${CLAUDE_PLUGIN_ROOT}/scripts/foundry-state.sh:*)"]
---

# /foundry-prototype — Phase 3 Prototype (conditional)

Forces entry to Phase 3 of the foundry. Iterates a throwaway tracer bullet (UI, architecture, or external-service interaction) and captures taste decisions into `.foundry/prototype/notes.md`.

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/foundry-state.sh" set-phase prototype
```

Then invoke the skill:

```
Use the Skill tool with skill name "foundry-prototype"
```

The skill will:
1. Read `.foundry/idea/intent.md` (and optional research notes).
2. Iterate a tracer bullet in 2–4 sessions.
3. Commit the winner.
4. Produce `.foundry/prototype/notes.md` with decisions locked.
5. Update `state.md` and advance to Phase 4 (or wait for `/foundry-prd`).

**Skip rule:** if the work is purely mechanical (library upgrade, pure refactor, one-line tweak), run `/foundry-skip-prototype` instead. See `skills/foundry-prototype/SKILL.md`.