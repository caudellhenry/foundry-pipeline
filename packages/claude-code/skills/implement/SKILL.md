---
name: foundry-execute
description: Phase 7 of the foundry — the Execution loop (Ralph loop). Drives the coding agent through the board, one ticket per iteration: read ticket + frozen TDD spec -> write failing tests per spec (red) -> implement (green) -> refactor -> update TDD doc -> record evidence -> commit -> mark done. Fresh context per ticket prevents context rot. Verifier sub-agent (or stop-hook) checks goal completion. Loops until the board is empty (or auto_loop max iterations). Use when /foundry-execute is invoked or when /foundry-loop-on is enabled.
---
foundry_version: 2.0.2

# Phase 6 — Execution Loop (Ralph loop)

> *"With the research, with the prototype, with the Kanban board, with the PRD helping it, you can totally run this execution loop AFK, and the results will be really good."* — Matt Pocock

This is the heart of the pipeline. The coding agent iterates through the board, one ticket per iteration. The loop is **driven by a stop-hook** that re-feeds the same focus prompt against fresh context + external state on disk.

## When to run

- `/foundry-execute` is invoked.
- Pipeline auto-advances from Phase 5.
- `/foundry-loop-on` is enabled and Phase 5 is complete.

## Loop mechanics

```
while board has unblocked "ready" or "in_progress" tickets:
   1. Pick the next ticket (highest priority; oldest; or user-specified).
   2. Open a fresh context (--clear / /compact / new sub-agent).
   3. Feed focus prompt: "Implement <TICKET> per its story, following TDD. Stop when tests pass and evidence is recorded."
   4. Sub-agent / session:
        a. Read .foundry/plan/stories/<TICKET>.md
        b. Write .foundry/tdd/<TICKET>.md with red/green notes
        c. Write failing tests (red)
        d. Implement to green
        e. Refactor
        f. Record evidence to .foundry/qa/evidence/<TICKET>.md
        g. Commit
        h. Update board: ticket -> review (or done, depending on policy)
   5. Verifier: run scripts/verify.sh execute <TICKET> — checks tests, evidence, commit.
   6. If verified: advance ticket to `done` (or `review` if policy requires human review).
   7. If not verified: keep iterating (max_iterations from env DEV_PIPELINE_MAX_ITER).
```

The loop is implemented in `scripts/foundry-loop.sh execute` and the stop-hook (`hooks/stop-hook.sh`) re-enters it on every turn when `auto_loop: true`.

## Ceremony for each ticket

1. **Read** the ticket story at `.foundry/plan/stories/<TICKET>.md`.
2. **Read** the frozen TDD spec at `.foundry/tdd/<TICKET>.md` — this is the **contract**; specs were frozen at Phase 5 and must not be edited here.
3. **Write tests per spec (red)** — turn each test case in the TDD spec into actual test code (failing tests). Save the test code to the appropriate place (e.g., `tests/`).
4. **Implement (green)** — write the minimum code to make the tests pass.
5. **Refactor** — clean up while keeping tests green.
6. **Record evidence** — `.foundry/qa/evidence/<TICKET>.md`:
   - Test output (paste or summarise).
   - Screenshots / recordings if UI.
   - Commit hash + message.
   - Any deviations from the story or spec (with rationale).
7. **Update TDD doc** — append the Red/Green/Refactor/Verification sections at the bottom of `.foundry/tdd/<TICKET>.md` (the spec at top stays frozen).
8. **Commit** — single commit per ticket, message `feat(<TICKET>): <story title>`.
9. **Update board** — move ticket to `review` (if human review required) or `done`.

## Output artefacts

### `.foundry/tdd/<TICKET>.md` (one per ticket)

