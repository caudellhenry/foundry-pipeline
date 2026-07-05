# User Guide — `foundry-pipeline` v2.0.0

> Single source of truth: `caudellhenry/foundry-pipeline`. This is the canonical end-to-end walkthrough.

> **Status:** Phase A skeleton. Full user guide ships in Phase F (see [`ROLLOUT.md`](ROLLOUT.md)).

---

## 0. The pitch

Foundry is a seven-phase AI-engineering pipeline that takes a fuzzy idea and produces a working MVP. The same workflow runs on **your** machine, on **your** harness, with **your** choice of tracker (local markdown, GitHub Issues, or Linear).

```
Idea → Research → Prototype → PRD → Plan/Kanban → Execution loop (Ralph) → QA
                          ▲                                       │
                          └───────── loops 5/6/7 ─────────────────┘
```

---

## 1. Install

See [`INSTALL.md`](INSTALL.md) for the per-harness matrix. TL;DR:

| Harness | Install |
|---|---|
| Claude Code | `/plugin marketplace add caudellhenry/foundry-pipeline` |
| Zcode | `bash packages/zcode/install.sh` |
| Hermes | `bash packages/hermes/install.sh` |
| OpenCode | `bash packages/opencode/install.sh` |
| Antigravity | `bash packages/antigravity/install.sh` |
| MimoCode | `bash packages/mimocode/install.sh` |
| skills.sh | `npx skills add caudellhenry/foundry-pipeline` |

---

## 2. First run

```bash
cd /path/to/your/project

# Bootstrap + start Phase 1 (Idea)
/foundry:init                              # first-run wizard (pick tracker)
/foundry:ship "ship: add Stripe-backed subscriptions to the SaaS"
```

The `/foundry:init` wizard asks:
1. Where should tickets live? (Local / GitHub Issues / Linear)
2. (if GitHub) Which repo?
3. (if Linear) Which team?
4. Create a test issue to validate? (y/N)

After init, `/foundry:ship` runs:
1. Detects your test runner (`package.json` / `pyproject.toml` / `go.mod` / `Cargo.toml`)
2. Auto-fills `state.md` `test:` block
3. Starts Phase 1 (Idea / grill-me)

---

## 3. Slash commands (canonical surface)

| Command | Phase | Effect |
|---|---|---|
| `/foundry:init` | — | First-run wizard |
| `/foundry:ship "<intent>"` | bootstrap | Start the pipeline |
| `/foundry:grill "<topic>"` | 1 | Idea interview |
| `/foundry:research "<q>"` | 2 | External-knowledge cache |
| `/foundry:prototype "<dq>"` | 3 | Throwaway variants |
| `/foundry:prd` | 4 | Destination document |
| `/foundry:board` | 5 | Vertical-slice tickets |
| `/foundry:plan` | 5 | Planning |
| `/foundry:implement [T]` | 6 | Execute ticket(s) |
| `/foundry:review [T]` | 7 | Fresh-context review |
| `/foundry:qa` | 7 | Round synthesis |
| `/foundry:status` | — | One-page state |
| `/foundry:reset` | — | Reset state |
| `/foundry:signoff [--by=<name>]` | — | Mark signed-off (gate 8) |
| `/foundry:test-config [<k> <v>]` | — | View/edit test: block |
| `/foundry:set-coverage-baseline` | — | Set coverage baseline |
| `/foundry:approve-review <T>` | — | Mark review human-approved (gate 2) |
| `/foundry:parallel-on [max_workers=3]` | 6 | Enable parallel fan-out |
| `/foundry:loop-on` / `/foundry:loop-off` | 6/7 | AFK mode toggle |
| `/foundry:eval [scenario]` | — | Run agent-eval harness |
| `/foundry:literate-diff [hash]` | — | Produce literate diff |
| `/foundry:self-improve [--since D] [--commit]` | — | Skill-improver meta-skill |
| `/foundry:patch-check` | — | Detect local divergence |
| `/foundry:patch-diff` | — | Show local vs canonical diff |
| `/foundry:patch-push` | — | Push local edits to canonical |
| `/foundry:patch-reset` | — | Reinstall canonical |
| `/foundry:patch-skip [days=30]` | — | Snooze divergence alerts |

---

## 4. The 8-gate convergence check

When all 8 gates pass, the pipeline is "done" (awaiting your signoff via `/foundry:signoff`):

1. **Board empty** — Ready + In progress = 0
2. **Review empty** — every Review ticket `human_approved: true`
3. **No high findings** — `qa-plan.md findings.high == 0`
4. **No medium findings** — `qa-plan.md findings.medium == 0`
5. **Tests pass** — latest runner JSON `failed == 0`
6. **Coverage gate** — `coverage_pct >= threshold` AND `>= baseline - 2%`
7. **Lint + typecheck clean** — both 0 errors
8. **User signoff** — `state.md signoff.user_signed_off == true`

---

## 5. Patch-push workflow

See [`PATCH_PUSH_WORKFLOW.md`](PATCH_PUSH_WORKFLOW.md). When your local install diverges from canonical, you see:

```
⚠️  foundry v2.0.0 installed locally differs from canonical v2.0.0.

    3 files modified (skills/foundry-ship/SKILL.md, scripts/foundry-loop.sh, ...).
    1 unpushed commit ahead.

    Commands:
      /foundry:patch-diff    Show the diff vs canonical
      /foundry:patch-push    Push local changes to caudellhenry/foundry-pipeline
      /foundry:patch-reset   Discard local changes, reinstall canonical v2.0.0
      /foundry:patch-skip    Ignore this divergence (default 30 days)
```

---

## 6. See also

- [`ARCHITECTURE.md`](ARCHITECTURE.md)
- [`INSTALL.md`](INSTALL.md)
- [`TRACKER_GUIDE.md`](TRACKER_GUIDE.md)
- [`PATCH_PUSH_WORKFLOW.md`](PATCH_PUSH_WORKFLOW.md)
- [`MIGRATION.md`](MIGRATION.md)
- [`ROLLOUT.md`](ROLLOUT.md)