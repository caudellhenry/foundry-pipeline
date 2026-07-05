---
name: foundry-orchestrator
description: Master orchestrator for the Foundry AI-engineering SDLC pipeline (Idea → Research → Prototype → PRD → Plan/Kanban → Execution → QA). Triggered by /foundry or $foundry. v1.0.0 dispatches the 4-spawn Anthropic A2 ceremony (explorer → planner → implementer → committer) per ticket + foundry-tester for adversarial QA. Reads .foundry/state.md, runs the convergent Dev/QA loop via stop-hook, persists all artefacts to local markdown, and surfaces phase status. Use when the user says /foundry, $foundry, "start the pipeline", "ship this feature", or invokes any foundry-* slash command.
---
foundry_version: 2.0.3

# /foundry — Foundry AI-Engineering Orchestrator

The `/foundry` command is the single entry point to the **seven-phase AI-engineering shipping workflow** (Pocock + Anthropic + Litt). v1.0.0 ships the **4-spawn Anthropic A2 ceremony** (Explore → Plan → Implement → Commit) via five sub-agents, plus the security iteration-cap (arXiv 2506.11022) and 8-gate machine-checkable convergence.

## Sub-agent matrix (v1.0.0)

| Role | Profile | Default model | Spawner | Output |
|---|---|---|---|---|
| **Explorer** | `Explore` | lite | `foundry-spawn-explorer.sh` | `EXPLORER_REPORT` (read ticket + TDD + code; returns 1,500-token plan) |
| **Planner** | `Explore` | lite | `foundry-spawn-planner.sh` | `PLANNER_REPORT` (step-by-step plan OR `skip_plan: true`) |
| **Implementer** | `general-purpose` | sonnet | `foundry-spawn-implementer.sh` | red→green→refactor + commit + evidence |
| **Committer** | `general-purpose` | lite | `foundry-spawn-committer.sh` | board update + story frontmatter + daily log |
| **Tester** (adversarial) | `Explore` | lite | `foundry-spawn-tester.sh` | `verdict: PASS \| FAIL` (tries to break the implementation) |
| Reviewer (per-ticket, kept) | `Explore` | lite | `foundry-spawn-reviewer.sh` | severity-ranked findings |
| Cross-Reviewer (kept) | `Explore` | lite | `foundry-spawn-cross-reviewer.sh` | cross-ticket coherence |
| QA-Planner (kept) | `general-purpose` | sonnet | `foundry-spawn-qa-planner.sh` | synthesizes reviews into qa-plan.md |

## Per-ticket ceremony (Anthropic A2)

For each Ready ticket, the orchestrator dispatches **4 sub-agents in sequence**:

```
1. EXPLORER (read-only)
   bash foundry-spawn-explorer.sh $TICKET
   → Agent(profileId=Explore, prompt=..., outputFile=.foundry/tdd/$TICKET.explorer.json)

2. PLANNER (pure plan-mode)
   bash foundry-spawn-planner.sh $TICKET
   input: explorer's report
   → Agent(profileId=Explore, prompt=..., outputFile=.foundry/tdd/$TICKET.planner.json)
   if planner.skip_plan == true:
       skip to committer (one-sentence diff)
   else:
       continue to implementer

3. IMPLEMENTER (worktree-isolated, TDD)
   WT_PATH = foundry-worktree.sh create $TICKET
   bash foundry-spawn-implementer.sh $TICKET $WT_PATH
   → Agent(profileId=general-purpose, prompt=..., outputFile=.foundry/tdd/$TICKET.md)
   - red → green → refactor → evidence → commit
   - iteration-cap enforced (3 consecutive failures = hard halt)
   if status == ITERATION_CAP: surface halt, request human review
   if status == FAIL: re-feed failure to next attempt (Ralph re-entry)

4. COMMITTER (mechanical, cheap)
   bash foundry-spawn-committer.sh $TICKET $WT_PATH
   → Agent(profileId=general-purpose, prompt=..., outputFile=.foundry/qa/evidence/$TICKET.committed.json)
   - updates board, story frontmatter, daily log

5. ADVERSARIAL TESTER (post-implementation, forked)
   bash foundry-spawn-tester.sh $TICKET
   → Agent(profileId=Explore, prompt=..., outputFile=.foundry/qa/review/$TICKET.tester.json)
   verdict PASS/FAIL
   if FAIL: route findings as NEW-### tickets
```

