---
name: foundry-agent-eval
description: Cross-cutting discipline skill. Defines the eval harness for the foundry — runs the agent's behaviour against fixed scenarios (analogous to SWE-bench Verified) so prompt drift is caught in CI, not in production. Treats prompts as first-class versioned, evaled artefacts (Goedecke: "prompts are technical debt too"). Fixtures live in .foundry/eval/{scenarios,results}/. Run on Stop (when a ticket lands), and via the /foundry-eval slash command.
---
foundry_version: 2.0.2

# Cross-cutting — Agent Eval

> *"Each solution is graded against the real unit tests from the pull request that closed the original GitHub issue."* — Anthropic SWE-bench Verified
>
> *"Prompts will decay silently. A set of prompts that you carefully crafted in January this year might be out of date or actively harmful by February."* — Sean Goedecke

This skill is the **eval harness** for the foundry. It runs the agent's behaviour against fixed scenarios and produces a grade, so prompt drift is caught in CI, not in production.

## When to run

- Manually via `/foundry-eval [scenario]`.
- Automatically on every Stop event when a ticket lands (configurable; off by default to keep the loop fast).
- Automatically on every merge to main (CI integration; future).

## Eval scenarios

Each scenario is a small, fixed challenge that the agent must solve. The grader checks both the *output* (file contents, commit, tests) and the *process* (the conversation log, the prompt used, the verifier verdict).

Scenarios live in `.foundry/eval/scenarios/<name>.yaml`:

```yaml
---
name: add-a-button
description: Agent must add a "Save" button to a hypothetical settings page.
expected_artifacts:
  - .foundry/tdd/<ticket>.md
  - .foundry/qa/evidence/<ticket>.md
expected_test_count: 3
expected_files_touched:
  - src/components/Settings.tsx
  - tests/Settings.test.tsx
forbidden_patterns:
  - "TODO"
  - "fixme"
max_tokens: 50000
```

## Grading rubric

Each scenario is graded on five axes (Anthropic's *multi-agent research* disciplines, applied to coding):

| Axis | Weight | What it measures |
|------|--------|------------------|
| **Functional correctness** | 40% | Tests pass; expected artefacts produced; acceptance criteria met |
| **Process discipline** | 20% | Followed TDD red→green→refactor; recorded evidence; updated board |
| **Prompt hygiene** | 15% | Re-used canonical prompts (no copy-paste rot); followed named-expert disciplines |
| **Communication clarity** | 15% | Literate diff produced; QA plan readable; cognitive-debt low |
| **Resource efficiency** | 10% | Token count within budget; no unnecessary sub-agents |

Total: 0–100. Pass threshold: ≥ 70. Sticky failures (same scenario fails 3 runs in a row) trigger a prompt-debt alarm in `.foundry/eval/results/debt.md`.

## Output artefacts

### `.foundry/eval/results/<timestamp>-<scenario>.json`

```json
{
  "scenario": "add-a-button",
  "ran_at": "<ISO>",
  "model": "<model id>",
  "prompt_version": "<git hash>",
  "scores": {
    "functional_correctness": 38,
    "process_discipline": 18,
    "prompt_hygiene": 14,
    "communication_clarity": 13,
    "resource_efficiency": 9
  },
  "total": 92,
  "verdict": "pass",
  "notes": "<short rationale>"
}
```

### `.foundry/eval/results/debt.md` (rolling summary)

```yaml
---
last_updated: <ISO>
sticky_failures:
  - scenario: <name>
    consecutive_failures: 3
    likely_cause: "Prompt <X> has drifted; re-test after pinning."
---
# Prompt Debt

| Scenario | Last score | Trend | Action |
|----------|------------|-------|--------|
| add-a-button | 92 | stable | none |
| fix-a-bug | 65 | ↓↓ | re-pin prompt <X> |
```

## Verifier

The eval is "doing its job" when:
- At least 3 scenarios exist in `eval/scenarios/`.
- Every shipped ticket has at least one eval result (run on demand).
- `eval/results/debt.md` has zero sticky failures (or they're addressed).
- The CI integration runs on every merge (future improvement).

## Cross-references

- **SWE-bench Verified** — Anthropic's *real unit tests from the PR* discipline
- **Longpre** — *third-party AI evaluation*; treat the agent as the model and the eval as the independent judge
- **Anthropic multi-agent research** — five eval disciplines (start small, LLM-as-judge, human eval, separate checker, eval against real execution)
- **Goedecke** — *"Prompts are a worse form of technical debt than code."* This skill is the eval discipline that defends against silent drift.
- **Langfuse / LangSmith / Helicone** — production eval platforms (named for future integration)

## Pipeline integration

The eval skill is *cross-cutting*: it does not own a phase. It runs on demand or as a CI step. The PostToolUse hook optionally triggers it after every commit (off by default).

## Named expert inputs

- **Anthropic** — SWE-bench Verified, multi-agent research eval disciplines
- **Longpre** — *Third-Party AI Evaluation* paper
- **Goedecke** — *"Prompts are technical debt too."*
- **Harrison Chase / LangChain** — eval as a discipline (Dex Horthy's *12 Factor Agents*)
