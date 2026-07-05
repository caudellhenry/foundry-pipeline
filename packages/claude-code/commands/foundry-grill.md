---
description: Phase 1 — grill-me interview (one question at a time) for an idea or topic
argument-hint: "<topic-or-idea>"
hide-from-slash-command-tool: "false"
foundry_version: 2.0.0
---

# `/foundry:grill`

Phase 1 — interview the user one question at a time until every branch of the decision tree for a piece of work is resolved.

Backed by the `grill` skill (`packages/core/skills/grill/SKILL.md`).

## Behaviour

1. Loads `.foundry/idea/intent.md` (creates if missing).
2. Asks questions one at a time: Who, What, Why now, Size, Out of scope, Assumptions, Success criteria, Failure modes, Constraints, Pre-mortem.
3. Writes decisions to `intent.md`; risks to `risks.md`.
4. On completion: signals "ready for `/foundry:research`" if external knowledge is needed, else "ready for `/foundry:prd`".

## Exit codes

- 0 — interview complete
- 1 — user cancelled