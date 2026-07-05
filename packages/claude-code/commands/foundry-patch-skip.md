---
description: Snooze the local-vs-canonical divergence alert for N days (default 30)
argument-hint: "[--days=30]"
hide-from-slash-command-tool: "false"
foundry_version: 2.0.0
---

# `/foundry:patch-skip`

Snooze the divergence alert.

## Behaviour

Writes a marker file:

```
~/.foundry/patch-skip-until: 2026-08-04
```

Until that date, `/foundry:patch-check` and the SessionStart hook exit 0 silently.

## When to use

- You're knowingly experimenting with local edits
- You want to defer the push decision

## Exit codes

- 0 — snooze set
- 1 — could not write marker file