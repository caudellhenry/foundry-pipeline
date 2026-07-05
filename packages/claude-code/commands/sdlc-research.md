---
description: "/sdlc-research — DEPRECATED alias of /foundry-research (will be removed in foundry v1.1.0). Triggered /foundry directly going forward."
argument-hint: ""
hide-from-slash-command-tool: "false"
---

# /sdlc-research → /foundry-research (deprecated)

This command is a **backward-compatibility alias** for /foundry-research.

**This alias is deprecated in foundry v1.0.0** and will be removed in foundry v1.1.0. Use /foundry-research directly going forward.

## Migration

Replace instances of:
  /sdlc-research <args>  →  /foundry-research <args>

In shell pipelines:
  alias ='foundry-research'    # already suggests /foundry; consider /foundry-research instead

See `foundry/templates/migration-from-ai-eng-sdlc.md` for the full migration guide.

## What this alias does

Read the original command's documentation at `commands/foundry-research.md`.

When invoked, this stub simply delegates to /foundry-research via the Skill tool with the same arguments.
