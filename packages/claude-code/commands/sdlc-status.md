---
description: "/sdlc-status — DEPRECATED alias of /foundry-status (will be removed in foundry v1.1.0). Triggered /foundry directly going forward."
argument-hint: ""
hide-from-slash-command-tool: "false"
---

# /sdlc-status → /foundry-status (deprecated)

This command is a **backward-compatibility alias** for /foundry-status.

**This alias is deprecated in foundry v1.0.0** and will be removed in foundry v1.1.0. Use /foundry-status directly going forward.

## Migration

Replace instances of:
  /sdlc-status <args>  →  /foundry-status <args>

In shell pipelines:
  alias ='foundry-status'    # already suggests /foundry; consider /foundry-status instead

See `foundry/templates/migration-from-ai-eng-sdlc.md` for the full migration guide.

## What this alias does

Read the original command's documentation at `commands/foundry-status.md`.

When invoked, this stub simply delegates to /foundry-status via the Skill tool with the same arguments.