```yaml
---
phase: execute
status: complete
created: <ISO timestamp>
ticket: <STORY-ID>
parent_feature: <FEATURE-ID>
commit: <hash>
---
# TDD — <TICKET>

## Red (failing tests)
- **<test name>** — <one-line>
  - File: <path>
  - Status: failing because <reason>

## Green (implementation)
- **<commit hash>** — feat(<TICKET>): <summary>
  - Files changed: <list>

## Refactor
- <bullet>
- <bullet>

## Verification
- All tests pass: yes
- Coverage: <pct>
```

### `.foundry/qa/evidence/<TICKET>.md` (one per ticket)

```yaml
---
phase: execute
status: complete
created: <ISO timestamp>
ticket: <STORY-ID>
commit: <hash>
reviewer_required: true | false
---
# Evidence — <TICKET>

## Acceptance criteria
- [x] Given ..., When ..., Then ...
- [x] Given ..., When ..., Then ...

## Test output
<paste or summary>

## Visual evidence (if UI)
<screenshot path or description>

## Deviations from story
- <deviation> — <rationale>

## Verifier
**Status**: PASS | FAIL
**Ran at**: <timestamp>
**By**: scripts/verify.sh execute <TICKET>
```

## Board updates

When a ticket completes:
- Move it from `in_progress` to `review` (or `done` if `reviewer_required: false`).
- Append `✓ <STORY-ID> — <title> (<commit-hash>)` to the board's `Done` section.
- For each ticket that was blocked by this one, check if it's now ready (move from `Blocked` to `Ready`).

## Verifier

`scipts/verify.sh execute <TICKET>` returns PASS when:
- `<TICKET>` is in `ready` or `in_progress` on the board.
- `.foundry/tdd/<TICKET>.md` exists.
- `.foundry/qa/evidence/<TICKET>.md` exists.
- The commit hash on disk matches the one recorded.
- All acceptance criteria checkboxes are ticked in evidence.
- (Optional) the project's test suite passes.

If FAIL, the ticket stays in `in_progress` and the loop iterates again.

## Loop termination

Phase 6 ends when:
- The board's `Ready` + `In progress` lists are both empty.
- `auto_loop: false` (user paused).
- `DEV_PIPELINE_MAX_ITER` reached (default 50).

On end:
1. Update `.foundry/state.md`:
   - `phases.execute.status = complete | paused | halted`
   - `phases.execute.iterations = <N>`
   - `phases.execute.completed_tickets = <list>`
   - `current_phase = qa`
2. Prompt: `✓ Phase 7 (Execute) complete. <N> tickets shipped. Next: Phase 8 (QA). Run /foundry-qa or /foundry-loop-on.`

## Sub-loop — External-Review Convergence (PR / MR, optional)

Some tickets have an exit criterion of *"the review is open and all CI checks pass"* — e.g. a GitHub PR green, a GitLab MR green. For those, Phase 6 spawns a **tactical sub-loop** at the end of each ticket's ceremony. For *most* tickets (default `local-only`), no sub-loop is needed and the ticket is "done" the moment the local tests + evidence are recorded.

> **The default is local-only.** The loop is designed to work on a repo with no remote, no `gh`/`glab` CLI, and no PR system at all. PR/MR convergence is opt-in per ticket and per project.

### Configuration (two layers — project-wide default + per-ticket override)

1. **Project-wide default** — `phases.execute.platform` in `.foundry/state.md`. One of:
   - `none` (default): no external review platform. The PR sub-loop is **never** activated, regardless of what individual tickets request.
   - `github`: tickets can opt into `exit_criterion: pr-green` (uses `gh` CLI; the canonical "Ship PR Until Green" pattern).
   - `gitlab`: tickets can opt into `exit_criterion: mr-green` (uses `glab` CLI).
   - (Future: `azure-devops`, `bitbucket`, etc. — same shape.)

