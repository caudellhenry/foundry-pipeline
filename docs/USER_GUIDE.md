# User Guide — `foundry-pipeline` v2.0.0

> Single source of truth: `caudellhenry/foundry-pipeline`. This is the canonical end-to-end walkthrough.

---

## 0. The pitch

Foundry is a seven-phase AI-engineering pipeline that takes a fuzzy idea and produces a working MVP. The same workflow runs on **your** machine, on **your** harness, with **your** choice of tracker (local markdown, GitHub Issues, or Linear).

```
Idea → Research → Prototype → PRD → Plan/Kanban → Execution loop (Ralph) → QA
                          ▲                                       │
                          └───────── loops 5/6/7 ─────────────────┘
```

Every install is the **same canonical version** (`v2.0.0`), regardless of harness. Every `SKILL.md` carries `foundry_version: 2.0.0` so any agent can verify what it has.

---

## 1. Install

See [`docs/INSTALL.md`](INSTALL.md) for the per-harness matrix. Quick paths:

```bash
# Claude Code (marketplace — recommended once published)
/plugin marketplace add caudellhenry/foundry-pipeline

# Zcode
bash packages/zcode/install.sh

# Hermes / OpenCode
bash packages/hermes/install.sh

# Antigravity / MimoCode
bash packages/antigravity/install.sh

# skills.sh (skills only — no commands/hooks)
npx skills add caudellhenry/foundry-pipeline
```

After install, **always verify** with the status command (works on every harness):

```bash
/foundry:status
# or: foundry-status (shell)
```

---

## 2. First-run wizard

```bash
cd /path/to/your/project

# Interactive: pick tracker + auto-detect test runner
/foundry:init

# Or non-interactive flags:
/foundry:init --tracker=local
/foundry:init --tracker=github --repo=owner/name
/foundry:init --tracker=linear --team-id=ABC-123
```

The wizard writes `.foundry/state.md` (with the `tracker:` block) and, for non-local trackers, a `.mcp.json` entry.

---

## 3. The seven phases

### Phase 1 — Idea (`/foundry:grill`)

One question at a time. The agent interviews you about Who, What, Why now, Size, Out of scope, Assumptions, Success criteria, Failure modes, Constraints, Pre-mortem.

**Output:** `.foundry/idea/intent.md` + `risks.md`.

### Phase 2 — Research (`/foundry:research`) — *conditional*

If the work depends on an unfamiliar external (API, SDK, protocol), do primary-source research and cache it with an expiry date.

**Output:** `.foundry/research/research.md`.

### Phase 3 — Prototype (`/foundry:prototype`) — *conditional*

When taste or a structural choice can't be decided on paper, build 2-3 throwaway variants in disposable worktrees. Human picks a winner. Losers deleted.

### Phase 4 — PRD (`/foundry:prd`)

The destination document. Behavior-only, never the implementation. Human must approve before the next phase.

**Output:** `.foundry/prd.md`.

### Phase 5 — Plan + Board (`/foundry:plan` + `/foundry:board`)

Break the PRD into vertical slices. Each ticket:
- Is independently shippable
- Has its own acceptance criteria
- Links to the PRD user story

**Output:** tickets in your tracker (local `board.md`, GitHub Issues, or Linear) + TDD spec per ticket.

### Phase 6 — Execute (`/foundry:implement`)

For each ticket (one at a time, or in parallel with `/foundry:parallel-on`):
- Fresh-context `general-purpose` writer sub-agent (sonnet)
- TDD: red → green → refactor → evidence → commit on `feat/<TICKET>` branch
- Optional worktree isolation (`/foundry:parallel-on [N=3]`)
- Real test runner against your `package.json` / `pyproject.toml` / `go.mod` / `Cargo.toml`

### Phase 7 — QA (`/foundry:qa`)

Fresh-context sub-agents per ticket + per round:
- `foundry-reviewer` (Explore / lite) — per-ticket cognitive-debt + comprehension-debt check
- `foundry-cross-reviewer` (Explore / lite) — once per round, cross-ticket coherence
- `foundry-qa-planner` (general-purpose / sonnet) — round synthesis into `qa-plan.md` findings

**Termination:** all 8 convergence gates green + `/foundry:signoff`.

---

## 4. The 8 convergence gates

The QA loop terminates when all 8 gates pass:

