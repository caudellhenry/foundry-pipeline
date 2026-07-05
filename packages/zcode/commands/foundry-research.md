---
description: "/foundry-research — Jump to Phase 2 (Research) of the foundry. Caches per-sprint external knowledge into .foundry/research/research.md with expiry."
argument-hint: ""
allowed-tools: ["Bash(${CLAUDE_PLUGIN_ROOT}/scripts/foundry-state.sh:*)"]
---

# /foundry-research — Phase 2 Research (conditional)

Forces entry to Phase 2 of the foundry. Caches per-sprint external knowledge (third-party APIs, niche libraries, recent breaking changes) into `.foundry/research/research.md` with an explicit expiry date.

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/foundry-state.sh" set-phase research
```

Then invoke the skill:

```
Use the Skill tool with skill name "foundry-research"
```

The skill will:
1. Read `.foundry/idea/intent.md` to understand the research questions.
2. Gather sources via WebFetch / WebSearch.
3. Produce `.foundry/research/research.md` with citations and expiry.
4. Update `state.md` and advance to Phase 3 (or wait for `/foundry-prototype`).

**Skip rule:** if no external knowledge needed, run `/foundry-skip-research` instead. See `skills/foundry-research/SKILL.md`.