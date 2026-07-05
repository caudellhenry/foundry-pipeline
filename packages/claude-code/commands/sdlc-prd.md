---
description: "/sdlc-prd — DEPRECATED alias of /foundry-prd (will be removed in foundry v1.1.0). Triggered /foundry directly going forward."
argument-hint: ""
hide-from-slash-command-tool: "false"
---

# /sdlc-prd → /foundry-prd (deprecated)

This command is a **backward-compatibility alias** for /foundry-prd.

**This alias is deprecated in foundry v1.0.0** and will be removed in foundry v1.1.0. Use /foundry-prd directly going forward.

## Migration

Replace instances of:
  /sdlc-prd <args>  →  /foundry-prd <args>

In shell pipelines:
  alias ='foundry-prd'    # already suggests /foundry; consider /foundry-prd instead

See `foundry/templates/migration-from-ai-eng-sdlc.md` for the full migration guide.

## What this alias does

Read the original command's documentation at `commands/foundry-prd.md`.

When invoked, this stub simply delegates to /foundry-prd via the Skill tool with the same arguments.
