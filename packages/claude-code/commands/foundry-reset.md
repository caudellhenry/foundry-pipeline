---
description: "/foundry-reset — Reset pipeline state in the current project (preserves templates; v1.2.0 also clears test config + signoff)."
argument-hint: ""
allowed-tools: ["Bash(${CLAUDE_PLUGIN_ROOT}/scripts/foundry-state.sh:*)"]
---

# /foundry-reset — Reset pipeline state

Resets `.foundry/state.md` and (optionally) deletes phase artefacts. Templates under `templates/` are preserved.

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/foundry-state.sh" reset [--keep-artefacts] [--keep-test-config]
```

Default behaviour (`--keep-artefacts` omitted):
- Delete `.foundry/state.md` (will be re-created on next `/foundry` from `templates/state.md`).
- Delete `.foundry/idea/`, `research/`, `prototype/`, `prd.md`, `plan/`, `tdd/`, `qa/`.
- **v1.2.0**: clear the `test:`, `models:`, and `signoff:` blocks in `state.md` (they'll be re-populated by `foundry-auto-detect-test.sh` on next bootstrap).
- **v1.3.0**: run `scripts/foundry-worktree.sh cleanup` to remove all `<project>-STORY-*` worktrees and delete their `feat/<TICKET>` branches. Confirm before this step.
- Keep `.foundry/logs/`.
- Keep `.foundry/eval/`.

With `--keep-artefacts`:
- Only reset `state.md` to defaults.
- Keep all phase artefacts.

With `--keep-test-config` (v1.2.0):
- Don't clear the `test:` block — preserve manually-configured test commands.
- The `models:` and `signoff:` blocks are still cleared.

Confirmation is required (the script prompts unless `--yes` is passed).

Destructive action — irreversible. Confirm with the user before running.