2. **Per-ticket override** — `exit_criterion` in `.foundry/plan/stories/<TICKET>.md` frontmatter. One of:
   - `local-only` (default): ticket is done when local tests pass + evidence recorded.
   - `pr-green`: ticket is done when the GitHub PR is open + all checks green (requires `platform: github`).
   - `mr-green`: ticket is done when the GitLab MR is open + pipeline green (requires `platform: gitlab`).
   - `commit-only`: ticket is done when committed to the working branch (no external review needed).

If the ticket's `exit_criterion` is incompatible with the project's `platform`, the verifier **fails with a clear error message** telling the agent to align the two.

### When to opt in
- The ticket's exit criterion is *"merged or merge-ready"* rather than *"code passes locally"*.
- A code-review CI is part of the project's quality gate (lint, type-check, tests, security scans).
- The agent should run unattended until the PR is green, not stop at the first push.

### Ceremony for `exit_criterion: pr-green` (step 10 of the ticket flow, conditional)

10. **Open or update the PR** with a summary + test plan. Capture the URL to:
    - `.foundry/state.md` → `phases.execute.prs.<TICKET>: <PR_URL>` (set by the agent after the push)
    - `.foundry/pr-state/<TICKET>.md` (the per-PR state file using `templates/pr-state.md`)
11. **Run the sub-loop** — repeatedly until all checks pass, the hard-cap is reached, or the agent reports blockers. Each iteration:
    a. `gh pr checks <PR_URL>` — read the rollup.
    b. If any check is FAILING: read its logs (`gh run view --log-failed`), fix locally, commit, push. Re-run the check.
    c. If all checks pass: write `.foundry/pr-state/<TICKET>.md` `## Status: green` + commit hash + check rollup; move ticket to `done`.
    d. **Anti-gaming rules** (the three "Ship PR Until Green" invariants — the named rules that prevent the agent from gaming the verifier):
       - *Do not modify the check command or exit criteria to force success.*
       - *Do not skip, disable, or bypass checks to pass the exit condition.*
       - *If stuck after several iterations, stop and report blockers instead of gaming metrics.*
    e. **Max iterations**: 10 (per-ticket; independent of the Ralph `DEV_PIPELINE_MAX_ITER`). On cap: pause loop, surface the failure mode in `pr-state.md` §Blockers, route a `NEW-###` ticket back to the board.
12. **Verifier exit**: `scripts/verify.sh pr <PR_URL>` returns PASS only when `gh pr checks <PR_URL>` shows zero failures AND `pr-state/<TICKET>.md` is marked `## Status: green`.

For `mr-green` (GitLab), the same flow uses `glab mr` / `glab ci status` instead of `gh pr`. Same template, same verifier schema, different CLI commands.

### What this sub-loop gives you that ad-hoc pushing doesn't
- **Convergent termination** with a hard cap — no runaway agents.
- **Independent evidence** of "green" — the verifier inspects the platform's checks rollup, not just local test output.
- **Cross-phase memory** — `pr-state/<TICKET>.md` captures the per-PR fix-up history so QA (Phase 7) and the human reviewer can audit it without re-running anything.
- **Back-flow** — blockers surface as `NEW-###` tickets and re-enter the kanban rather than getting silently dropped.

### What it intentionally does NOT do
- It does **not** post review comments or reply to review threads automatically (that's the `pr-review-toolkit` plugin's job — optional dependency, see `plugin.json`).
- It does **not** merge the PR — `done` means green-and-ready, not merged. A human merges, by policy.
- It does **not** bypass the project's branch-protection rules — it plays within them.

### Local-only projects (the common case)
If `phases.execute.platform: none` (the default), the agent **does not** open a PR. Steps 10–12 above are skipped entirely. The ticket is done when local tests pass + evidence is recorded. The loop never references `gh` / `glab`. **`verify.sh pr` returns SKIP (not PASS, not FAIL)** when called on a `none`-platform project — it's a no-op. **The loop will not break on a repo with no remote.**

### Connector-failure semantics — HALT, don't mask