After 1-4 succeed, the orchestrator merges `feat/$TICKET` to main and cleans up the worktree.

## Quick reference

| Invocation | Effect |
|---|---|
| `/foundry "<intent>"` | Bootstrap the pipeline in the current project + advance from Phase 1 |
| `/foundry-status` | Show pipeline state (current phase, board, QA cycle, loop state) |
| `/foundry-idea` | Force entry to Phase 1 (Idea / grill-me) |
| `/foundry-research` | Force entry to Phase 2 (Research) |
| `/foundry-prototype` | Force entry to Phase 3 (Prototype / TDD tracer bullet) |
| `/foundry-prd` | Force entry to Phase 4 (PRD) |
| `/foundry-plan` | Force entry to Phase 5 (Plan / Kanban) |
| `/foundry-execute` | Force entry to Phase 6 (Execution loop / Ralph) |
| `/foundry-qa` | Force entry to Phase 7 (QA) |
| `/foundry-loop-on` | Enable auto-loop on Phases 5/6/7 |
| `/foundry-loop-off` | Disable auto-loop |
| `/foundry-reset` | Reset pipeline state (preserves templates) |
| `$foundry` | Bash alias for `/foundry` (set up in your shell: `alias $foundry='/foundry'`) |

## Architecture

The plugin ships **one slash command per phase** plus the **master orchestrator** that runs them. State lives in `.foundry/state.md` in the project root. Hooks (SessionStart, UserPromptSubmit, Pre/PostToolUse, Stop) form the chain that advances the pipeline and keeps the Dev/QA loop running.

```
SessionStart  ->  bootstrap .foundry/ if missing
                       |
UserPromptSubmit ->  log the user's intent
                       |
Stop (stop-hook) -> check verifier -> advance phase or loop Dev/QA
                       |
PreToolUse (Bash) ->  validate scope (operate only inside project root + .foundry)
                       |
PostToolUse ->  append to phase log under .foundry/logs/<phase>.log
```

## Phase model (Pocock's seven phases)

| # | Phase | Skill | Conditional? | Output artefact |
|---|-------|-------|--------------|-----------------|
| 1 | Idea | `foundry-idea` | No | `.foundry/idea/{intent,risks}.md` |
| 2 | Research | `foundry-research` | Yes | `.foundry/research/research.md` (with expiry) |
| 3 | Prototype | `foundry-prototype` | Yes | `.foundry/prototype/notes.md` + tracer-bullet code |
| 4 | PRD | `foundry-prd` | No | `.foundry/prd.md` (destination doc) |
| 5 | Plan / Kanban | `foundry-plan` | No | `.foundry/plan/{features,board}.md` |
| 6 | Execution loop | `foundry-execute` | No (loops) | per-ticket `.foundry/tdd/<TICKET>.md` + commits |
| 7 | QA | `foundry-qa` | No (loops with 5/6) | `.foundry/qa/{plan,evidence}.md` |

