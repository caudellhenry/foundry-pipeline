---
description: "/sdlc-self-improve — DEPRECATED alias of /foundry-self-improve (will be removed in foundry v1.1.0). Triggered /foundry directly going forward."
argument-hint: ""
hide-from-slash-command-tool: "false"
---

# /sdlc-self-improve → /foundry-self-improve (deprecated)

This command is a **backward-compatibility alias** for /foundry-self-improve.

**This alias is deprecated in foundry v1.0.0** and will be removed in foundry v1.1.0. Use /foundry-self-improve directly going forward.

## Migration

Replace instances of:
  /sdlc-self-improve <args>  →  /foundry-self-improve <args>

In shell pipelines:
  alias ='foundry-self-improve'    # already suggests /foundry; consider /foundry-self-improve instead

See `foundry/templates/migration-from-ai-eng-sdlc.md` for the full migration guide.

## What this alias does

Read the original command's documentation at `commands/foundry-self-improve.md`.

When invoked, this stub simply delegates to /foundry-self-improve via the Skill tool with the same arguments.
