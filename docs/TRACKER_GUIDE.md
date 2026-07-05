# Tracker Guide — local / GitHub / Linear (v2.0.0)

> Single source of truth: `caudellhenry/foundry-pipeline`. This doc covers the three tracker backends the pipeline supports.

---

## Overview

The pipeline tracks tickets (user stories, enabler issues) through a **tracker adapter**. Three backends are supported:

| Backend | Storage | When to use |
|---|---|---|
| **`local`** | `.foundry/board.md` + `.foundry/issues/*.md` | Solo work, offline, no external setup |
| **`github`** | GitHub Issues (via MCP) | You already use GitHub Issues; team lives on GitHub |
| **`linear`** | Linear (via MCP) | You use Linear; team prefers Linear's UX |

Switch backends any time by editing `state.md` and re-running `/foundry:init`.

---

## Local (default)

No setup. Tickets live in your project repo as markdown files.

```
.foundry/
├── state.md      # pipeline state + tracker block
├── board.md      # kanban (Backlog / Ready / In progress / Review / Done / Blocked)
└── issues/
    ├── STORY-001-add-stripe-subscriptions.md
    ├── STORY-002-onboarding-flow.md
    └── ENABLER-003-postgres-migration.md
```

`.foundry/` should be `.gitignore`d in the target project (each issue's content is in your issue tracker / commit messages, not in the repo history).

### When to choose local

- Solo dev / side projects
- No team / no external coordination
- Want zero dependencies
- Working offline

---

## GitHub Issues

Tickets live as GitHub Issues on `<owner>/<repo>`. Requires the GitHub MCP server configured in `.mcp.json` (see below).

### Setup

1. **Configure `.mcp.json`** in your project root:
   ```json
   {
     "mcpServers": {
       "github": {
         "type": "http",
         "url": "https://api.githubcopilot.com/mcp/"
       }
     }
   }
   ```

2. **Run `/foundry:init`** and pick `github`:
   ```
   ? Where should tickets live? GitHub Issues
   ? Which repo? owner/name
   ? Create a test issue to validate? (y/N) y
   ```

3. **Verify** — the wizard creates and deletes a test issue, then writes:
   ```yaml
   # .foundry/state.md frontmatter
   tracker:
     backend: github
     repo: owner/name
     mcp_required: true
   ```

### Ticket labels

Foundry writes these labels (create them in GitHub if missing):

- `foundry:story` — user story
- `foundry:enabler` — enabler / chore
- `foundry:phase-1` … `foundry:phase-7` — phase tag
- `foundry:blocked` — blocked status

### When to choose GitHub

- Team already on GitHub
- PRs + issues live in the same place
- Want traceability between code and tickets

---

## Linear

Tickets live as Linear issues in a team. Requires the Linear MCP server.

### Setup

1. **Configure `.mcp.json`**:
   ```json
   {
     "mcpServers": {
       "linear": {
         "type": "sse",
         "url": "https://mcp.linear.app/sse"
       }
     }
   }
   ```

2. **Run `/foundry:init`** and pick `linear`:
   ```
   ? Where should tickets live? Linear
   ? Which team? Engineering
   ? Which project (optional)? MVP-2026
   ```

3. **Verify** — wizard creates + deletes a test issue.

### Status mapping

| Foundry status | Linear state |
|---|---|
| `ready` | Todo |
| `in_progress` | In Progress |
| `review` | In Review |
| `done` | Done |
| `blocked` | Blocked |

### When to choose Linear

- Team prefers Linear's UX (cycles, projects, roadmaps)
- Already pay for Linear
- Want rich filtering / saved views

---

## Switching backends

To switch from local to GitHub (or any other combination):

1. Edit `.foundry/state.md` frontmatter `tracker:` block
2. Re-run `/foundry:init` to validate the new adapter
3. Optionally export existing local tickets:
   ```bash
   bash ~/.claude/plugins/cache/foundry-pipeline/2.0.0/scripts/foundry-tracker-migrate.sh \
     --from local --to github
   ```

---

## MCP availability check

The adapter detects MCP availability at runtime. If `tracker.backend: github` but no `github` MCP server is configured, the adapter:

1. Logs a warning: `tracker: github requested but GitHub MCP not found in .mcp.json — falling back to REST API`
2. Falls back to GitHub REST API (requires `GITHUB_TOKEN` env var)
3. If `GITHUB_TOKEN` is also absent, falls back to `tracker: local` and emits an error message

Same fallback chain for Linear (`LINEAR_API_KEY` env var).

---

## See also

- [`docs/ARCHITECTURE.md`](ARCHITECTURE.md) — adapter interface
- [`docs/INSTALL.md`](INSTALL.md) — installing on each harness
- [`docs/MIGRATION.md`](MIGRATION.md) — switching tracker during migration