Cross-cutting skills: `foundry-context-rotate` (Breunig four failure modes), `foundry-agent-eval` (SWE-bench-style fixtures), `foundry-literate-diff` (Litt's `/explore-diff` analogue).

## Loop semantics

Phases 6/7 (execute + qa) form a **convergent loop** that runs until the 8-gate convergence check passes and the user signs off:

```
   +----------- phase 7 (QA) ----------+
   |  per-ticket reviewer sub-agent    |  <-- Explore / lite (fresh context per ticket)
   |  cross-ticket reviewer sub-agent  |  <-- Explore / lite (one per round)
   |  QA planner sub-agent             |  <-- general-purpose / sonnet
   |  8-gate convergence check         |  <-- machine-checkable
   |  human sign-off                   |  <-- /foundry-signoff
   +------------------------------------+
                 |
                 v (NEW-### tickets)
   +----------- phase 6 (Execute) ------+
   |  writer sub-agent per ticket      |  <-- general-purpose / sonnet (fresh context)
   |  real test runner (verify.sh)     |  <-- jest|vitest|pytest|go-test|cargo-test
   |  coverage / lint / typecheck      |  <-- gates from state.md
   |  PR sub-loop (if platform set)    |  <-- Ship PR Until Green
   +------------------------------------+
                 |
                 v (commit + evidence)
   +----------- phase 7 (QA) ----------+
                 ...
```

The loop is driven by the `stop-hook.sh` script (see `hooks/stop-hook.sh`). When `auto_loop: true` in `.foundry/state.md`, the stop-hook:
1. Reads the current phase.
2. Runs the phase's verifier (defined in `scripts/verify.sh`).
3. If verified, advances to the next phase.
4. For phases 6/7, loops within the phase until the 8-gate convergence check passes (or `DEV_PIPELINE_MAX_ITER` is hit).

### v1.2.0 — Sub-agent dispatch (the actual loop driver)

In v1.2.0, the loop body is **not** re-fed into the orchestrator's own context. Instead, the orchestrator invokes the `Agent` tool with a fresh-context sub-agent for each unit of work:

| Unit of work | Agent `profileId` | Role prompt | Model |
|--------------|-------------------|-------------|-------|
| Implement one ticket | `general-purpose` | `agents/foundry-writer.md` | `models.writer` (default: sonnet) |
| Review one shipped ticket | `Explore` | `agents/foundry-reviewer.md` | `models.reviewer` (default: lite) |
| Cross-ticket coherence (once per round) | `Explore` | `agents/foundry-cross-reviewer.md` | `models.cross_reviewer` (default: lite) |
| Synthesise QA round into qa-plan.md | `general-purpose` | `agents/foundry-qa-planner.md` | `models.qa_planner` (default: sonnet) |

The spawner scripts (`scripts/foundry-spawn-{writer,reviewer,cross-reviewer,qa-planner}.sh`) concatenate the role prompt + per-ticket payload (story, TDD spec, evidence, diff) into a complete `prompt` body the Agent tool consumes.

The orchestrator SKILL's job per loop iteration:
1. Read `state.md` to know the current phase, iteration, model config.
2. Call the appropriate spawner script.
3. Invoke the `Agent` tool with the produced prompt body.
4. Wait for the sub-agent to complete; check its JSON tail.
5. Run the real verifier (`scripts/verify.sh <phase> [args]`).
6. Update state.md (`phases.execute.iterations`, `phases.qa.rounds`, story frontmatter, etc.).
7. Surface status to the user (or, if `auto_loop: true`, let the stop-hook block exit and re-feed).

## On invocation

1. Run `bash "$DEV_PIPELINE_ROOT/scripts/foundry-state.sh" ensure` to bootstrap `.foundry/` if missing.
2. Read `.foundry/state.md` to find the current phase.
3. Dispatch to the appropriate phase skill (`foundry-idea`, `foundry-research`, ...).
4. Surface phase status to the user (current phase, board progress, QA cycle).
5. If `auto_loop: true`, the stop-hook will keep the loop running.

## Artefacts

All artefacts are local markdown files under `.foundry/` in the project root. The plugin does **not** require Linear / GitHub / Notion / Figma to function — those are optional future integrations. For now:

- `intent.md`, `risks.md` (Phase 1)
- `research.md` (Phase 2)
- `prototype/notes.md` (Phase 3)
- `prd.md` (Phase 4)
- `plan/features.md`, `plan/board.md`, `plan/stories/<STORY>.md` (Phase 5)
- `tdd/<TICKET>.md` (Phase 6, red/green notes)
- `qa/qa-plan.md`, `qa/evidence/<TICKET>.md` (Phase 7)
- `state.md` (master state)
- `logs/<phase>.log` (per-phase tool-call log)

Templates for each artefact live in `$DEV_PIPELINE_ROOT/templates/`.

## Slash-command to skill mapping

Each `commands/foundry-*.md` is a thin wrapper that:
1. Ensures `.foundry/state.md` exists.
2. Sets the current phase in state.
3. Invokes the corresponding skill (`skills/foundry-<phase>/SKILL.md`) via the Skill tool.

The skill then owns the full conversational ceremony for that phase — Q&A, artefact production, completion criteria.

## Environment variables

The orchestrator and hooks read these (set automatically by the plugin loader):

| Var | Meaning | Default |
|-----|---------|---------|
| `DEV_PIPELINE_ROOT` | Absolute path to this plugin's root | (this directory) |
| `DEV_PIPELINE_STATE` | Absolute path to `.foundry/state.md` | `<project>/.foundry/state.md` |
| `DEV_PIPELINE_AUTO_LOOP` | `1` if auto-loop is on | `0` |
| `DEV_PIPELINE_MAX_ITER` | Max iterations for Dev/QA loops | `50` |

## v1.3.0 — Worktree isolation + parallel fan-out (FR-20260704-008 + FR-20260704-009)

### Worktree isolation (FR-008)

By default, `state.md worktree.enabled: true`. Each writer sub-agent operates in its own git worktree at `<project_parent>/<project_basename>-<TICKET>/`, on branch `feat/<TICKET>`. After the writer succeeds, the orchestrator merges `feat/<TICKET>` into the current branch with `--no-ff` and removes the worktree.

Why this matters:
- **No clobbering** — in-progress tickets can't trample each other's files.
- **Clean per-ticket history** — each ticket's commits are isolated; PR review is trivial.
- **Failed tickets are disposable** — `git worktree remove --force` discards everything; main stays clean.
- **Foundation for parallel** — without worktrees, FR-009 is impossible.

The worktree script: `scripts/foundry-worktree.sh {create,path,exists,remove,merge,list,cleanup,path-parent} <TICKET>`.

Toggle: `foundry-state.sh set-worktree enabled|disabled`.

### Parallel fan-out (FR-009)

When `state.md parallel.enabled: true`, the orchestrator reads `board.md` §"## Parallelisable now" (the line listing tickets with no blocking relationships) and spawns up to `parallel.max_workers` writer sub-agents in parallel. Each runs in its own worktree (no conflicts). After all writers return, the orchestrator merges serially (`serial-merge` strategy) so conflicts surface one-at-a-time.

The orchestration flow:

```
1. Read board.md §"## Parallelisable now"  → list of independent tickets
2. For each independent ticket (up to max_workers):
     WT_PATH = foundry-worktree.sh create $TICKET
     PROMPT_BODY = foundry-spawn-writer.sh $TICKET --worktree-path=$WT_PATH
     Agent(profileId=general-purpose, prompt=PROMPT_BODY, outputFile=.foundry/tdd/$TICKET.md)
3. For each completed ticket (serial-merge strategy):
     foundry-worktree.sh merge $TICKET
     foundry-worktree.sh remove $TICKET
     verify.sh execute $TICKET
4. Update board: each ticket moves from In progress to Review or Done.
5. If any writer FAILED: don't merge that worktree; route the failure as a NEW-### finding.
```

Toggle: `foundry-state.sh set-parallel enabled [max_workers=3]`.

### Concurrency caveat

ZCode's `Agent` tool may not support true concurrent invocations (the runtime emits one metadata.json per call, suggesting serial semantics). If true concurrency is unavailable:
- Run the parallel tickets **sequentially within a single turn**: TodoWrite each as `in_progress`, invoke Agent for each, advance to `completed`. This is what the orchestrator SKILL's focus prompt instructs.
- The worktree isolation still provides value: even serial execution gets clean per-ticket branches.
- For genuine speedup, run **multiple CLI sessions in parallel**, each handling a subset of tickets.

### Anti-patterns

- **Don't** run writers against `main` branch. Always use the worktree's `feat/<TICKET>` branch.
- **Don't** disable worktrees to "save disk space". The cost is per-ticket-branch clutter on `main`, which is worse.
- **Don't** enable parallel if the project's CI doesn't handle parallel-branch pushes well.
- **Don't** forget to merge — a merged-and-cleaned ticket is `done`; an unmerged worktree is `in_progress`.

### Migration from v1.2.0

v1.2.0 projects continue to work in v1.3.0 because `worktree.enabled` defaults to `true` but is per-project. To opt out: `foundry-state.sh set-worktree disabled`. To opt into parallel: `foundry-state.sh set-parallel enabled 3` (after the board has been populated with `## Parallelisable now`).

## See also

- `Knowledge Base/analysis/analysis_ai-engineering-practices-deep-research_2026-07-03.md` — the design source
- `Knowledge Base/podcast-summaries/SevenPhasesOfAIDevelopment_youtube_summary.md` — Pocock's original transcript
- `Knowledge Base/references/loop-command-guide.md` — workspace primitive that this plugin adopts
- `Skills/claude-plugins-official/plugins/ralph-loop/` — the underlying loop mechanism this plugin re-uses

## Meta

This plugin is the *first* concrete realisation of the skill map drawn in §7 of the analysis. It packages ready-to-ship skills (Pocock's `grill-me`, `tdd`, `to-prd`, `diagnose` patterns — re-implemented locally with markdown-only artefacts) plus the four `to-build` gaps (`research-cache`, `context-rotate`, `agent-eval`, `literate-diff`) as one installable unit.
