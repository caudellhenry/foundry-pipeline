---
description: "/foundry-signoff — Mark the pipeline as user-signed-off (gate 8 of convergence). Sets state.md signoff.user_signed_off=true and current_phase=complete. Optional --by=<name> to record who signed off; optional <TICKET> to also approve that ticket's review (gate 2)."
argument-hint: "[<STORY-ID>] [--by=<name>]"
allowed-tools: ["Bash(${CLAUDE_PLUGIN_ROOT}/scripts/foundry-state.sh:*)", "Bash(${CLAUDE_PLUGIN_ROOT}/scripts/foundry-check-convergence.sh:*)"]
---

# /foundry-signoff — Mark pipeline signed-off (gate 8 of convergence)

When the 8-gate convergence check passes (or you want to override remaining failures with a human judgement call), this command:

1. Approves a specific per-ticket review (`human_approved: true`) if `<STORY-ID>` is passed.
2. Sets `state.md signoff.user_signed_off: true` and `signed_off_at: <ISO>` and `signed_off_by: <name>`.
3. If `current_phase == qa`, advances to `current_phase: complete`.
4. Surfaces the current convergence status.

```bash
# Sign off the whole pipeline
bash scripts/foundry-state.sh signoff --by=henry

# Sign off AND approve a specific review (gate 2)
bash scripts/foundry-state.sh approve-review STORY-001
bash scripts/foundry-state.sh signoff --by=henry

# Roll back (only if you jumped the gun)
bash scripts/foundry-state.sh unsignoff
```

## What this command does NOT do

- It does NOT skip any of the 8 convergence gates. If you sign off while gates are still failing, the pipeline is marked `complete` but the convergence check still shows what's failing. You can review the failures via `foundry-check-convergence.sh` after signing off.
- It does NOT merge to main, push to remote, or open a PR. Those are configured per-platform via `state.md phases.execute.platform` (none | github | gitlab) and the underlying connector CLI (`gh`, `glab`).

## When to use

- All 8 gates are green → run `/foundry-signoff` to complete the pipeline.
- Some gates are still failing but you have a good reason → run `/foundry-signoff` to acknowledge; the user takes responsibility.
- You signed off too early → run `/foundry-state.sh unsignoff` to roll back, then fix what's needed, then sign off again.

## See also

- `/foundry-status` — see current convergence state + signoff status
- `/foundry-loop-off` — pause auto-loop first if you want to inspect before signing off
- `Knowledge Base/analysis/.learnings/LEARNINGS.md` — `LRN-20260704-...` entries that explain why signoff is explicit rather than automatic