---
description: Upgrade foundry-pipeline — fetch latest tag, switch, clean orphan symlinks from prior installs (e.g. v2.0.1), re-run workspace installer.
argument-hint: "[--to=vX.Y.Z] [--dry-run] [--no-fetch] [--no-reinstall] [--no-verify]"
allowed-tools: ["Bash(${CLAUDE_PLUGIN_ROOT}/../../../../Skills/foundry-pipeline/packages/core/scripts/foundry-upgrade.sh:*)", "Bash(${CLAUDE_PLUGIN_ROOT}/../../../../Skills/foundry-pipeline/packages/core/scripts/foundry-install-workspace.sh:*)"]
foundry_version: 2.0.2
---

# `/foundry:upgrade`

One-shot upgrade of the canonical foundry-pipeline clone to a newer tag.
Pulls tags, switches, removes any orphan symlinks left by prior installs
(notably the **v2.0.1 path bug** — plugin-style harnesses wrote to
`~/.zcode/cli/plugins/cache/<ver>` instead of
`~/.zcode/cli/plugins/cache/foundry-pipeline/<ver>`), then re-runs the
workspace installer. Idempotent.

## Usage

```bash
# Upgrade to the latest released tag (default)
bash "$HOME/Agents Workspace/Skills/foundry-pipeline/packages/core/scripts/foundry-upgrade.sh"

# Upgrade to a specific version
bash "$HOME/Agents Workspace/Skills/foundry-pipeline/packages/core/scripts/foundry-upgrade.sh" --to=v2.0.2

# Preview only (no disk changes)
bash "$HOME/Agents Workspace/Skills/foundry-pipeline/packages/core/scripts/foundry-upgrade.sh" --dry-run

# Just clean orphans + reinstall, skip git fetch (use when offline)
bash "$HOME/Agents Workspace/Skills/foundry-pipeline/packages/core/scripts/foundry-upgrade.sh" --no-fetch
```

## Flags

| Flag | Purpose |
|---|---|
| `--to=vX.Y.Z` | Pin to a specific tag (default: latest `v*`) |
| `--source=<dir>` | Override canonical clone location |
| `--workspace=<dir>` | Override workspace root |
| `--no-fetch` | Skip `git fetch --tags` |
| `--no-reinstall` | Skip reinstall (only clean orphans) |
| `--no-verify` | Skip the post-install verify step |
| `--dry-run` | Print what would happen; no disk changes |

## What it does

1. `git fetch --tags` in the canonical clone
2. `git checkout <target>` (latest tag, or `--to=vX.Y.Z`)
3. **Removes orphan symlinks** from the v2.0.1 install bug:
   - `~/.claude/plugins/cache/<ver>` (should be `.../foundry-pipeline/<ver>`)
   - `~/.zcode/cli/plugins/cache/<ver>` (same)
   - `~/.antigravity/plugins/<ver>` (same)
   - `~/.mimocode/plugins/<ver>` (same)
   - and the workspace-level mirrors
4. `foundry-install-workspace.sh` — refresh symlinks everywhere
5. Verifies the 4 plugin-style harness symlinks resolve

## Exit codes

- `0` — upgrade complete + verified
- `1` — upgrade ran but some symlinks missing
- `2` — invocation error (bad flag, missing clone)