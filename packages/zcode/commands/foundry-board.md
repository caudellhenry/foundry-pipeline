---
description: Phase 5 — break an approved PRD into vertical-slice tickets on the configured tracker (local / GitHub / Linear)
argument-hint: "[--from-prd=<path>]"
hide-from-slash-command-tool: "false"
foundry_version: 2.0.0
---

# `/foundry:board`

Phase 5 — break an approved PRD into vertical-slice tickets.

Backed by the `board` skill (`packages/core/skills/board/SKILL.md`).

## Behaviour

1. Reads `.foundry/prd.md` and `.foundry/plan/features.md`.
2. For each user story + enabler, calls the configured tracker adapter:
   - **local** — writes `.foundry/issues/STORY-XXX-<slug>.md` and appends to `.foundry/board.md`
   - **github** — `tracker_create_issue` via GitHub MCP
   - **linear** — `tracker_create_issue` via Linear MCP
3. Sets `state.md current_phase = plan`.
4. Prints the new ticket count + tracker URL (or local board path).

## Exit codes

- 0 — board created
- 1 — PRD not approved
- 2 — tracker adapter failed