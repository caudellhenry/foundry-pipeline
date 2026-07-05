---
description: "/sdlc-test-config — DEPRECATED alias of /foundry-test-config (will be removed in foundry v1.1.0). Triggered /foundry directly going forward."
argument-hint: ""
hide-from-slash-command-tool: "false"
---

# /sdlc-test-config → /foundry-test-config (deprecated)

This command is a **backward-compatibility alias** for /foundry-test-config.

**This alias is deprecated in foundry v1.0.0** and will be removed in foundry v1.1.0. Use /foundry-test-config directly going forward.

## Migration

Replace instances of:
  /sdlc-test-config <args>  →  /foundry-test-config <args>

In shell pipelines:
  alias ='foundry-test-config'    # already suggests /foundry; consider /foundry-test-config instead

See `foundry/templates/migration-from-ai-eng-sdlc.md` for the full migration guide.

## What this alias does

Read the original command's documentation at `commands/foundry-test-config.md`.

When invoked, this stub simply delegates to /foundry-test-config via the Skill tool with the same arguments.
