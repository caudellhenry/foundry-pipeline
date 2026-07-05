---
description: "/sdlc-tdd — DEPRECATED alias of /foundry-tdd (will be removed in foundry v1.1.0). Triggered /foundry directly going forward."
argument-hint: ""
hide-from-slash-command-tool: "false"
---

# /sdlc-tdd → /foundry-tdd (deprecated)

This command is a **backward-compatibility alias** for /foundry-tdd.

**This alias is deprecated in foundry v1.0.0** and will be removed in foundry v1.1.0. Use /foundry-tdd directly going forward.

## Migration

Replace instances of:
  /sdlc-tdd <args>  →  /foundry-tdd <args>

In shell pipelines:
  alias ='foundry-tdd'    # already suggests /foundry; consider /foundry-tdd instead

See `foundry/templates/migration-from-ai-eng-sdlc.md` for the full migration guide.

## What this alias does

Read the original command's documentation at `commands/foundry-tdd.md`.

When invoked, this stub simply delegates to /foundry-tdd via the Skill tool with the same arguments.
