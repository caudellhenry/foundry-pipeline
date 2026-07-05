---
description: "/foundry-literate-diff — Produce a literate diff for the current commit (or specified commit-hash). Operationalises Geoffrey Litt's /explore-diff."
argument-hint: "[commit-hash]"
allowed-tools: ["Bash(${CLAUDE_PLUGIN_ROOT}/scripts/foundry-state.sh:*)"]
---

# /foundry-literate-diff — Literate diff

Produces a literate diff for the current commit (or a specified commit-hash). The literate diff is a structured prose explanation of what changed, why, and what the maintainer needs to know.

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/foundry-state.sh" literate-diff [commit-hash]
```

The script:
1. Reads the commit diff (`git diff <hash>^ <hash>`).
2. Invokes the literate-diff ceremony:
   - What changed (one sentence).
   - Why (the intent, not the implementation).
   - How it works (3–10 line walk-through).
   - Trade-offs (what we considered and rejected).
   - What could go wrong (risks and mitigations).
   - Quiz (3–5 questions the maintainer should answer).
3. Writes `.foundry/literate/<commit-hash>.md`.

The QA reviewer (Phase 7) reads the literate diff alongside the actual diff to mitigate cognitive debt.

See `skills/foundry-literate-diff/SKILL.md`.