---
description: Detect local divergence from the canonical foundry-pipeline tag at v2.0.0
argument-hint: ""
hide-from-slash-command-tool: "false"
foundry_version: 2.0.0
---

# `/foundry:patch-check`

Detect if the local install of foundry-pipeline differs from the canonical tag at `v2.0.0`.

## Behaviour

Runs `packages/core/scripts/foundry-self-update.sh` which supports two detection modes:

### Mode A — git-aware (when install dir is a git checkout)

```bash
LOCAL_HEAD=$(git -C "$INSTALL_DIR" rev-parse HEAD)
UPSTREAM_SHA=$(git ls-remote --tags origin v2.0.0 | awk '{print $1}')
[[ "$LOCAL_HEAD" != "$UPSTREAM_SHA" ]] && emit_prompt
```

### Mode B — file-checksum (when install dir is not a git checkout)

```bash
LOCAL_SHA=$(sha256sum "$INSTALL_DIR"/skills/*/SKILL.md | sha256sum)
CANONICAL_SHA=$(curl -sL "https://raw.githubusercontent.com/caudellhenry/foundry-pipeline/v2.0.0/packages/claude-code/.foundry-version-manifest.json" | jq -r '.files."skills/ship/SKILL.md"')
[[ "$LOCAL_SHA" != "$CANONICAL_SHA" ]] && emit_prompt
```

## When it diverges, emits:

```
⚠️  foundry v2.0.0 installed locally differs from canonical v2.0.0.

    3 files modified (skills/ship/SKILL.md, scripts/foundry-loop.sh, ...).
    1 unpushed commit ahead.

    Commands:
      /foundry:patch-diff    Show the diff vs canonical
      /foundry:patch-push    Push local changes to caudellhenry/foundry-pipeline
      /foundry:patch-reset   Discard local changes, reinstall canonical v2.0.0
      /foundry:patch-skip    Ignore this divergence (default 30 days)
```

## Exit codes

- 0 — no divergence
- 1 — divergence detected