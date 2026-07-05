---
description: "/sdlc-plan — DEPRECATED alias of /foundry-plan (will be removed in foundry v1.1.0). Triggered /foundry directly going forward."
argument-hint: ""
hide-from-slash-command-tool: "false"
---

# /sdlc-plan → /foundry-plan (deprecated)

This command is a **backward-compatibility alias** for /foundry-plan.

**This alias is deprecated in foundry v1.0.0** and will be removed in foundry v1.1.0. Use /foundry-plan directly going forward.

## Migration

Replace instances of:
  /sdlc-plan <args>  →  /foundry-plan <args>

In shell pipelines:
  alias ='foundry-plan'    # already suggests /foundry; consider /foundry-plan instead

See `foundry/templates/migration-from-ai-eng-sdlc.md` for the full migration guide.

## What this alias does

Read the original command's documentation at `commands/foundry-plan.md`.

When invoked, this stub simply delegates to /foundry-plan via the Skill tool with the same arguments.
