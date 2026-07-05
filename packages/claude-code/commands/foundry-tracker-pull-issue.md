---
description: /foundry-tracker-pull-issue — Fetch a single tracker issue (Linear | GitHub) into a foundry story. Backend is auto-detected from .foundry/state.md `tracker.backend`. Writes the story file under .foundry/plan/stories/, appends to ## Ready in board.md, sets phases.execute.platform=<backend>, and bumps current_phase=execute so the next /foundry-execute picks it up.
argument-hint: "<ISSUE-IDENTIFIER> [--dry-run] [--no-status-flip]"
hide-from-slash-command-tool: "false"
foundry_version: 2.1.0
---

# `/foundry-tracker-pull-issue` — Per-issue tracker → foundry dispatch

Pulls a single tracker issue into the local foundry kanban, ready for the dev+QA loop.

## Backend dispatch

Backend is auto-detected from `.foundry/state.md` `tracker.backend`:

| Backend | Identifier | Local SID |
|---|---|---|
| `linear` | `HAC-42` | `HAC-42` (preserves public id; 1:1 with foundry story) |
| `github` | `42`, `#42`, or full URL `https://github.com/owner/repo/issues/42` | `STORY-42` |
| `local` | (rejected — use the local adapter directly) | — |

## Behaviour

1. Resolve the public identifier to the canonical tracker id:
   - Linear: `HAC-N` → UUID via GraphQL `issues(filter: {identifier: {eq: $id}})` query.
   - GitHub: parse `42` / `#42` / URL → bare number → `GET /repos/$OWNER/$REPO/issues/$N`.
2. Fetch the full issue via the adapter's `tracker_get_issue`:
   - Linear: title, description, state, url, priority, parent.
   - GitHub: title, body, state, html_url, labels[].name.
3. Build the local story file via shared `tracker-pull-common.sh` helpers:
   - Frontmatter: `sid`, `title`, `status: ready`, `imported_from`, `github_issue_id` / `linear_issue_id`, `linear_issue_uuid` (Linear only), `github_url` / `linear_url`, `parent_feature`, `priority`, `estimate: M`, `blocked_by`, `blocks`, `tdd_plan`, `evidence_plan`, `created`, `updated`.
   - Body: imported header + description + acceptance-criteria placeholder.
4. Append the SID to `## In progress` in `.foundry/plan/board.md` (idempotent — skips if already there).
5. Advance `current_phase: execute` so `/foundry-loop-on` picks it up next iteration.
6. (Optional, default ON) Flip the tracker issue to "In Progress" via `tracker_update_status`. Skip with `--no-status-flip`.

## Flags

| Flag | Effect |
|---|---|
| `--dry-run` | Show what would happen; no file writes, no API mutations |
| `--no-status-flip` | Don't flip the tracker issue to "In Progress" on import |

## Examples

```bash
# Linear
/foundry-tracker-pull-issue HAC-42
/foundry-tracker-pull-issue HAC-42 --dry-run
/foundry-tracker-pull-issue HAC-42 --no-status-flip

# GitHub
/foundry-tracker-pull-issue 42
/foundry-tracker-pull-issue '#42' --dry-run
/foundry-tracker-pull-issue https://github.com/me/repo/issues/42
```

## Exit codes

- 0 — pulled (or dry-run)
- 1 — issue not found / network error / auth error
- 2 — invalid args or unknown backend

## Idempotency

Re-running on the same identifier updates the local story body (the latest `tracker_get_issue` fetch) but preserves the STORY-NNN id (so we don't churn the local board). If you want to re-import from scratch, delete the local story file and re-run.

## When to invoke

- Manually, after creating/labeling a new ticket in the tracker (e.g., a GitHub Issue filed by a stakeholder).
- From the "Open in Foundry" link in GitHub Issues (via the `coding-tools.json` integration; see the Linear command for the equivalent).
- After bumping `tracker.backend` from `local` to `github`/`linear` on an existing foundry project (back-fill existing issues).

## See also

- `packages/core/scripts/foundry-tracker-pull-issue.sh` — implementation
- `packages/core/scripts/lib/tracker-pull-common.sh` — shared helpers used by both `pull-issue` and the loop's `tracker_ingest_new`
- `commands/foundry-tracker-sync.md` — bulk version (multiple issues at once)
- `commands/foundry-tracker-push-all.md` — reverse direction (local → tracker)
- `commands/foundry-tracker-writeback.md` — status sync (local → tracker, per ticket)