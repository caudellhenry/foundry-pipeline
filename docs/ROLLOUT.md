# Rollout — phased delivery checklist (v2.0.0)

> Single source of truth: `caudellhenry/foundry-pipeline`. This doc tracks delivery phases for the v2.0.0 monorepo rebuild.

---

## Phase A — Repo skeleton ✅ (current)

- [x] Create `caudellhenry/foundry-pipeline` (local repo)
- [x] `VERSION = 2.0.0`
- [x] Root files: `package.json` (workspaces), `.gitignore`, `LICENSE`, `README.md`, `CHANGELOG.md`
- [x] All 8 package skeletons under `packages/`
- [x] Root scripts: `foundry-{version-sync,version-check,monorepo-build,changelog,self-test}.sh`
- [x] CI workflows: `foundry-self-test.yml`, `foundry-publish.yml`, `release-drafter.yml`
- [x] 8 monorepo-level eval scenarios + `evals/run.sh`
- [x] All 7 docs skeletons (`USER_GUIDE`, `ARCHITECTURE`, `INSTALL`, `MIGRATION`, `TRACKER_GUIDE`, `PATCH_PUSH_WORKFLOW`, `ROLLOUT`)
- [x] Initial commit + tag `v2.0.0-alpha.1`

---

## Phase B — Port core from Zcode plugin

- [ ] Copy `Skills/foundry/skills/` → `packages/core/skills/` (rename `foundry-*` → `<name>`)
- [ ] Copy `Skills/foundry/agents/` → `packages/core/agents/`
- [ ] Copy `Skills/foundry/templates/` → `packages/core/templates/`
- [ ] Copy `Skills/foundry/scripts/` → `packages/core/scripts/` (preserve v1.2.0 / v1.3.0 features)
- [ ] Port `Skills/foundry/hooks/` into `packages/claude-code/hooks/` and `packages/zcode/hooks/`
- [ ] Port `Skills/foundry/commands/` into `packages/claude-code/commands/` and `packages/zcode/commands/`
- [ ] Copy `Skills/foundry/evals/` → `packages/core/evals/`

---

## Phase C — Tracker abstraction

- [ ] Implement `packages/core/tracker-adapters/interface.sh`
- [ ] Implement `packages/core/tracker-adapters/local/adapter.sh`
- [ ] Implement `packages/core/tracker-adapters/github/adapter.sh` (wraps GitHub MCP, falls back to REST)
- [ ] Implement `packages/core/tracker-adapters/linear/adapter.sh` (wraps Linear MCP, falls back to REST)
- [ ] Update `templates/state.md` with `tracker:` block
- [ ] Update `packages/core/skills/foundry-board/SKILL.md` to dispatch to adapter
- [ ] Update `packages/core/skills/foundry-ship/SKILL.md` to call `tracker_init` first
- [ ] Add `/foundry:init` wizard (interactive + non-interactive flags)

---

## Phase D — Patch detection

- [ ] Implement `packages/core/scripts/foundry-self-update.sh` (git + checksum modes)
- [ ] Add SessionStart hook in `packages/claude-code/hooks/` to call it
- [ ] Add SessionStart hook in `packages/zcode/hooks/` to call it
- [ ] Add `/foundry:patch-{check,diff,push,reset,skip}` commands
- [ ] Implement `/foundry:patch-push` (interactive PR opener with fork detection)
- [ ] Add `.foundry-version-manifest.json` generator to `scripts/foundry-monorepo-build.sh`

---

## Phase E — Harness wrappers

- [ ] `packages/claude-code/install.sh` (marketplace publish + slash commands)
- [ ] `packages/zcode/install.sh` (symlink to Zcode plugin cache)
- [ ] `packages/skills-sh/install.sh` (skills-only publish via `npx skills add`)
- [ ] `packages/hermes/install.sh` (symlinks to `~/.hermes/skills/`)
- [ ] `packages/opencode/install.sh` (symlinks to `~/.opencode/skills/`)
- [ ] `packages/antigravity/install.sh` (plugin dir copy to `~/.antigravity/plugins/`)
- [ ] `packages/mimocode/install.sh` (plugin dir copy to `~/.mimocode/plugins/`)
- [ ] Update `packages/core/scripts/foundry-init.sh` to autodetect harness

---

## Phase F — Full documentation pass

- [ ] Write `docs/USER_GUIDE.md` (idea → MVP walkthrough with per-harness notes)
- [ ] Polish all existing docs with examples, screenshots, edge cases
- [ ] Add `CONTRIBUTING.md` (conventional commits, PR template, code of conduct)
- [ ] Add `SECURITY.md` (vulnerability reporting)

---

## Phase G — Archival & migration

- [ ] Archive `caudellhenry/foundry` (banner + `ARCHIVED.md` + tag `v0.1.0-frozen`)
- [ ] Move `/Users/henrycaudell/Agents Workspace/Skills/foundry` → `_archive/Skills-foundry-v1.3.0/`
- [ ] Add `packages/core/scripts/foundry-migrate.sh` (auto-detect old installs)
- [ ] Add `legacy-marker.txt` detection in `foundry-init.sh`

---

## Phase H — CI + release

- [ ] Wire all 4 CI workflows (already done in Phase A — verify)
- [ ] Tag `v2.0.0` (post-Phase G)
- [ ] First canonical GitHub release
- [ ] Publish `packages/skills-sh/` to skills.sh
- [ ] Update `caudellhenry/foundry` README to point at the new repo
- [ ] Announce on whatever channels the user uses

---

## Phase I — Dogfooding (optional)

- [ ] Run `/foundry:ship` against a real MVP idea end-to-end
- [ ] Triage findings → v2.0.1
- [ ] Tag `v2.0.1`

---

## Status legend

- [ ] = pending
- [x] = done
- [~] = in progress
- [!] = blocked (waiting on external dependency / decision)