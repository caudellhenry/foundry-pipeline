---
description: "/sdlc-idea — DEPRECATED alias of /foundry-idea (will be removed in foundry v1.1.0). Triggered /foundry directly going forward."
argument-hint: ""
hide-from-slash-command-tool: "false"
---

# /sdlc-idea → /foundry-idea (deprecated)

This command is a **backward-compatibility alias** for /foundry-idea.

**This alias is deprecated in foundry v1.0.0** and will be removed in foundry v1.1.0. Use /foundry-idea directly going forward.

## Migration

Replace instances of:
  /sdlc-idea <args>  →  /foundry-idea <args>

In shell pipelines:
  alias ='foundry-idea'    # already suggests /foundry; consider /foundry-idea instead

See `foundry/templates/migration-from-ai-eng-sdlc.md` for the full migration guide.

## What this alias does

Read the original command's documentation at `commands/foundry-idea.md`.

When invoked, this stub simply delegates to /foundry-idea via the Skill tool with the same arguments.