| # | Gate | Check |
|---|---|---|
| 1 | Board empty | Ready + In progress = 0 |
| 2 | Review empty | every Review ticket `human_approved: true` |
| 3 | No high findings | `qa-plan.md findings.high == 0` |
| 4 | No medium findings | `qa-plan.md findings.medium == 0` |
| 5 | Tests pass | latest runner JSON `failed == 0` |
| 6 | Coverage gate | `coverage_pct >= threshold` AND `>= baseline - 2%` |
| 7 | Lint + typecheck clean | both 0 errors |
| 8 | User signoff | `state.md signoff.user_signed_off == true` (`/foundry:signoff`) |

**Failure routing:** gates 1-2 → loop back to Phase 6; gates 3-7 → writer sub-agent fixes; gate 8 → prompt `/foundry:signoff`.

---

## 5. Tracker flexibility

Switch backends any time. State stored in `state.md` frontmatter:

```yaml
tracker:
  backend: local | github | linear
  repo: owner/name       # required if github
  team_id: UUID          # required if linear
```

| Backend | Storage | Auth |
|---|---|---|
| `local` | `.foundry/board.md` + `.foundry/issues/*.md` | none |
| `github` | GitHub Issues | MCP, `gh auth login`, or `$GITHUB_TOKEN` |
| `linear` | Linear | MCP or `$LINEAR_API_KEY` |

All three expose the same 7-function API (`tracker_create_issue`, `tracker_update_status`, etc.). The `/foundry:board` skill calls the right adapter at runtime.

---

## 6. Patch-push workflow

When you edit installed files locally, the agent prompts you at every `SessionStart`:

```
⚠️  foundry v2.0.0 installed locally differs from canonical v2.0.0.

    3 files modified (skills/ship/SKILL.md, scripts/foundry-loop.sh, ...).
    1 unpushed commit ahead.

    Commands:
      /foundry:patch-diff    Show the diff vs canonical
      /foundry:patch-push    Push local changes to caudellhenry/foundry-pipeline
      /foundry:patch-reset   Discard local changes, reinstall canonical v2.0.0
      /foundry:patch-skip    Ignore this divergence (default 30 days)
```

`/foundry:patch-push` opens a PR for you (auto-forks if needed, runs the eval gate, fills the PR template).

---

## 7. Slash commands (canonical surface)

| Command | Phase | Effect |
|---|---|---|
| `/foundry:init` | — | First-run wizard (tracker picker) |
| `/foundry:ship "<intent>"` | bootstrap | Start the pipeline |
| `/foundry:grill` | 1 | Idea interview |
| `/foundry:research` | 2 | External-knowledge cache |
| `/foundry:prototype` | 3 | Throwaway variants |
| `/foundry:prd` | 4 | Destination document |
| `/foundry:board` | 5 | Vertical-slice tickets |
| `/foundry:plan` | 5 | Planning |
| `/foundry:tdd` | 5 | TDD test specs |
| `/foundry:implement` | 6 | Execute next ticket |
| `/foundry:review` | 7 | Fresh-context review |
| `/foundry:qa` | 7 | Round synthesis |
| `/foundry:status` | — | One-page state |
| `/foundry:reset` | — | Reset state |
| `/foundry:signoff` | — | Mark signed-off (gate 8) |
| `/foundry:test-config` | — | View/edit test: block |
| `/foundry:set-coverage-baseline` | — | Set coverage baseline |
| `/foundry:approve-review <T>` | — | Mark review human-approved (gate 2) |
| `/foundry:parallel-on [N=3]` | 6 | Enable parallel fan-out |
| `/foundry:loop-on` / `loop-off` | 6/7 | AFK mode toggle |
| `/foundry:eval [scenario]` | — | Run agent-eval harness |
| `/foundry:literate-diff [hash]` | — | Produce literate diff |
| `/foundry:self-improve` | — | Skill-improver meta-skill |
| `/foundry:diagnose` | — | Disciplined 6-step bug hunt |
| `/foundry:security-review` | — | Diff / MCP / setup audit |
| `/foundry:handoff` | — | Session → handoff.md |
| `/foundry:patch-check` | — | Detect local divergence |
| `/foundry:patch-diff` | — | Show local vs canonical diff |
| `/foundry:patch-push` | — | Open PR to canonical |
| `/foundry:patch-reset` | — | Reinstall canonical |
| `/foundry:patch-skip` | — | Snooze divergence alerts |

