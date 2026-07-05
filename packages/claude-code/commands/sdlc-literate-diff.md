---
description: "/sdlc-literate-diff — DEPRECATED alias of /foundry-literate-diff (will be removed in foundry v1.1.0). Triggered /foundry directly going forward."
argument-hint: ""
hide-from-slash-command-tool: "false"
---

# /sdlc-literate-diff → /foundry-literate-diff (deprecated)

This command is a **backward-compatibility alias** for /foundry-literate-diff.

**This alias is deprecated in foundry v1.0.0** and will be removed in foundry v1.1.0. Use /foundry-literate-diff directly going forward.

## Migration

Replace instances of:
  /sdlc-literate-diff <args>  →  /foundry-literate-diff <args>

In shell pipelines:
  alias ='foundry-literate-diff'    # already suggests /foundry; consider /foundry-literate-diff instead

See `foundry/templates/migration-from-ai-eng-sdlc.md` for the full migration guide.

## What this alias does

Read the original command's documentation at `commands/foundry-literate-diff.md`.

When invoked, this stub simply delegates to /foundry-literate-diff via the Skill tool with the same arguments.
