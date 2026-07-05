# Architecture — `foundry-pipeline` v2.0.0

> Single source of truth: `caudellhenry/foundry-pipeline`. This doc is the canonical architecture reference.

---

## 0. Bird's-eye

```
                          ┌─────────────────────────────────────┐
                          │      caudellhenry/foundry-pipeline  │
                          │      (this repo, single source)     │
                          └──────────────┬──────────────────────┘
                                         │
                       ┌─────────────────┼─────────────────────┐
                       │                 │                     │
                ┌──────▼──────┐  ┌───────▼──────┐  ┌───────────▼──────────┐
                │ packages/   │  │ packages/    │  │ packages/            │
                │ core/       │  │ claude-code/ │  │ zcode/ hermes/       │
                │ (portable)  │  │ zcode/       │  │ opencode/            │
                │             │  │              │  │ antigravity/         │
                │ - skills    │  │ + commands/  │  │ mimocode/            │
                │ - agents    │  │ + hooks/     │  │ skills-sh/           │
                │ - scripts   │  │ + install.sh │  │ + install.sh         │
                │ - templates │  │              │  │   (symlinks)         │
                │ - adapters  │  │              │  │                      │
                │ - evals     │  │              │  │                      │
                └──────┬──────┘  └───────┬──────┘  └───────────┬──────────┘
                       │                 │                     │
                       └─────────────────┼─────────────────────┘
                                         │
                          ┌──────────────▼──────────────┐
                          │  Target machine (any harness)│
                          │  ~/.claude/plugins/...       │
                          │  ~/.zcode/cli/plugins/...    │
                          │  ~/.hermes/skills/...        │
                          │  ~/.opencode/skills/...      │
                          │  ~/.antigravity/plugins/...  │
                          │  ~/.mimocode/plugins/...     │
                          └──────────────┬──────────────┘
                                         │
                          ┌──────────────▼──────────────┐
                          │  Target project (your code)  │
                          │  .foundry/                   │
                          │   ├─ state.md                │
                          │   ├─ board.md (or GitHub)    │
                          │   ├─ issues/                 │
                          │   └─ (per-phase artefacts)   │
                          └─────────────────────────────┘
```

---

## 1. Repo structure (canonical)

```
foundry-pipeline/
├── VERSION                # single source of truth (e.g., "2.0.0")
├── package.json           # npm workspaces manifest
├── README.md
├── CHANGELOG.md
├── LICENSE                # MIT
│
├── packages/
│   ├── core/              # portable: consumed by every harness package
│   │   ├── skills/        # 14 portable Agent Skills (open standard)
│   │   ├── agents/        # 9 sub-agent role prompts
│   │   ├── tracker-adapters/  # local | github | linear
│   │   ├── templates/     # state.md, board.md, prd.md, tdd.md, …
│   │   ├── evals/         # pass^k scenarios (portable)
│   │   ├── scripts/       # foundry-init, foundry-state, foundry-test-runner, …
│   │   └── lib/           # version helpers, sha helpers
│   │
│   ├── claude-code/       # Claude Code marketplace plugin
│   ├── zcode/             # Zcode plugin wrapper
│   ├── skills-sh/         # skills.sh install (skills-only)
│   ├── hermes/            # ~/.hermes/skills symlinks
│   ├── opencode/          # ~/.opencode/skills symlinks
│   ├── antigravity/       # Antigravity plugin dir
│   └── mimocode/          # MimoCode plugin dir
│
├── scripts/               # monorepo-level: build, version-sync, changelog, self-test
├── .github/workflows/     # CI: foundry-self-test, foundry-publish
├── docs/                  # USER_GUIDE, ARCHITECTURE, INSTALL, MIGRATION, …
└── evals/                 # monorepo-level pass^k evals
```

---

## 2. Versioning (single source of truth)

- **`VERSION`** (root) is the only file that holds the version.
- `scripts/foundry-version-sync.sh` reads it and writes into every `packages/*/package.json` and `packages/*/.claude-plugin/{plugin,marketplace}.json`.
- Every `SKILL.md`, script header, and agent frontmatter is stamped with `foundry_version: <VERSION>` at build time.
- `scripts/foundry-version-check.sh` is a CI guard — PRs that drift fail.
- `foundry-publish.yml` triggers on tag `v*`, syncs version, builds, creates a GitHub release.

---

## 3. Tracker abstraction

