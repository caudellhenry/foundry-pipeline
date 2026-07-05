---
name: foundry-research
description: Phase 2 of the foundry — the Research phase (conditional). Caches hard-to-explore external knowledge (third-party APIs, niche libraries, framework internals) into .foundry/research/research.md with an explicit expiry date. Uses WebFetch / WebSearch to gather information; caches only what the agent cannot retrieve reliably from parametric knowledge. Skip rule: if the topic is in the agent's training data and stable, skip this phase. Use when /foundry-research is invoked or when the pipeline auto-advances from Phase 1.
---
foundry_version: 2.0.3

# Phase 2 — Research (conditional)

> *"Research rots — outdated research can just send an agent off course where it's not needed."* — Matt Pocock

This phase produces a **per-sprint `research.md`** in the project, scoped to the current idea's lifetime. Anything cached here must have an explicit expiry date so future agents know when to re-fetch.

## When to run

- `/foundry-research` is invoked.
- Pipeline auto-advances from Phase 1 and user has not skipped Phase 2.
- The user flags external knowledge (an unfamiliar API, a niche library, a recent breaking change).

## Skip rule

If the topic is in the agent's training data **and** stable, **skip** this phase. The plugin surfaces a `Phase 2 (Research) — skip? [Y/n]` prompt.

Skip if any of:
- No third-party / niche API involved.
- No unfamiliar framework / library version involved.
- No recent breaking change involved.
- The user says "skip research, I know this domain."

## Ceremony

1. Read `.foundry/idea/intent.md` to understand what is being researched.
2. Identify the **research questions** — what's the agent uncertain about that, if wrong, would derail the PRD or the execution loop? Examples:
   - "What's the current Stripe subscription webhook contract (2026-07)?"
   - "Does library X support feature Y in version N?"
   - "What's the recommended migration path from API v1 to v2?"
3. For each question, use `WebFetch` / `WebSearch` to gather a citable answer. Prefer:
   - Official documentation (vendor docs, RFCs).
   - Recent (within the last 12 months) high-trust sources.
   - Changelogs for breaking-change lookups.
4. Capture findings into `.foundry/research/research.md` with **citations** (URLs) and **expiry dates**.

## Output artefact

### `.foundry/research/research.md`

```yaml
---
phase: research
status: complete
created: <ISO timestamp>
expires: <ISO timestamp, ≤ 30 days from created>
sprint: <idea slug>
sources:
  - <url>
  - <url>
---
# Research — <intent summary>

> Expires: <date>. After this date, re-fetch before relying on the cached facts.

## Q1: <question>
**Source**: [<title>](<url>), accessed <date>
**Answer**: <concise answer>
**Confidence**: high / medium / low
**Notes**: <gotchas, caveats, version specifics>

## Q2: <question>
...

## What we explicitly did not research
- <bullet> (because it is in agent's training data and stable)
- <bullet> (because the user already knew the answer)

## Open questions to revisit during execution
- <bullet>
```

## Verifier

Phase 2 is **complete** when:
- `research.md` exists, is non-empty, and has at least one source URL.
- `expires` date is set and within 30 days.
- Each question has a confidence level (high / med / low).
- "What we explicitly did not research" section is present (so the agent is honest about coverage).

Or when the phase is **skipped**: state file shows `phases.research.status = skipped` with reason.

## On completion

1. Update `.foundry/state.md`:
   - `phases.research.status = complete | skipped`
   - `phases.research.completed = <now>`
   - `phases.research.artifact = .foundry/research/research.md`
   - `phases.research.expires = <date>`
   - `current_phase = prototype`
2. Prompt: `✓ Phase 2 (Research) complete. Next: Phase 3 (Prototype) — conditional. Run /foundry-prototype or /foundry-skip-prototype.`

## Lifetime rule

Research is per-sprint only. When the idea is closed, delete `research.md`. The pipeline includes a `scripts/foundry-cleanup.sh` that archives research notes when a feature ships, retaining them for one sprint after `done`.

## Cross-references

- **Context engineering**: just-in-time retrieval (Anthropic), retrieval as a first-class lever (LangChain / Harrison Chase).
- **WebFetch** in ZCode / Claude Code automatically returns LLM-ready markdown.
- **MCP**: when MCP servers (Linear, GitHub, Notion, Figma, Postgres, Playwright) are connected, prefer them over WebFetch for first-party data.

## Named expert inputs

- **Pocock** — *"Per-sprint research. Research rots."* (transcript §"Phase 2 — Research")
- **Anthropic** — *just-in-time retrieval*, *lightweight identifiers* (file paths, stored queries, web links).
- **LangChain / Harrison Chase** — *retrieval* is one of the five context-engineering levers.
- **Boris Cherny** — *WebFetch auto-formats as markdown*.
