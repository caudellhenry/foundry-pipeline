---
description: Phase 6 — push local user stories to the configured tracker backend (local / GitHub / Linear). Reads the local kanban from .foundry/plan/stories/, dispatches each story via tracker_create_issue, and caches the returned ID in the story frontmatter for round-trip.
argument-hint: "[--from-prd=<path>] [--dry-run]"
hide-from-slash-command-tool: "false"
foundry_version: 2.1.0
---

# `/foundry:board`

Phase 6 — push local user stories to the configured tracker backend.

Backed by the `board` skill (`packages/core/skills/board/SKILL.md`).

## Behaviour

1. **Auto-detect** the tracker backend from `.foundry/state.md` `tracker.backend`:
   - `local` (default if unset) — write per-story markdown files under `.foundry/issues/`, append to `.foundry/board.md`.
   - `github` — call `tracker_create_issue` via the GitHub adapter (`gh` CLI / MCP / `$GITHUB_TOKEN`). Caches `github_issue_id` + `github_url` in story frontmatter.
   - `linear` — call `tracker_create_issue` via the Linear adapter (GraphQL / MCP). Caches `linear_issue_id` + `linear_issue_uuid` + `linear_url` in story frontmatter.
2. **For each** user story + enabler in `.foundry/plan/stories/*.md`:
   - Skip if already pushed (tracker-id field present in frontmatter → idempotent re-run).
   - Build the issue body from the story's vertical-slice + acceptance-criteria sections.
   - Build the labels list: `foundry:story` (or `foundry:enabler`), priority `P0/P1/P2/P3`. The GitHub adapter additionally infers `bug`/`enhancement`/`chore` from title/body keywords.
   - Call the adapter; cache the returned ID.
3. **Update** `.foundry/state.md`:
   - `phases.board.status = complete`
   - `phases.board.adapter = <backend>`
   - `phases.board.pushed_count = <N>`
   - `current_phase = execute` (when `phases.plan.status == complete`)
4. **Print** the new ticket count + tracker URL (or local board path).

## Flags

| Flag | Effect |
|---|---|
| `--from-prd=<path>` | Use a non-default PRD path |
| `--dry-run` | Print what would be pushed; do not call any mutation tool |

## Exit codes

- 0 — board pushed
- 1 — PRD not approved / plan phase incomplete
- 2 — tracker adapter failed (e.g. connector failure: `gh` not installed, missing API key)
- 3 — connector-failure HALT (user must resolve before proceeding)

## Connector-failure semantics

When `tracker.backend: github` or `tracker.backend: linear` is set but the matching CLI / API key is missing, the command **HALTs with a 3-option resolution message** (same UX as `verify.sh pr`). It does NOT silently fall back to the local tracker — that would mask a broken CI gate. Options:

- (a) Install the missing CLI / set the API key
- (b) Change `tracker.backend: local` in `.foundry/state.md` (loop reads from local kanban directly)
- (c) Skip `/foundry:board` entirely (the loop can still run local-only)

## When to invoke

- After `/foundry-plan` creates the initial kanban (Phase 5 → 6 transition).
- After adding new features/stories (push them incrementally).
- After fixing a story file's frontmatter (re-push to update).
- The orchestrator's auto-loop also calls this when `phases.execute.platform == github` or `linear` and any Ready ticket lacks a cached tracker id.

## See also

- `commands/foundry-tracker-push-all.md` — manual one-shot push of all Ready tickets (lower-level).
- `commands/foundry-tracker-pull-issue.md` — reverse direction: tracker → local.
- `commands/foundry-tracker-sync.md` — bulk ingest from tracker (reverse direction).
- `packages/core/tracker-adapters/{interface,local,github,linear}/adapter.sh` — backend implementations.