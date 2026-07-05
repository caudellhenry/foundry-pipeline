---
description: Manage the project's GitHub deploy workflow (init / status / verify). Owns .github/workflows/deploy.yml. Detects target (firebase | vercel | netlify | custom), writes the right steps, surfaces required secrets. Called by the dev-QA loop's PR sub-loop to gate ticket completion on a green deploy.
argument-hint: "<init|status|verify> [args]"
hide-from-slash-command-tool: "false"
foundry_version: 2.1.0
---

# `/foundry-deploy` — manage the project's GitHub deploy workflow

In foundry v2.1.0+, this command takes ownership of `.github/workflows/deploy.yml` from the `github-discipline` skill. The two coexist; foundry wins when both are present.

## Subcommands

### `init [TARGET]`

Detect (or accept) the deploy target, write `.github/workflows/deploy.yml` from `packages/core/templates/deploy.yml`, set the `deploy:` block in `.foundry/state.md`, and print the required secrets/variables the user must configure in GitHub repo settings.

| Target | Detection | Deploy steps |
|---|---|---|
| `firebase` | `firebase.json` present | `FirebaseExtended/action-hosting-deploy@v0` with `FIREBASE_SERVICE_ACCOUNT` |
| `vercel` | `vercel.json` or `"vercel"` in `package.json` | `npx vercel --prod` with `VERCEL_TOKEN` |
| `netlify` | `netlify.toml` present | `npx netlify deploy --prod` with `NETLIFY_AUTH_TOKEN` + `NETLIFY_SITE_ID` |
| `custom` | `Dockerfile` / `docker-compose.yml` / nothing detected | Placeholder; user replaces the deploy step manually |

If no `TARGET` arg, foundry auto-detects from the project files.

`init` is idempotent and non-destructive: existing steps outside the `# === FOUNDRY_DEPLOY_STEPS_* ===` markers in `deploy.yml` are preserved on re-runs.

### `status [PR_URL]`

Without a `PR_URL`: print the latest deploy run for the repo (uses `gh run list --workflow=deploy.yml --limit=1`).

With a `PR_URL`: print all checks on that PR (uses `gh pr checks <url>`).

### `verify <PR_URL>`

Exit-code-only gate, called by the orchestrator's PR sub-loop:

- `exit 0` — deploy succeeded (all checks green)
- `exit 1` — deploy failed or no deploy check found for the PR
- `exit 2` — no deploy target configured (SKIP — the orchestrator treats 2 as "not applicable")

### `help`

Show usage.

## Examples

```bash
/foundry-deploy init                 # auto-detect target, write workflow, print secrets
/foundry-deploy init firebase        # force Firebase target
/foundry-deploy status               # show latest deploy run
/foundry-deploy status https://github.com/me/repo/pull/42   # PR's checks
/foundry-deploy verify https://github.com/me/repo/pull/42   # exit 0/1/2 for the orchestrator
```

## Configuration: `.foundry/state.md`

`init` writes:

```yaml
deploy:
  target: firebase
  initialized_at: "2026-07-05T17:00:00Z"
```

Other parts of foundry read this to know whether deploy gating applies.

## Coordination with github-discipline

If a project has BOTH foundry and the `github-discipline` skill installed:
- foundry takes ownership of `deploy.yml` (Phase 1.3 of github-discipline defers when foundry is present)
- foundry owns the `deploy:` block in state.md
- foundry is the canonical source for deploy-related state

If only `github-discipline` is installed (no foundry):
- `github-discipline` Phase 1.3 manages deploy.yml standalone
- No `deploy:` block in state.md (foundry's `verify` exits 2 / SKIP)

## When to invoke

- Once per project, after first clone: `/foundry-deploy init` (auto-detects target).
- After switching deploy targets (e.g., migrating Firebase → Vercel): `/foundry-deploy init <new-target>`.
- To check deploy health before merging a PR: `/foundry-deploy verify <PR_URL>`.
- The orchestrator's PR sub-loop calls `verify` automatically when a ticket's `exit_criterion` is `pr-green`.

## Required GitHub secrets/variables per target

| Target | Secrets | Variables |
|---|---|---|
| firebase | `GITHUB_TOKEN`, `FIREBASE_SERVICE_ACCOUNT` | `FOUNDRY_FIREBASE_PROJECT_ID` |
| vercel | `GITHUB_TOKEN`, `VERCEL_TOKEN` | — |
| netlify | `GITHUB_TOKEN`, `NETLIFY_AUTH_TOKEN`, `NETLIFY_SITE_ID` | — |
| custom | (your own) | — |

**Important:** foundry does NOT write these secrets to GitHub — that requires admin access and is a security boundary. The user must set them manually via Settings → Secrets and variables → Actions.

## See also

- `packages/core/scripts/foundry-deploy.sh` — implementation
- `packages/core/templates/deploy.yml` — template
- `Knowledge Base/architecture/github-deploy-workflow.md` — full architecture doc (when written)
- `~/.agents/skills/github-discipline/SKILL.md` — the skill this command supersedes for foundry-managed projects