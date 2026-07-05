---
description: "/sdlc-eval — DEPRECATED alias of /foundry-eval (will be removed in foundry v1.1.0). Triggered /foundry directly going forward."
argument-hint: ""
hide-from-slash-command-tool: "false"
---

# /sdlc-eval → /foundry-eval (deprecated)

This command is a **backward-compatibility alias** for /foundry-eval.

**This alias is deprecated in foundry v1.0.0** and will be removed in foundry v1.1.0. Use /foundry-eval directly going forward.

## Migration

Replace instances of:
  /sdlc-eval <args>  →  /foundry-eval <args>

In shell pipelines:
  alias ='foundry-eval'    # already suggests /foundry; consider /foundry-eval instead

See `foundry/templates/migration-from-ai-eng-sdlc.md` for the full migration guide.

## What this alias does

Read the original command's documentation at `commands/foundry-eval.md`.

When invoked, this stub simply delegates to /foundry-eval via the Skill tool with the same arguments.
