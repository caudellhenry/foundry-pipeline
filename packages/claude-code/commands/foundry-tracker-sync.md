---
description: Bulk-ingest ready issues from the configured tracker (GitHub Issues / Linear) into the local kanban. Runs the same logic the dev-QA loop runs at the start of each iteration, but explicitly and verbose. Useful for back-filling after enabling GitHub Issues for an existing foundry project.
argument-hint: "[--dry-run] [--include-non-ready]"
hide-from-slash-command-tool: "false"
foundry_version: 2.1.0
---

# `/foundry-tracker-sync` — Bulk ingest from tracker

Pulls all `ready` (optionally all) issues from the configured tracker into the local kanban. Idempotent — re-running skips already-imported issues.

## Behaviour

1. Auto-detect `tracker.backend` from `.foundry/state.md` (skip if `local` or unset).
2. Source the configured tracker adapter (`github` or `linear`).
3. Call `tracker_list_issues` (filtered to `status=ready` by default; `--include-non-ready` overrides to all states).
4. For each issue not yet in `.foundry/plan/stories/`, fetch the full issue body and write a story file using the shared `tracker-pull-common.sh` helpers.
5. Append each new story to `## Ready` in `.foundry/plan/board.md` (idempotent).
6. Print a summary: `Tracker ingest: N new, M already, K errors`.

This is the same logic `foundry-loop.sh execute` runs at the start of each iteration, exposed as a standalone command for manual bulk ingestion. The loop auto-syncs; this command is for users who want to back-fill on demand.

## Flags

| Flag | Effect |
|---|---|
| `--dry-run` | Show what would be ingested; no file writes, no API mutations |
| `--include-non-ready` | Ingest issues in any state (not just `ready`). Use for back-filling after enabling GH Issues. |

## Examples

```bash
/foundry-tracker-sync                    # ingest all ready issues
/foundry-tracker-sync --dry-run          # preview only
/foundry-tracker-sync --include-non-ready  # back-fill everything
```

## Exit codes

- 0 — sync complete (or nothing to sync)
- 1 — adapter init failed / connector unavailable
- 2 — invalid args

## Connector-failure semantics

When `tracker.backend: github` or `tracker.backend: linear` is set but the matching CLI / API key is missing, the command HALTs with a clear error (does NOT silently no-op). Same UX as `verify.sh pr`.

## When to invoke

- Right after `git init` + `/foundry-deploy init` + `/foundry-board` on a project that's being wired up to GitHub Issues for the first time (back-fill existing issues).
- After a long gap (e.g., you haven't run the loop in a week and want to ingest the latest issues).
- During debugging — when you want to inspect exactly what would be ingested without running the loop.

## See also

- `packages/core/scripts/foundry-tracker-pull-issue.sh` — single-issue ingest (more targeted).
- `packages/core/scripts/lib/tracker-pull-common.sh` — shared helpers.
- `commands/foundry-tracker-push-all.md` — reverse direction (local → tracker).
- `commands/foundry-tracker-writeback.md` — status sync (local → tracker, per ticket).
- `commands/foundry-board.md` — the push side that mirrors `foundry-tracker-push-all`.