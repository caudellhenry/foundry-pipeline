---
description: Compact the current session's state into a handoff document for resumption in a fresh session
argument-hint: "[--to=<agent-name>]"
hide-from-slash-command-tool: "false"
foundry_version: 2.0.0
---

# `/foundry:handoff`

Backed by the `handoff` skill (`packages/core/skills/handoff/SKILL.md`).

## Behaviour

Writes a `handoff.md` covering:

- **Where things stand** — current phase, board state, last completed ticket
- **Decisions w/ why** — every architectural / product decision made in this session
- **In-flight** — tickets currently in `In progress`, including branch + worktree path
- **Gotchas** — known issues, half-finished work, things to remember
- **Next actions** — what the fresh session / human should do first

## When to use

- Before ending a long session
- Before switching machines
- Before handing work to another person

## Exit codes

- 0 — handoff.md written
- 1 — nothing to handoff (fresh project)