---
description: "/sdlc-execute — DEPRECATED alias of /foundry-execute (will be removed in foundry v1.1.0). Triggered /foundry directly going forward."
argument-hint: ""
hide-from-slash-command-tool: "false"
---

# /sdlc-execute → /foundry-execute (deprecated)

This command is a **backward-compatibility alias** for /foundry-execute.

**This alias is deprecated in foundry v1.0.0** and will be removed in foundry v1.1.0. Use /foundry-execute directly going forward.

## Migration

Replace instances of:
  /sdlc-execute <args>  →  /foundry-execute <args>

In shell pipelines:
  alias ='foundry-execute'    # already suggests /foundry; consider /foundry-execute instead

See `foundry/templates/migration-from-ai-eng-sdlc.md` for the full migration guide.

## What this alias does

Read the original command's documentation at `commands/foundry-execute.md`.

When invoked, this stub simply delegates to /foundry-execute via the Skill tool with the same arguments.