---

## 8. Per-harness install

### Claude Code

```bash
/plugin marketplace add caudellhenry/foundry-pipeline
/plugin install foundry-pipeline@foundry-pipeline-marketplace
/foundry:status
```

### Zcode

```bash
bash packages/zcode/install.sh
# Restart Zcode
/foundry:status
```

### Hermes

```bash
bash packages/hermes/install.sh
# Restart Hermes
```

Hermes auto-discovers skills in `~/.hermes/skills/`. The install creates 15 `foundry-*` symlinks there.

### OpenCode

```bash
bash packages/opencode/install.sh
# Restart OpenCode
```

### Antigravity

```bash
bash packages/antigravity/install.sh
# Restart Antigravity
```

### MimoCode

```bash
bash packages/mimocode/install.sh
# Restart MimoCode
```

### skills.sh (skills only)

```bash
npx skills add caudellhenry/foundry-pipeline
```

Note: skills.sh doesn't support commands or hooks — only skills auto-invoke based on description match.

---

## 9. Example end-to-end session

```bash
cd ~/projects/saas-app

# Bootstrap
/foundry:init --tracker=local
# Picks local. Writes .foundry/state.md, board.md, issues/.gitkeep.

# Phase 1
/foundry:ship "build a SaaS app for dog walkers to schedule walks"
# /foundry:grill runs the interview. Writes .foundry/idea/intent.md.

# Phase 2
/foundry:research "Stripe subscription billing for SaaS"
# (conditional — only if external knowledge needed)
# Writes .foundry/research/research.md.

# Phase 3 (skip if no taste decision needed)
/foundry:prototype "calendar UI: week-view vs month-view vs list-view"
# Builds 3 disposable worktrees. User picks winner.

# Phase 4
/foundry:prd
# Synthesizes PRD.md from intent + research + prototype. User approves.

# Phase 5
/foundry:board
# Creates 12 tickets in .foundry/issues/ + adds to .foundry/board.md.
/foundry:tdd STORY-001
# Writes .foundry/tdd/STORY-001.md (TDD spec).

# Phase 6
/foundry:implement STORY-001
# Fresh-context writer sub-agent runs red→green→refactor on feat/STORY-001.
/foundry:implement STORY-002
# ...

# Phase 7
/foundry:review STORY-001
/foundry:qa
# Round synthesis → qa-plan.md with findings.
/foundry:implement NEW-001   # fix found by review

# Sign off
/foundry:signoff --by=henry
```

---

## 10. Update

```bash
# Re-run install for your harness — idempotent
bash packages/<harness>/install.sh

# Or in-agent:
/foundry:patch-check
/foundry:patch-diff
/foundry:patch-reset     # discard local edits, reinstall canonical
```

---

## 11. Uninstall

```bash
bash packages/<harness>/install.sh --uninstall
```

---

## 12. Troubleshooting

| Symptom | Fix |
|---|---|
| `jq: command not found` | `brew install jq` / `apt install jq` |
| Slash command not found | Restart your agent |
| `Permission denied` on install.sh | `chmod +x packages/*/install.sh` |
| Version drift between packages | `bash scripts/foundry-version-sync.sh` |
| Patch detection always fires | `/foundry:patch-skip 30` to snooze 30 days |
| Linear MCP not detected | Check `.mcp.json` has `mcpServers.linear`; or set `LINEAR_API_KEY` env var |
| GitHub MCP not detected | Check `.mcp.json` has `mcpServers.github`; or `gh auth login`; or `GITHUB_TOKEN` env var |

---

## 13. See also

- [`docs/ARCHITECTURE.md`](ARCHITECTURE.md) — monorepo + adapter + state machine
- [`docs/INSTALL.md`](INSTALL.md) — per-harness install details
- [`docs/TRACKER_GUIDE.md`](TRACKER_GUIDE.md) — local / GitHub / Linear setup
- [`docs/PATCH_PUSH_WORKFLOW.md`](PATCH_PUSH_WORKFLOW.md) — patch detection + push workflow
- [`docs/MIGRATION.md`](MIGRATION.md) — from v0.1.0 / v1.3.0 → v2.0.0
- [`docs/ROLLOUT.md`](ROLLOUT.md) — phased delivery checklist