When the user has **opted into** a review platform (`platform: github` or `platform: gitlab`) but the matching CLI is not on PATH, **this is a connector failure that the user must resolve**. The plugin does NOT silently skip and continue dev — that would mask a broken CI gate. Instead:

- **`scripts/verify.sh pr` returns FAIL (not SKIP)** with a three-option resolution message:
  - *"(a) install `gh` and ensure it is on PATH; (b) set `phases.execute.platform: none` (local-only); (c) change affected tickets' `exit_criterion` from `pr-green`/`mr-green` to `local-only`."*
- **`scripts/foundry-loop.sh execute` emits a HALT focus prompt** that explicitly tells the agent to **surface the issue to the user** and pause. No next-ticket focus prompt. No PR sub-loop focus prompt. The loop halts at the next iteration.
- The agent's job at the HALT focus prompt: stop iterating, surface the issue to the user (in chat), and wait for the user to either install the CLI, switch `platform`, or downgrade the affected ticket's `exit_criterion`.
- Once resolved, the user re-enables the loop with `/foundry-loop-on` and work continues.

This is deliberate asymmetry: **`platform: none` → SKIP (user opted out, no failure); `platform: github` + no `gh` → FAIL (user opted in, broken connector — must fix).** The asymmetry keeps local-only projects frictionless while making review-platform configurations loud.

### Plugin-side behaviour
- `foundry-loop.sh execute` only emits sub-loop focus prompts when at least one ticket has a non-`none` `exit_criterion` AND the project's `platform` matches AND the matching CLI is on PATH.
- `foundry-loop.sh execute` emits a **HALT focus prompt** (above) when `platform` is set but the CLI is missing. The loop pauses; the user must resolve.
- `verify.sh pr` returns:
  - `SKIP` when `platform=none` (default; user opted out).
  - `FAIL` when `platform` is set but the CLI is missing (connector failure).
  - `FAIL` when `platform` is set, CLI is present, and any CI check is genuinely failing (legitimate failure).
  - `PASS` when `platform` is set, CLI is present, all checks pass, and `pr-state/<TICKET>.md` is marked `## Status: green`.
  - `FAIL` when the platform string is unknown (e.g. `gitea` typo) — config errors are visible, not masked.
- `foundry-loop.sh execute` will not block forever on a PR sub-loop: the 10-iteration cap routes blockers as `NEW-###` tickets to the board.

## v1.2.0 — Real sub-agent + real test runner

### What changed

In v1.2.0, this phase no longer re-feeds a focus prompt into the same context. Instead:

1. The orchestrator reads the next ticket from `.foundry/plan/board.md` (via `scripts/foundry-loop.sh execute`).
2. The orchestrator invokes a fresh-context writer sub-agent via the `Agent` tool:

```
PROMPT_BODY = $(bash scripts/foundry-spawn-writer.sh STORY-XXX)

Agent(
  profileId = "general-purpose",            # built-in profile
  description = "Implement STORY-XXX via TDD",
  prompt = PROMPT_BODY,                      # = role-prompt + ticket payload + story + TDD
  outputFile = ".foundry/tdd/STORY-XXX.md"
)
```

3. The sub-agent (role from `agents/foundry-writer.md`) implements the ticket end-to-end: red tests → green code → refactor → evidence → commit → board update. **Fresh context, no prior-failure bias.**
4. After the sub-agent returns, the orchestrator runs the **real** verifier:

```
bash scripts/verify.sh execute STORY-XXX
```

This invokes `scripts/foundry-test-runner.sh STORY-XXX`, which actually runs the project's `test_cmd` (jest / vitest / pytest / go-test / etc.), parses pass/fail/coverage/lint/typecheck, caches the result by `(ticket, commit)`, and emits a structured JSON verdict.

5. PASS → move ticket from In progress to Review (or Done if `reviewer_required: false`). FAIL → re-feed the failure JSON's `reason` to the next writer spawn (Ralph re-entry).
6. Loop until `## Ready` is empty → `current_phase: qa` → `foundry-qa`.

