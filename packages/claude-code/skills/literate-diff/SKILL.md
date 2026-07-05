---
name: foundry-literate-diff
description: Cross-cutting discipline skill. After every ticket lands (Phase 6 commit), produces a literate diff — a structured prose explanation of what changed, why, and what the reader needs to know to maintain it. Operationalises Geoffrey Litt's /explore-diff and the cognitive-debt discipline (Willison / Osmani). The literate diff is committed alongside the code and used by the QA reviewer (Phase 7 writer/reviewer). Triggered on PostToolUse after Write/Edit on a tracked file.
---
foundry_version: 2.0.3

# Cross-cutting — Literate Diff

> *"I won't send code to others until I can pass the quiz."* — Geoffrey Litt
>
> *"Need to write a strong `explore-diff` skill along these lines."* — Geoffrey Litt

A **literate diff** is a structured prose explanation of what changed, why, and what the reader needs to know to maintain it. It is the operationalisation of Litt's `/explore-diff` and the cognitive-debt / comprehension-debt discipline (Willison / Osmani).

## When to run

- After every Write / Edit on a tracked file (via PostToolUse hook).
- Manually via `/foundry-literate-diff [commit-hash]` to retro-document a past commit.
- The QA reviewer (Phase 7) reads the literate diff alongside the actual diff.

## Ceremony

For a commit (or in-progress change), produce a literate diff with these sections:

1. **What changed** — one-sentence summary.
2. **Why** — the *intent* behind the change, not the implementation.
3. **How it works** — a 3–10 line walk-through that the reader can use as a mental model.
4. **Trade-offs** — what we considered and rejected.
5. **What could go wrong** — known risks, footguns, sharp edges.
6. **Quiz** — 3–5 questions the maintainer should be able to answer *before* merging (Litt's "quiz as speed regulator").

## Output artefact

### `.foundry/literate/<commit-hash>.md`

```yaml
---
phase: execute
created: <ISO>
commit: <hash>
ticket: <STORY-ID>
reviewer_quiz_score: <N>/M (filled by reviewer)
---
# Literate Diff — <commit short-hash>

## What changed
<one sentence>

## Why
<intent — not implementation>

## How it works
<3–10 line walk-through>

## Trade-offs
- Considered <X>, chose <Y> because <reason>.
- Considered <A>, rejected <B> because <reason>.

## What could go wrong
- <risk> — mitigate by <how>.
- <risk> — mitigate by <how>.

## Quiz (for the maintainer)
- [ ] Q1: <question>
- [ ] Q2: <question>
- [ ] Q3: <question>

## Reviewer sign-off
**Reviewer**: <name or "fresh-context-subagent">
**Quiz score**: <N>/<M>
**Status**: APPROVED | NEEDS-REVISION
**Notes**: <one paragraph>
```

## Hook integration

The PostToolUse hook (`hooks/post-tool-use.sh`) listens for `Write` and `Edit` tool events. After each Write / Edit on a tracked file, it:

1. Stashes the diff fragment.
2. After 60 seconds of inactivity (or on Stop), assembles the full diff for the ticket.
3. Asks the agent to produce a literate diff.
4. Writes `.foundry/literate/<commit-hash>.md`.

If the user disabled literate diffs (`auto_loop: false` AND `--no-literate`), the hook no-ops.

## Verifier

The skill is "doing its job" when:
- Every commit has a literate diff (or the user explicitly opted out for that commit).
- The reviewer can pass the quiz before approving the change.
- Cognitive debt is trending down (measured by reviewer quiz scores over time).

## Cross-references

- **Geoffrey Litt** — *Understanding is the new bottleneck* (2 Jul 2026); *literate diff*; *quiz as speed regulator*
- **Willison** — `cognitive-debt` tag at <https://simonwillison.net/tags/cognitive-debt/>
- **Osmani** — *Comprehension Debt — the hidden cost of AI generated code* (14 Mar 2026)

## Pipeline integration

- Phase 6 (Execute) — produced automatically after each commit.
- Phase 7 (QA) — the writer/reviewer reads the literate diff before reading the actual code.
- Phase 5 (Plan) — the ticket's *tdd_plan* includes a placeholder for the literate diff that will be produced.

## Named expert inputs

- **Litt** — *"I won't send code to others until I can pass the quiz."*
- **Litt** — *literate diff* as a deliberate cognitive-debt mitigation
- **Willison** — *cognitive debt* tag; correlates with this skill
- **Osmani** — *comprehension debt*; same failure mode
