# foundry-pipeline

> **One canonical source of truth for the foundry AI-engineering pipeline — idea → working MVP.**
> Installable identically across Claude Code, Zcode, Hermes, OpenCode, Antigravity, MimoCode, and skills.sh.

**Current version:** `2.0.0` (single source of truth: [`VERSION`](VERSION))

---

## What is foundry?

Foundry is a seven-phase AI-engineering pipeline that takes a fuzzy idea and produces a working MVP, with executable checks, human gates, and tracker-flexible ticket management:

```
Idea → Research → Prototype → PRD → Plan/Kanban → Execution loop (Ralph) → QA
                          ▲                                       │
                          └───────── loops 5/6/7 ─────────────────┘
```

The same workflow runs on **your** machine, on **your** harness, with **your** choice of tracker (local markdown, GitHub Issues, or Linear).

---

## Install (per harness)

| Harness | Install |
|---|---|
| **Claude Code** | `/plugin marketplace add caudellhenry/foundry-pipeline` (after the marketplace is published) |
| **Zcode** | `bash packages/zcode/install.sh` |
| **Hermes** | `bash packages/hermes/install.sh` |
| **OpenCode** | `bash packages/opencode/install.sh` |
| **Antigravity** | `bash packages/antigravity/install.sh` |
| **MimoCode** | `bash packages/mimocode/install.sh` |
| **skills.sh (skills only, no hooks/commands)** | `npx skills add caudellhenry/foundry-pipeline` |

After install, invoke the pipeline with **`/foundry:ship "<your intent>"`** or one of the phase commands (`/foundry:grill`, `/foundry:prd`, `/foundry:implement`, `/foundry:qa`, …). See [`docs/INSTALL.md`](docs/INSTALL.md) for the full matrix.

---

## Why this monorepo exists

Before v2.0.0, foundry existed as two separate repos with drift:

- `caudellhenry/foundry` (v0.1.0) — portable, public, MCP-first, frozen.
- `Skills/foundry` (v1.3.0, workspace-local) — sophisticated, state-machine, local-first, never published.

Both are now superseded. **`caudellhenry/foundry-pipeline` is the single canonical source of truth from v2.0.0 onward.** See [`docs/MIGRATION.md`](docs/MIGRATION.md) for the migration path.

---

## Features

- **Single VERSION file** drives every package's manifest. CI fails on drift.
- **Tracker adapter pattern**: local markdown / GitHub Issues / Linear — pick at install time.
- **Git-aware patch detection**: if you edit installed files locally, the plugin prompts you to push the patch upstream (`/foundry:patch-push`).
- **Multi-harness install**: same skills ship to Claude Code, Zcode, Hermes, OpenCode, Antigravity, MimoCode, skills.sh.
- **8-gate convergence**: machine-checkable QA (board empty, no findings, tests pass, coverage gate, lint/typecheck clean, user signoff).
- **Real test runner**: auto-detects from `package.json` / `pyproject.toml` / `go.mod` / `Cargo.toml`.
- **Pass^k eval suite** + CI workflow that runs on every PR.
- **Per-ticket worktree isolation** (FR-008) + opt-in parallel fan-out (FR-009).
- **Fresh-context sub-agents** per ticket and per QA round (writer / reviewer / cross-reviewer / qa-planner).

---

## Repo layout

```
foundry-pipeline/
├── VERSION                  # single source of truth
├── package.json             # npm workspaces manifest
├── README.md
├── CHANGELOG.md
├── LICENSE
│
├── packages/
│   ├── core/                # portable: skills, agents, scripts, tracker-adapters, templates, evals
│   ├── claude-code/         # Claude Code marketplace plugin
│   ├── zcode/               # Zcode plugin wrapper
│   ├── skills-sh/           # skills.sh wrapper
│   ├── hermes/              # ~/.hermes/skills symlinks
│   ├── opencode/            # ~/.opencode/skills symlinks
│   ├── antigravity/         # Antigravity plugin dir wrapper
│   └── mimocode/            # MimoCode plugin dir wrapper
│
├── scripts/                 # monorepo build, version sync, changelog
├── .github/workflows/       # CI: evals, version-sync, build, publish
├── docs/                    # USER_GUIDE, ARCHITECTURE, INSTALL, MIGRATION, …
└── evals/                   # monorepo-level cross-package evals
```

See [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) for full diagrams.

---

## Contributing

Conventional Commits (`feat:`, `fix:`, `chore:`, `docs:`). PRs that drift from `VERSION` fail CI. Every PR runs `foundry-evals` + `foundry-monorepo-build`. Releases are cut by tagging `v*` — `foundry-publish.yml` does the rest.

---

## License

MIT — see [`LICENSE`](LICENSE).