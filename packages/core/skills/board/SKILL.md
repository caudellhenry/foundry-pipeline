---
name: foundry-board
description: Phase 6 of the foundry — the Board step (push to tracker). Reads the PRD + local kanban (features + stories from /foundry-plan) and dispatches each user story / enabler to the configured tracker backend (local | github | linear). When the backend is `local`, writes issues as markdown files under .foundry/issues/. When `github` or `linear`, calls the tracker's create-issue API, caches the returned ID into the story frontmatter, and posts the same vertical-slice + acceptance-criteria body the local write would. Idempotent: re-runs skip already-pushed stories (those with a tracker-id field set in frontmatter). Use when /foundry:board is invoked or when the pipeline auto-advances from Phase 5.
---
foundry_version: 2.1.0

# Phase 6 — Board (push to tracker)

> *"The board is the source of truth for what the agent is allowed to pick up next — but the tracker is the source of truth for the team."* — Foundry principle

This phase turns the **local kanban** produced by Phase 5 (`/foundry-plan`) into a **pushed tracker board** so the team can see, triage, and discuss tickets without needing direct access to `.foundry/`. Local-first design is preserved: the loop still reads from `.foundry/plan/board.md`; the tracker is a parallel surface for humans + cross-repo views.

## When to run

- `/foundry:board` is invoked.
- Pipeline auto-advances from Phase 5 (`/foundry-plan`).
- The user says "push to github", "sync board", or "create issues".

## Inputs

- `.foundry/prd.md`
- `.foundry/plan/features.md`
- `.foundry/plan/stories/*.md` — one per user story / enabler
- `.foundry/plan/board.md` — local kanban, kept in sync (the loop reads from this)
- `.foundry/state.md` — must contain `tracker:` block with `backend:`

## Tracker configuration

Read from `.foundry/state.md`:

```yaml
tracker:
  backend: local          # local | github | linear
  repo: owner/name        # github only (e.g. caudellhenry/rally)
  team_id: <UUID>         # linear only
  github_owner_id: <node> # github Projects v2 only (optional)
```

When `backend: local`, this phase still runs — it writes per-story markdown files under `.foundry/issues/` and updates `.foundry/board.md`. The "tracker" is just the filesystem.

When `backend: github` or `linear`, this phase additionally calls the adapter's `tracker_create_issue` and caches the returned ID back into the story frontmatter.

## Ceremony

1. **Read** `.foundry/state.md` to discover the tracker backend (auto-detected; default `local`).
2. **Source the adapter**:
   ```bash
   source packages/zcode/tracker-adapters/interface.sh
   case "$TRACKER_ADAPTER" in
     github) source packages/zcode/tracker-adapters/github/adapter.sh ;;
     linear) source packages/zcode/tracker-adapters/linear/adapter.sh ;;
     local)  source packages/zcode/tracker-adapters/local/adapter.sh ;;
   esac
   tracker_init || exit 1   # HALT-on-connector-failure: see verify.sh pr
   ```
3. **For each** `.foundry/plan/stories/<STORY-ID>.md`:
   - **Skip if already pushed**: if `github_issue_id:` or `linear_issue_id:` is present in the frontmatter, skip (idempotent re-runs).
   - **Build the issue body** from the story's vertical-slice + acceptance-criteria sections + PRD context. See "Issue body template" below.
   - **Build the labels list**:
     - Always: `foundry:story` (or `foundry:enabler` for ENABLER-NNN)
     - Plus priority: `P0`/`P1`/`P2`/`P3` (matches the story frontmatter)
     - The GitHub adapter additionally infers `bug`/`enhancement`/`chore` from foundry labels + title/body keywords (see `_tracker_github_infer_gh_labels`).
   - **Call the adapter**: `tracker_create_issue <title> <body> <labels>` → returns the new ID.
   - **Cache the ID** in the story frontmatter:
     - GitHub: `github_issue_id: "<N>"`, `github_url: <html_url>`
     - Linear: `linear_issue_id: <HAC-N>`, `linear_issue_uuid: <UUID>`, `linear_url: <url>`
     - Local: skip (the file IS the cache).
4. **Update local state**: bump `phases.board.completed_at`, set `current_phase = execute` if `phases.plan.status == complete`.
5. **Print** a per-ticket summary + the tracker URL (or local board path) for human review.

## Issue body template

```
<one-paragraph context from PRD>

## Acceptance criteria
- [ ] <criterion 1>
- [ ] <criterion 2>
...

## Vertical slice
<trace from story frontmatter>

## Out of scope
<bullets from story frontmatter>

---
Imported from foundry via /foundry:board. Local story file: .foundry/plan/stories/<SID>.md
Foundry SID: <SID>
```

## Verifier

Phase 6 is **complete** when:
- `.foundry/state.md` `phases.board.status == complete`
- Every story with `tracker: github` or `tracker: linear` has a `github_issue_id` or `linear_issue_id` field populated.
- `phases.board.completed_at` is set.
- The tracker API responded successfully for every story (no silent failures).

If the tracker API fails (network, auth, rate-limit), the verifier exits FAIL with a list of failed stories. Re-running `/foundry:board` is safe — already-pushed stories are skipped.

## On completion

1. Update `.foundry/state.md`:
   - `phases.board.status = complete`
   - `phases.board.completed_at = <now>`
   - `phases.board.adapter = <backend>`
   - `phases.board.pushed_count = <N>`
   - `current_phase = execute`
2. Prompt:
   - GitHub: `✓ Board pushed to GitHub: <N> issues created. View: <repo URL>`
   - Linear: `✓ Board pushed to Linear: <N> issues created under team <team_id>`
   - Local: `✓ Board created locally: <N> issues under .foundry/issues/. Next: /foundry-execute or /foundry-loop-on`

## Connector-failure semantics

The phase MUST HALT (not silently skip) when:
- `tracker.backend` is `github` or `linear` AND the corresponding CLI / API key is missing.
- The adapter's `tracker_init` returns non-zero.

Same 3-option UX as `verify.sh pr`:
- "(a) install the missing CLI / set the API key"
- "(b) change `tracker.backend: local` in `.foundry/state.md`"
- "(c) skip /foundry:board entirely (loop reads from local kanban directly)"

## Cross-references

- `packages/zcode/scripts/foundry-tracker-push-all.sh` — manual one-shot push of all Ready tickets.
- `packages/zcode/scripts/foundry-tracker-pull-issue.sh` — reverse direction: tracker → local.
- `packages/zcode/scripts/foundry-tracker-writeback.sh` — local status → tracker (state sync).
- `commands/foundry-board.md` — slash command wrapper.
- `commands/foundry-tracker-push-all.md` — manual push command.
- `commands/foundry-tracker-sync.md` — bulk ingest from tracker (reverse direction).