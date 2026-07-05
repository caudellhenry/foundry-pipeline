---
description: "/sdlc-loop-off — DEPRECATED alias of /foundry-loop-off (will be removed in foundry v1.1.0). Triggered /foundry directly going forward."
argument-hint: ""
hide-from-slash-command-tool: "false"
---

# /sdlc-loop-off → /foundry-loop-off (deprecated)

This command is a **backward-compatibility alias** for /foundry-loop-off.

**This alias is deprecated in foundry v1.0.0** and will be removed in foundry v1.1.0. Use /foundry-loop-off directly going forward.

## Migration

Replace instances of:
  /sdlc-loop-off <args>  →  /foundry-loop-off <args>

In shell pipelines:
  alias ='foundry-loop-off'    # already suggests /foundry; consider /foundry-loop-off instead

See `foundry/templates/migration-from-ai-eng-sdlc.md` for the full migration guide.

## What this alias does

Read the original command's documentation at `commands/foundry-loop-off.md`.

When invoked, this stub simply delegates to /foundry-loop-off via the Skill tool with the same arguments.
