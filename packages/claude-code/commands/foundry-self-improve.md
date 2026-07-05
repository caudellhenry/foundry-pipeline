---
description: "/foundry-self-improve — Run the skill-improver meta-skill on this session. Walks captures → classifies against the pattern taxonomy → proposes improvements → commits approved changes to the Knowledge Base and existing skills."
argument-hint: "[--since YYYY-MM-DD] [--commit]"
allowed-tools: ["Bash(${CLAUDE_PLUGIN_ROOT:-/Users/henrycaudell/Agents Workspace/Skills/foundry-pipeline-plugin}/scripts/foundry-self-improve.sh:*)", "Bash($HOME/.zcode/skills/skill-improver/scripts/*:*)"]
---

# /foundry-self-improve — Skill-improver wrapper

Invokes the **`skill-improver`** meta-skill on the current foundry
session. Runs the five-stage ceremony:

1. **Capture** — read recent skill / script / learnings changes in the workspace
2. **Classify** — match against the pattern taxonomy
3. **Propose** — emit `~/.skill-improver/YYYY-MM-DD-improvements.md`
4. **Review** — STOP HERE. The user reviews the draft.
5. **Commit** — (only with `--commit`) append approved entries to the Knowledge Base

## Usage

```bash
/foundry-self-improve                    # default: 7-day lookback, draft only
/foundry-self-improve --since 2026-07-01 # custom lookback
/foundry-self-improve --commit           # also commit approved changes
```

## Behaviour

- **Default**: runs Stages 1–3, writes draft, surfaces path for review. **Does NOT commit**.
- **`--commit`**: also runs Stage 5 — appends approved entries from the draft to `Knowledge Base/analysis/.learnings/{LEARNINGS,ERRORS,FEATURE_REQUESTS}.md`.
- **Always non-destructive**: the draft is written first; the user reads before approving.

## Cross-cutting discipline

This is one of three cross-cutting disciplines in the foundry, sitting
parallel to `foundry-context-rotate` and `foundry-agent-eval`:

- **`foundry-context-rotate`** — manages the model's context window.
- **`foundry-agent-eval`** — runs the agent against fixed scenarios.
- **`foundry-self-improve`** — consolidates learnings into durable artefacts.

Invoke any of them after a Phase completes; or invoke `/foundry-self-improve`
at the end of a session.

## See also

- `Skills/skill-improver/SKILL.md` — full ceremony
- `Skills/foundry-pipeline-plugin/skills/foundry-context-rotate/SKILL.md`
- `Knowledge Base/analysis/.learnings/LEARNINGS.md` — destination for proposed learnings