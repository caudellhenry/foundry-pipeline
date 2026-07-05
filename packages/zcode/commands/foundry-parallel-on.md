---
description: "/foundry-parallel-on — Enable parallel fan-out (v1.3.0, FR-20260704-009). The orchestrator will spawn up to N writer sub-agents in parallel for independent tickets (board.md ## Parallelisable now). Requires worktree mode (FR-20260704-008) to be enabled."
argument-hint: "[<max_workers=3>]"
allowed-tools: ["Bash(${CLAUDE_PLUGIN_ROOT}/scripts/foundry-state.sh:*)", "Bash(${CLAUDE_PLUGIN_ROOT}/scripts/foundry-worktree.sh:*)"]
---

# /foundry-parallel-on — Enable parallel fan-out (v1.3.0)

Sets `state.md parallel.enabled: true` and `parallel.max_workers: <N>`. The orchestrator will read `board.md` §"## Parallelisable now" and spawn up to N writer sub-agents in parallel, each running in its own worktree.

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/foundry-state.sh" set-parallel enabled 3
```

## Prerequisites

- **`worktree.enabled` must be `true`** (default since v1.3.0). The orchestrator's parallel fan-out depends on per-ticket worktrees to avoid in-flight collisions.
- **The board must have `## Parallelisable now` populated** (a comma-separated list of tickets with no blocking relationships). `/foundry-plan` populates this when the board is generated.
- **`auto_loop: true`** so the stop-hook continues the loop.

## How it works

```
1. Read board.md §"## Parallelisable now"  → up to max_workers tickets
2. For each ticket, create a worktree:
     WT_PATH = foundry-worktree.sh create $TICKET
3. Spawn a writer sub-agent per ticket (one Agent tool call each):
     Agent(profileId=general-purpose, prompt=$(foundry-spawn-writer.sh $TICKET --worktree-path=$WT_PATH))
4. After all writers return, merge + cleanup each ticket serially:
     foundry-worktree.sh merge $TICKET
     foundry-worktree.sh remove $TICKET
     verify.sh execute $TICKET
5. Update board.
```

## Concurrency caveat

ZCode's `Agent` tool may not support true concurrent invocations. If you hit that limit, the orchestrator's focus prompt instructs running the tickets **sequentially within a single turn** (TodoWrite each as `in_progress`, invoke Agent for each, advance to `completed`). The worktree isolation still provides clean per-ticket branches even in serial execution.

For genuine speedup: run **multiple CLI sessions in parallel**, each handling a subset of tickets from `## Parallelisable now`. The board is shared via `.foundry/plan/board.md` on disk, so concurrent sessions can coordinate via the worktrees (each session takes a unique ticket from the list).

## When NOT to enable

- CI doesn't handle parallel-branch pushes well.
- Tickets have shared-file dependencies (rare but possible — the kanban should mark these as blocking, but double-check).
- You want strict serial execution for debugging.

## See also

- `/foundry-loop-on` — auto-loop (also needed for parallel to keep running across turns)
- `foundry-state.sh set-parallel disabled` — turn off
- `Knowledge Base/analysis/.learnings/LEARNINGS.md` — `LRN-20260704-012` (role-prompt sub-agents)