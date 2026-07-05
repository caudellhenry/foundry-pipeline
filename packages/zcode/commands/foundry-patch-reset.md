---
description: Discard local foundry-pipeline edits and reinstall canonical v2.0.0
argument-hint: ""
hide-from-slash-command-tool: "false"
foundry_version: 2.0.0
---

# `/foundry:patch-reset`

DESTRUCTIVE — discards all local edits and re-installs canonical `v2.0.0`.

## Behaviour

1. **Backup** — copies the current install to `~/.foundry/patch-reset-backups/<timestamp>/`.
2. **Confirm** — prompts "Are you sure you want to discard local edits? [y/N]". Requires explicit `y`.
3. **Re-install** — re-clones (or re-extracts) from canonical `v2.0.0` tag, depending on harness.

## When to use

- Local edits were experiments you no longer want.
- You want to start over from clean canonical.

## Exit codes

- 0 — reset complete
- 1 — user cancelled (no destructive action taken)
- 2 — backup failed
- 3 — re-install failed