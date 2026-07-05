---
description: "/sdlc-prototype — DEPRECATED alias of /foundry-prototype (will be removed in foundry v1.1.0). Triggered /foundry directly going forward."
argument-hint: ""
hide-from-slash-command-tool: "false"
---

# /sdlc-prototype → /foundry-prototype (deprecated)

This command is a **backward-compatibility alias** for /foundry-prototype.

**This alias is deprecated in foundry v1.0.0** and will be removed in foundry v1.1.0. Use /foundry-prototype directly going forward.

## Migration

Replace instances of:
  /sdlc-prototype <args>  →  /foundry-prototype <args>

In shell pipelines:
  alias ='foundry-prototype'    # already suggests /foundry; consider /foundry-prototype instead

See `foundry/templates/migration-from-ai-eng-sdlc.md` for the full migration guide.

## What this alias does

Read the original command's documentation at `commands/foundry-prototype.md`.

When invoked, this stub simply delegates to /foundry-prototype via the Skill tool with the same arguments.
