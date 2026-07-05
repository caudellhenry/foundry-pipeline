---
name: handoff
description: Compact the current session's state into a handoff document so a fresh session (or another person) can resume losslessly. Use before ending a long session, switching machines, or handing work over.
disable-model-invocation: true
---
foundry_version: 2.0.1

# /handoff — lossless resumption

Nothing load-bearing may live only in a conversation. This skill moves it to disk.

Write `handoff.md`:

```markdown
# Handoff: <work title>
date: YYYY-MM-DD
phase: <pipeline phase> · ticket: <id or ->

## Where things stand
Two or three sentences, plain language.

## Decisions made this session (and why)
- ...

## Unresolved / in flight
- <issue> — <state, next step>

## Gotchas discovered
- <non-obvious thing the next session must know>

## Next actions (in order)
1. ...
```

Rules: decisions with their *why*, not a transcript · every claim checkable against the repo · under a page · update `.foundry/state.json` to match · verify a fresh reader needs nothing from this conversation.
