---
description: "/sdlc-qa — DEPRECATED alias of /foundry-qa (will be removed in foundry v1.1.0). Triggered /foundry directly going forward."
argument-hint: ""
hide-from-slash-command-tool: "false"
---

# /sdlc-qa → /foundry-qa (deprecated)

This command is a **backward-compatibility alias** for /foundry-qa.

**This alias is deprecated in foundry v1.0.0** and will be removed in foundry v1.1.0. Use /foundry-qa directly going forward.

## Migration

Replace instances of:
  /sdlc-qa <args>  →  /foundry-qa <args>

In shell pipelines:
  alias ='foundry-qa'    # already suggests /foundry; consider /foundry-qa instead

See `foundry/templates/migration-from-ai-eng-sdlc.md` for the full migration guide.

## What this alias does

Read the original command's documentation at `commands/foundry-qa.md`.

When invoked, this stub simply delegates to /foundry-qa via the Skill tool with the same arguments.
