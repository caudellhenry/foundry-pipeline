---
description: "/sdlc-loop-on — DEPRECATED alias of /foundry-loop-on (will be removed in foundry v1.1.0). Triggered /foundry directly going forward."
argument-hint: ""
hide-from-slash-command-tool: "false"
---

# /sdlc-loop-on → /foundry-loop-on (deprecated)

This command is a **backward-compatibility alias** for /foundry-loop-on.

**This alias is deprecated in foundry v1.0.0** and will be removed in foundry v1.1.0. Use /foundry-loop-on directly going forward.

## Migration

Replace instances of:
  /sdlc-loop-on <args>  →  /foundry-loop-on <args>

In shell pipelines:
  alias ='foundry-loop-on'    # already suggests /foundry; consider /foundry-loop-on instead

See `foundry/templates/migration-from-ai-eng-sdlc.md` for the full migration guide.

## What this alias does

Read the original command's documentation at `commands/foundry-loop-on.md`.

When invoked, this stub simply delegates to /foundry-loop-on via the Skill tool with the same arguments.