- **Interface**: `tracker_init`, `tracker_create_issue`, `tracker_update_status`, `tracker_add_comment`, `tracker_get_issue`, `tracker_list_issues`, `tracker_link_dep`.
- **Adapters** in `packages/core/tracker-adapters/{local,github,linear}/adapter.sh`.
- **State declaration** in `state.md` frontmatter:
  ```yaml
  tracker:
    backend: local | github | linear
    repo: owner/name
    team_id: ...
  ```
- **First-run wizard**: `/foundry:init` picks the backend and validates by creating + deleting a test issue.

---

## 4. Patch detection

- `packages/core/scripts/foundry-self-update.sh` (git-aware + file-checksum modes).
- Runs on `SessionStart` (in every harness with hook support), before phase transitions, and on manual `/foundry:patch-check`.
- Emits `additionalContext` JSON when local diverges; user runs `/foundry:patch-{diff,push,reset,skip}`.

---

## 5. Per-harness packages — install surface

| Harness | Install path |
|---|---|
| Claude Code | `~/.claude/plugins/cache/foundry-pipeline/<version>/` (via marketplace) |
| Zcode | `~/.zcode/cli/plugins/cache/foundry-pipeline/<version>/` |
| Hermes | `~/.hermes/skills/foundry-<skill-name>/` (symlinks) |
| OpenCode | `~/.opencode/skills/foundry-<skill-name>/` (symlinks) |
| Antigravity | `~/.antigravity/plugins/foundry-pipeline/<version>/` |
| MimoCode | `~/.mimocode/plugins/foundry-pipeline/<version>/` |
| skills.sh | `npx skills add caudellhenry/foundry-pipeline` |

Every package exposes a `bash install.sh` for ad-hoc installation. See `docs/INSTALL.md` for the full matrix.

---

## 6. Pipeline state machine

```
idea → research → prototype → prd → tdd → plan → execute → qa → complete
                              │                  ▲         │
                              └─────── loops ────┴────┐    │
                                                     │    │
                              gate failure → writer fixes  │
                              high findings → re-plan ────┘
```

8-gate convergence machine in `packages/core/scripts/foundry-check-convergence.sh`:
1. Board empty
2. Review empty (every ticket human-approved)
3. No high findings
4. No medium findings
5. Tests pass
6. Coverage gate (>= threshold AND >= baseline - 2%)
7. Lint + typecheck clean
8. User signoff

---

## 7. Sub-agent matrix

| Role | Profile | Model | Spawner | Output |
|---|---|---|---|---|
| Writer (per ticket) | `general-purpose` | sonnet | `foundry-spawn-writer.sh` | `.foundry/tdd/<T>.md` |
| Reviewer (per ticket) | `Explore` | lite | `foundry-spawn-reviewer.sh` | `.foundry/qa/review/<T>.md` |
| Cross-reviewer (per round) | `Explore` | lite | `foundry-spawn-cross-reviewer.sh` | `.foundry/qa/review/CROSS-round-<N>.md` |
| QA planner (per round) | `general-purpose` | sonnet | `foundry-spawn-qa-planner.sh` | `.foundry/qa/qa-plan.md` |

---

## 8. Why monorepo, not two repos

| Concern | Two-repo (old) | Monorepo (this) |
|---|---|---|
| Version drift | Yes (v0.1.0 vs v1.3.0) | Impossible (single VERSION file + CI guard) |
| Cross-harness release | Manual sync | `bash scripts/foundry-monorepo-build.sh` |
| Publish to skills.sh | Manual | Automated via `foundry-publish.yml` |
| Edit a skill → 7 harness packages | 7 PRs | 1 PR |
| Patch-push workflow | n/a | Built in (`/foundry:patch-push`) |
| Eval suite | Zcode only | Monorepo-level + per-package |

---

## 9. See also

- [`docs/USER_GUIDE.md`](USER_GUIDE.md) — workflow walkthrough
- [`docs/INSTALL.md`](INSTALL.md) — per-harness install
- [`docs/TRACKER_GUIDE.md`](TRACKER_GUIDE.md) — local / GitHub / Linear setup
- [`docs/PATCH_PUSH_WORKFLOW.md`](PATCH_PUSH_WORKFLOW.md) — pushing local edits to canonical
- [`docs/MIGRATION.md`](MIGRATION.md) — from v0.1.0 / v1.3.0 → v2.0.0
- [`docs/ROLLOUT.md`](ROLLOUT.md) — phased delivery checklist