### Per-ticket ceremony (what the writer sub-agent does)

The full ceremony is in `agents/foundry-writer.md`. Summary:

| Step | Action |
|------|--------|
| 1 | Read story + frozen TDD spec |
| 2 | `git checkout -b feat/STORY-XXX` |
| 3 | Red — write failing tests |
| 4 | Green — minimum code to pass |
| 5 | Refactor — clean up |
| 6 | Run `foundry-test-runner.sh STORY-XXX`; embed result JSON in evidence frontmatter |
| 7 | (Optional) Literate diff to `.foundry/literate/<commit7>.md` |
| 8 | Commit: `feat(STORY-XXX): <one-line summary>` |
| 9 | Update board: move ticket to Review or Done |
| 10 | Update story frontmatter (`commit`, `branch`, `iterations`, `test_results`, etc.) |
| 11 | End with JSON tail: `{"status":"PASS","commit":"abc1234","tests_run":N,...}` |

### Why a sub-agent (not the same context)?

- **Fresh context** prevents anterograde-amnesia drift (Karpathy).
- **Lower-power model** for review/cross-review (Willison: *"use your judgement to decide an appropriate lower power model"*).
- **Anthropic's writer/reviewer pattern**: fresh reviewer catches biases the writer has.
- **Tool isolation**: writer sub-agent runs in its own allowed-tool set; can't accidentally call hooks that would re-feed the loop.

### Failure modes (writer sub-agent)

- Tests fail → fix code, re-run (don't change tests to make them pass).
- Coverage drops > 2% → add tests until coverage recovers.
- Lint fails → fix the lints (don't disable rules).
- Typecheck fails → fix the types (don't `@ts-ignore`).
- TDD spec has a real gap → write the test, surface as `NEW-###` finding in JSON tail.
- Blocked by external dep → surface as `NEW-###` P3, keep ticket in progress.

## Cross-references

- **mattpocock/skills/tdd** — red/green discipline.
- **Anthropic /goal** — *"A separate evaluator re-checks it after every turn and Claude keeps working until it holds."*
- **Ralph loop** (Wiggum technique) — same prompt, fresh context, external state.
- **Geoffrey Litt** — *code like a surgeon*; the prototype is primary work, not secondary.
- **Cursor Composer** — fastest UI iteration loop in mid-2026.
- **Worktrees** — *"run separate CLI sessions in isolated git checkouts so edits don't collide."*
- **Sub-agents** — *"run in their own context with their own set of allowed tools."*
- **Agent teams** — automated coordination of multiple sessions with shared tasks, messaging, team lead.
- **Ship PR Until Green** (loops.elorm.xyz) — the canonical external pattern this sub-loop absorbs.

## Named expert inputs

- **Pocock** — Ralph loop; AFK is a consequence of doing Phases 1–5 well.
- **Anthropic** — /goal, worktrees, sub-agents, agent teams, /clear, /compact, /rewind.
- **Willison** — *"For all coding tasks use your judgement to decide an appropriate lower power model and run that in a subagent."* (3 Jul 2026)
- **Goedecke** — *"When in doubt, use agents."* The execution loop is the canonical agent use case.
- **Karpathy** — *Anterograde amnesia* — fresh context per ticket prevents amnesia-induced drift.
- **Ship PR Until Green authors** (loops.elorm.xyz, 2026) — the *sub-loop shape* (4 phases, anti-gaming rules, max-iteration cap). Their loop is tactical (single PR); ours wraps it in the general-purpose Ralph so the sub-loop inherits the project's board + verifier + state.
- **Sean Lynch** (via Willison, 19 Jun 2026) — *MCP as auth gateway*. Implication for the plugin: future ticket-exit-criterion could include "MCP-authed remote" without hard-coding `gh` / `glab`.
