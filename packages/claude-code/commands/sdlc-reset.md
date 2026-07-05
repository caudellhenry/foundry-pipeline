---
description: "/sdlc-reset — DEPRECATED alias of /foundry-reset (will be removed in foundry v1.1.0). Triggered /foundry directly going forward."
argument-hint: ""
hide-from-slash-command-tool: "false"
---

# /sdlc-reset → /foundry-reset (deprecated)

This command is a **backward-compatibility alias** for /foundry-reset.

**This alias is deprecated in foundry v1.0.0** and will be removed in foundry v1.1.0. Use /foundry-reset directly going forward.

## Migration

Replace instances of:
  /sdlc-reset <args>  →  /foundry-reset <args>

In shell pipelines:
  alias ='foundry-reset'    # already suggests /foundry; consider /foundry-reset instead

See `foundry/templates/migration-from-ai-eng-sdlc.md` for the full migration guide.

## What this alias does

Read the original command's documentation at `commands/foundry-reset.md`.

When invoked, this stub simply delegates to /foundry-reset via the Skill tool with the same arguments.
