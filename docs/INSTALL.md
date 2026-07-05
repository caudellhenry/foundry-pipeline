# Install — workspace pattern (v2.0.1+)

> **One canonical clone, symlinks everywhere.** Update once, push to every harness at once.
> The per-harness scripts still exist (Pattern B below) for edge cases, but the
> recommended install is `foundry-install-workspace.sh`.

Single source of truth: [`caudellhenry/foundry-pipeline`](https://github.com/caudellhenry/foundry-pipeline).

---

## Pattern A — workspace install (recommended)

A single clone lives at `~/Agents Workspace/Skills/foundry-pipeline/`. Every
harness plugin dir (home + workspace) is a symlink into that clone. Updating
is a `git pull` in one place.

### One-time setup

```bash
# 1. Clone into the canonical workspace location
git clone https://github.com/caudellhenry/foundry-pipeline.git \
  "$HOME/Agents Workspace/Skills/foundry-pipeline"
cd "$HOME/Agents Workspace/Skills/foundry-pipeline"
git checkout v2.0.1   # pin to a release

# 2. Remove any legacy/duplicate installs (optional but recommended)
bash packages/core/scripts/foundry-cleanup-all.sh

# 3. Wire every harness (home + workspace) via symlinks
bash packages/core/scripts/foundry-install-workspace.sh
```

That's it. The script:

- Builds the monorepo (`foundry-monorepo-build.sh`)
- Symlinks `packages/<harness>` into `~/<harness>/plugins/...`
- Symlinks `packages/<harness>` into `~/Agents Workspace/.<harness>/...`
- Idempotent — re-running just refreshes links

### Update to a new version

```bash
cd "$HOME/Agents Workspace/Skills/foundry-pipeline"
git fetch --tags
git checkout v2.0.2   # or whatever the new tag is
bash packages/core/scripts/foundry-install-workspace.sh   # refresh links
```

### Harness coverage (13)

| Harness | Home target | Workspace target |
|---|---|---|
| Claude Code | `~/.claude/plugins/cache/foundry-pipeline/<ver>` | `~/Agents Workspace/.claude/plugins/cache/foundry-pipeline/<ver>` |
| Zcode | `~/.zcode/cli/plugins/cache/foundry-pipeline/<ver>` | `~/Agents Workspace/.zcode/cli/plugins/cache/foundry-pipeline/<ver>` |
| Hermes | `~/.hermes/skills/foundry-*` | `~/Agents Workspace/.hermes/skills/foundry-*` |
| OpenCode | `~/.opencode/skills/foundry-*` | `~/Agents Workspace/.opencode/skills/foundry-*` |
| Antigravity | `~/.antigravity/plugins/foundry-pipeline/<ver>` | `~/Agents Workspace/.antigravity/plugins/foundry-pipeline/<ver>` |
| MimoCode | `~/.mimocode/plugins/foundry-pipeline/<ver>` | `~/Agents Workspace/.mimocode/plugins/foundry-pipeline/<ver>` |
| skills-sh | `~/.skills-sh/skills/foundry-*` | `~/Agents Workspace/.skills-sh/skills/foundry-*` |
| MiniMax | `~/.minimax/skills/foundry-*` | `~/Agents Workspace/.minimax/skills/foundry-*` |
| Cursor | `~/.cursor/skills/foundry-*` | `~/Agents Workspace/.cursor/skills/foundry-*` |
| Codex | `~/.codex/skills/foundry-*` | `~/Agents Workspace/.codex/skills/foundry-*` |
| Windsurf | `~/.windsurf/skills/foundry-*` | `~/Agents Workspace/.windsurf/skills/foundry-*` |
| Cline | `~/.cline/skills/foundry-*` | `~/Agents Workspace/.cline/skills/foundry-*` |
| Gemini | `~/.gemini/skills/foundry-*` | `~/Agents Workspace/.gemini/skills/foundry-*` |

### Escape hatch — copy mode

If you want a real copy instead of a symlink (e.g. air-gapped / read-only
filesystem), pass `--copy` or set the env var:

```bash
FOUNDRY_INSTALL_COPY=1 bash packages/core/scripts/foundry-install-workspace.sh
```

The same flag is honored by the per-harness scripts (Pattern B).

### Restrict to one harness

```bash
# Only update antigravity links
bash packages/core/scripts/foundry-install-workspace.sh --harness=antigravity

# Only home (no workspace)
bash packages/core/scripts/foundry-install-workspace.sh --home-only

# Only workspace
bash packages/core/scripts/foundry-install-workspace.sh --workspace-only
```

### Verify

```bash
ls -l ~/.antigravity/plugins/foundry-pipeline/2.0.1 \
       ~/.mimocode/plugins/foundry-pipeline/2.0.1 \
       ~/Agents Workspace/.antigravity/plugins/foundry-pipeline/2.0.1
# expect: all three are symlinks → $WORKSPACE/Skills/foundry-pipeline/packages/<harness>

bash "$HOME/Agents Workspace/Skills/foundry-pipeline/scripts/foundry-self-test.sh"
bash "$HOME/Agents Workspace/Skills/foundry-pipeline/scripts/foundry-version-check.sh"
```

---

## Pattern B — per-harness install (legacy / escape hatch)

Use the per-harness scripts when you can't or won't use the workspace clone —
e.g. on a machine where `~/Agents Workspace` doesn't exist, or when installing
just one harness.

```bash
# One-shot clone + install for a single harness
git clone --depth 1 --branch v2.0.1 \
  https://github.com/caudellhenry/foundry-pipeline.git /tmp/foundry-pipeline
bash /tmp/foundry-pipeline/packages/<harness>/install.sh
# Default mode is symlink in v2.0.1+. Force copy with FOUNDRY_INSTALL_COPY=1.
```

| Harness | Install command |
|---|---|
| Claude Code | `bash /tmp/foundry-pipeline/packages/claude-code/install.sh` |
| Zcode | `bash /tmp/foundry-pipeline/packages/zcode/install.sh` |
| Hermes | `bash /tmp/foundry-pipeline/packages/hermes/install.sh` |
| OpenCode | `bash /tmp/foundry-pipeline/packages/opencode/install.sh` |
| Antigravity | `bash /tmp/foundry-pipeline/packages/antigravity/install.sh` |
| MimoCode | `bash /tmp/foundry-pipeline/packages/mimocode/install.sh` |
| skills.sh | `npx skills add caudellhenry/foundry-pipeline` |

---

## Uninstall

Pattern A: `bash packages/core/scripts/foundry-cleanup-all.sh` (backs up to `~/.foundry.bak.<ts>/` first).

Pattern B:

```bash
bash /tmp/foundry-pipeline/packages/<harness>/install.sh --uninstall
```

---

## Prerequisites (all harnesses)

- `bash >= 4.0` (macOS 3.2 compat: no `declare -i`, no new assoc arrays)
- `jq >= 1.6` (for tracker adapters + version sync)
- `git >= 2.30` (for patch detection)
- A terminal where your AI coding agent runs

---

## Troubleshooting

| Symptom | Fix |
|---|---|
| `jq: command not found` | `brew install jq` (mac) / `apt install jq` (linux) |
| Slash command not found | Restart your agent; some harnesses cache the command list |
| `Permission denied` on install.sh | `chmod +x packages/*/install.sh packages/core/scripts/*.sh` |
| Version drift between packages | `bash scripts/foundry-version-sync.sh` (from a checkout) |
| Patch detection always fires | `/foundry:patch-skip 30` to snooze 30 days |
| `git pull` doesn't update installed plugin | Re-run `foundry-install-workspace.sh` to refresh links |
| Need a copy not a symlink (read-only fs) | `FOUNDRY_INSTALL_COPY=1 bash foundry-install-workspace.sh` |
| Leftover legacy dirs from v1.x | `bash packages/core/scripts/foundry-cleanup-all.sh --dry-run` first, then run without `--dry-run` |