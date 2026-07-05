---
description: "/foundry-loop-off — Disable auto-loop. The stop-hook will exit cleanly after the current ticket completes."
argument-hint: ""
allowed-tools: ["Bash(${CLAUDE_PLUGIN_ROOT}/scripts/foundry-state.sh:*)"]
---

# /foundry-loop-off — Disable auto-loop

Sets `auto_loop: false` in `.foundry/state.md`. The stop-hook (`hooks/stop-hook.sh`) will exit cleanly after the current ticket / phase completes, surfacing control back to the user.

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/foundry-state.sh" set-loop off
```

Use this when:
- You want to pause AFK execution and inspect the state.
- A new finding needs human review before continuing.
- You're done with the loop and want to stop on the next Stop event.

To resume: `/foundry-loop-on`.