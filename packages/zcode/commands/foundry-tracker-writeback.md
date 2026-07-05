---
description: Write status + summary comment back to the configured tracker (GitHub Issues / Linear) for a single foundry story. Updates the issue's status (closed/reopened, foundry:* label, or Linear workflow state), posts a comment with commit + PR + test counts. Used by the PR sub-loop when a ticket's PR goes green, and by the user to manually update status.
argument-hint: "<SID> --status=<done|blocked|in_progress|review|ready> --summary=<text> [--commit=<sha7>] [--pr=<url>] [--tests=<X/Y>] [--dry-run]"
hide-from-slash-command-tool: "false"
foundry_version: 2.1.0
---

# `/foundry-tracker-writeback` — Status sync (local → tracker)

Pushes the local story's status + a summary comment back to the configured tracker. Backend-agnostic (auto-detected from `.foundry/state.md` `tracker.backend`).

## Behaviour

1. Read `.foundry/plan/stories/<SID>.md` frontmatter:
   - Linear: extract `linear_issue_id` (HAC-N) + `linear_issue_uuid`
   - GitHub: extract `github_issue_id` (number)
   - Local backend: no-op (write a console message and exit 0).
2. Build the comment body from the args:
   - `--summary` (required) — first line is treated as the title, rest as body
   - `--commit`, `--pr`, `--tests` (optional) — appended to the comment
   - Auto-appends: `Foundry dev+QA loop · <ISO timestamp>`
3. Update the issue status:
   - Linear: looks up the workflow state by name (default: Todo/In Progress/In Review/Done/Blocked), with optional `--linear-state-name` override for non-canonical teams.
   - GitHub: maps to the `foundry:<status>` label (e.g., `foundry:done`); on `done`, also closes the issue.
4. Post the comment via `tracker_add_comment`.

Errors are surfaced but non-blocking: if the API call fails, the script exits 0 (writes a warning to stderr) so the loop doesn't break. Re-running with corrected auth will succeed.

## Required args

| Arg | Description |
|---|---|
| `<SID>` | STORY-42 (GitHub) or HAC-42 (Linear) |
| `--status=<s>` | One of `ready \| in_progress \| review \| done \| blocked` |
| `--summary=<text>` | Multi-line summary; first line is title, rest is body |

## Optional args

| Arg | Description |
|---|---|
| `--commit=<sha7>` | Commit hash (added to comment) |
| `--pr=<url>` | PR/MR URL (added to comment) |
| `--tests=<X/Y>` | Test result counts (added to comment) |
| `--status-label=<name>` | Override the foundry:* label (rare) |
| `--linear-state-name=<name>` | Override Linear state name (rare; for non-canonical teams) |
| `--dry-run` | Preview the payload; no API calls |

## Examples

```bash
# Mark ticket done with PR URL + commit
/foundry-tracker-writeback STORY-42 \
  --status=done \
  --summary="Implemented red→green→refactor with full coverage." \
  --commit=abc1234 \
  --pr=https://github.com/me/repo/pull/43

# Mark blocked and route a NEW-### finding
/foundry-tracker-writeback HAC-42 \
  --status=blocked \
  --summary="Blocked: missing API credentials; routed NEW-007 to /foundry-plan"

# Preview without API calls
/foundry-tracker-writeback STORY-42 --status=done --summary="..." --dry-run
```

## Exit codes

- 0 — writeback succeeded (or dry-run)
- 1 — story file missing or no tracker id in frontmatter
- 2 — invalid args

## When to invoke

- **Automatically**: called by `foundry-loop.sh execute` whenever a ticket's PR goes green (see `tracker_writeback_green`).
- **Manually**: after running the writer + tester + verifier, to force-push status to the tracker (the loop's automatic writeback is idempotent and safe to re-trigger).

## See also

- `packages/core/scripts/foundry-tracker-writeback.sh` — the implementation.
- `packages/core/scripts/foundry-post-merge.sh` — runs AFTER writeback when the PR merges (closes the issue + deletes the branch).
- `commands/foundry-tracker-pull-issue.md` — reverse direction.
- `commands/foundry-tracker-sync.md` — bulk sync (multiple issues at once).