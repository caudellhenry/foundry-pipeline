# Install — per-harness matrix (v2.0.0)

> Single source of truth: `caudellhenry/foundry-pipeline`. This doc covers every supported harness.

---

## Prerequisites (all harnesses)

- `bash >= 4.0`
- `jq >= 1.6` (for tracker adapters + version sync)
- `git >= 2.30` (for patch detection)
- A terminal where your AI coding agent runs (Claude Code, Zcode, etc.)

---

## Quick matrix

| Harness | Install command |
|---|---|
| **Claude Code** | `/plugin marketplace add caudellhenry/foundry-pipeline` (after marketplace is published) |
| **Zcode** | `git clone https://github.com/caudellhenry/foundry-pipeline.git /tmp/foundry-pipeline && bash /tmp/foundry-pipeline/packages/zcode/install.sh` |
| **Hermes** | `git clone https://github.com/caudellhenry/foundry-pipeline.git /tmp/foundry-pipeline && bash /tmp/foundry-pipeline/packages/hermes/install.sh` |
| **OpenCode** | `git clone https://github.com/caudellhenry/foundry-pipeline.git /tmp/foundry-pipeline && bash /tmp/foundry-pipeline/packages/opencode/install.sh` |
| **Antigravity** | `git clone https://github.com/caudellhenry/foundry-pipeline.git /tmp/foundry-pipeline && bash /tmp/foundry-pipeline/packages/antigravity/install.sh` |
| **MimoCode** | `git clone https://github.com/caudellhenry/foundry-pipeline.git /tmp/foundry-pipeline && bash /tmp/foundry-pipeline/packages/mimocode/install.sh` |
| **skills.sh** (skills only, no commands/hooks) | `npx skills add caudellhenry/foundry-pipeline` |

After install, verify:

```bash
# Should print "All packages in sync with VERSION=2.0.0"
bash ~/.claude/plugins/cache/foundry-pipeline/2.0.0/scripts/foundry-version-check.sh
# (or the equivalent path for your harness)
```

---

## Per-harness details

### Claude Code

```bash
# 1. Add the marketplace (one-time)
/plugin marketplace add caudellhenry/foundry-pipeline

# 2. Install the plugin
/plugin install foundry-pipeline@foundry-pipeline-marketplace

# 3. Verify
/foundry:status
```

### Zcode

```bash
# Symlink to the Zcode plugin cache
git clone https://github.com/caudellhenry/foundry-pipeline.git /tmp/foundry-pipeline
bash /tmp/foundry-pipeline/packages/zcode/install.sh
# Creates ~/.zcode/cli/plugins/cache/foundry-pipeline/2.0.0/ symlink
```

### Hermes

```bash
git clone https://github.com/caudellhenry/foundry-pipeline.git /tmp/foundry-pipeline
bash /tmp/foundry-pipeline/packages/hermes/install.sh
# Creates ~/.hermes/skills/foundry-{ship,grill,prd,...}/ symlinks
```

### OpenCode

```bash
git clone https://github.com/caudellhenry/foundry-pipeline.git /tmp/foundry-pipeline
bash /tmp/foundry-pipeline/packages/opencode/install.sh
# Creates ~/.opencode/skills/foundry-{ship,grill,prd,...}/ symlinks
```

### Antigravity

```bash
git clone https://github.com/caudellhenry/foundry-pipeline.git /tmp/foundry-pipeline
bash /tmp/foundry-pipeline/packages/antigravity/install.sh
# Creates ~/.antigravity/plugins/foundry-pipeline/2.0.0/
```

### MimoCode

```bash
git clone https://github.com/caudellhenry/foundry-pipeline.git /tmp/foundry-pipeline
bash /tmp/foundry-pipeline/packages/mimocode/install.sh
# Creates ~/.mimocode/plugins/foundry-pipeline/2.0.0/
```

### skills.sh (skills only)

```bash
npx skills add caudellhenry/foundry-pipeline
# Skills auto-discovered via the Agent Skills standard.
# No slash commands; skills auto-invoke based on description match.
```

---

## Update

To update to a newer version:

```bash
# Re-run the install script (it re-creates symlinks against the new tag)
git -C /tmp/foundry-pipeline fetch --tags
git -C /tmp/foundry-pipeline checkout v2.0.1   # or whatever the new tag is
bash /tmp/foundry-pipeline/packages/<your-harness>/install.sh
```

Or use the in-agent patch detection:

```
/foundry:patch-check
/foundry:patch-diff
/foundry:patch-reset     # re-install canonical
```

---

## Uninstall

```bash
bash /tmp/foundry-pipeline/packages/<your-harness>/uninstall.sh
```

---

## Troubleshooting

| Symptom | Fix |
|---|---|
| `jq: command not found` | `brew install jq` (mac) / `apt install jq` (linux) |
| Slash command not found | Restart your agent; some harnesses cache the command list |
| `Permission denied` on install.sh | `chmod +x packages/*/install.sh` |
| Version drift between packages | `bash scripts/foundry-version-sync.sh` (from a checkout) |
| Patch detection always fires | `/foundry:patch-skip 30` to snooze 30 days |