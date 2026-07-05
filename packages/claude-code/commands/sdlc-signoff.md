---
description: "/sdlc-signoff — DEPRECATED alias of /foundry-signoff (will be removed in foundry v1.1.0). Triggered /foundry directly going forward."
argument-hint: ""
hide-from-slash-command-tool: "false"
---

# /sdlc-signoff → /foundry-signoff (deprecated)

This command is a **backward-compatibility alias** for /foundry-signoff.

**This alias is deprecated in foundry v1.0.0** and will be removed in foundry v1.1.0. Use /foundry-signoff directly going forward.

## Migration

Replace instances of:
  /sdlc-signoff <args>  →  /foundry-signoff <args>

In shell pipelines:
  alias ='foundry-signoff'    # already suggests /foundry; consider /foundry-signoff instead

See `foundry/templates/migration-from-ai-eng-sdlc.md` for the full migration guide.

## What this alias does

Read the original command's documentation at `commands/foundry-signoff.md`.

When invoked, this stub simply delegates to /foundry-signoff via the Skill tool with the same arguments.
