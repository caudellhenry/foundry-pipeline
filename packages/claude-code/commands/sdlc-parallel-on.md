---
description: "/sdlc-parallel-on — DEPRECATED alias of /foundry-parallel-on (will be removed in foundry v1.1.0). Triggered /foundry directly going forward."
argument-hint: ""
hide-from-slash-command-tool: "false"
---

# /sdlc-parallel-on → /foundry-parallel-on (deprecated)

This command is a **backward-compatibility alias** for /foundry-parallel-on.

**This alias is deprecated in foundry v1.0.0** and will be removed in foundry v1.1.0. Use /foundry-parallel-on directly going forward.

## Migration

Replace instances of:
  /sdlc-parallel-on <args>  →  /foundry-parallel-on <args>

In shell pipelines:
  alias ='foundry-parallel-on'    # already suggests /foundry; consider /foundry-parallel-on instead

See `foundry/templates/migration-from-ai-eng-sdlc.md` for the full migration guide.

## What this alias does

Read the original command's documentation at `commands/foundry-parallel-on.md`.

When invoked, this stub simply delegates to /foundry-parallel-on via the Skill tool with the same arguments.
