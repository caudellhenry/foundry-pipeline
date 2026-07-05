---
name: foundry-context-rotate
description: Cross-cutting discipline skill. Watches for the four named context-failure modes (Context Poisoning, Context Distraction, Context Confusion, Context Clash — per Drew Breunig) and triggers context rotation before the model degrades. Fires on PostToolUse or Stop; suggests /clear or /compact when near 80% of the limit, when a poisoned chunk is detected, or when the focus has drifted from the current ticket. Modeled on Boris Cherny's "auto-compact near 155k tokens" habit.
---
foundry_version: 2.0.1

# Cross-cutting — Context Rotation

> *"As the number of tokens in the context window increases, the model's ability to accurately recall information from that context decreases."* — Anthropic / Drew Breunig

Context rot is the underlying engine of all four named failure modes:

| Failure mode | Definition | Symptom | Rotation trigger |
|--------------|------------|---------|------------------|
| **Context Poisoning** | A hallucination or other error makes it into the context, where it is repeatedly referenced | Wrong facts repeated, citations that don't exist | When a hallucinated chunk is detected by a sub-agent |
| **Context Distraction** | The context grows so long that the model over-focuses on the context; neglects training | Code that "looks right" but is unidiomatic; over-reliance on README text | When context > 80% of window |
| **Context Confusion** | Superfluous content is used by the model to generate a low-quality response | Tangential answers, drift from current ticket | When focus drift is detected (current ticket no longer mentioned in recent tool calls) |
| **Context Clash** | New information and tools conflict with other information in the context | Agent contradicts itself across iterations | When two recent tool outputs disagree on the same fact |

## When to rotate

The skill fires on every PostToolUse and Stop event via the `post-tool-use.sh` hook. It checks:

1. **Size threshold** — has the conversation exceeded 80% of the model's context window?
2. **Poisoning heuristic** — has any recent tool output been flagged by the user as a hallucination?
3. **Distraction heuristic** — has the conversation gone > 10 turns without mentioning the current ticket id?
4. **Clash heuristic** — do two recent tool outputs disagree on a key fact?

If any check fires, the skill suggests (via the PostToolUse JSON output):

```json
{
  "hookSpecificOutput": {
    "hookEventName": "PostToolUse",
    "additionalContext": "Context rotation recommended: <reason>. Run /clear or /compact, then resume with the current ticket focus prompt."
  }
}
```

The hook output is non-blocking — it surfaces the recommendation, the user / agent decides whether to act.

## When to compact (vs clear)

| Action | Effect | Use when |
|--------|--------|----------|
| `/compact` | Summarises near-limit content into a smaller window | Continuing the same work in the same session |
| `/clear` | Resets the context window entirely | Switching tickets / phases |
| `/rewind` | Rolls back conversation + code to a checkpoint | A specific decision was wrong; restore earlier state |

## State to write

When rotation fires, append to `.foundry/logs/context-rotations.log`:

```yaml
---
timestamp: <ISO>
trigger: size | poisoning | distraction | clash | manual
context_size: <approx tokens>
ticket_at_time: <STORY-ID>
action_taken: /clear | /compact | /rewind | none
reason: <one line>
```

## Verifier

The skill is "doing its job" when the rotation log has at least one entry per 50 turns of execution, and no ticket completes with a hallucinated fact in its evidence.

## Cross-references

- **Breunig** — *How Long Contexts Fail (and how to fix them)* (22 Jun 2025)
- **Anthropic** — *Effective context engineering for AI agents*
- **Boris Cherny** — *"We always auto-compacted near 155k tokens so there's enough buffer."*

## Pipeline integration

The PostToolUse hook chain calls `scripts/foundry-context-check.sh` after every tool invocation. That script decides whether to recommend rotation; the recommendation surfaces in the agent's next turn.

The Stop hook (`hooks/stop-hook.sh`) also calls it before exiting, so the agent knows whether to resume with a clean context.

## Named expert inputs

- **Breunig** — four failure modes + "context rot" engine
- **Anthropic Applied AI** — *right altitude* framing for context
- **Harrison Chase / LangChain** — five levers (tool use, short-term memory, long-term memory, prompt engineering, retrieval)
- **Boris Cherny** — auto-compact threshold (155k tokens)
