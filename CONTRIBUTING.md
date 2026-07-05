# Contributing to foundry-pipeline

> Single source of truth: `caudellhenry/foundry-pipeline`.

Thanks for helping make the foundry AI-engineering pipeline better. This document covers everything you need to send a PR.

---

## TL;DR

1. **Fork** [caudellhenry/foundry-pipeline](https://github.com/caudellhenry/foundry-pipeline).
2. **Branch** off `main`: `git checkout -b feat/<short-desc>`.
3. **Make your change.** Follow the conventions below.
4. **Run the local checks:**
   ```bash
   bash scripts/foundry-self-test.sh          # shell + JSON syntax + VERSION sanity
   bash scripts/foundry-version-sync.sh       # sync version into every package
   bash scripts/foundry-version-check.sh      # verify in sync
   bash scripts/foundry-monorepo-build.sh     # build every package
   bash evals/run.sh --release-check          # pass^k CI gate
   ```
5. **Commit** with [Conventional Commits](https://www.conventionalcommits.org/) (`feat:`, `fix:`, `chore:`, `docs:`, `refactor:`).
6. **Push** and open a PR against `main`.

---

## Repo structure

```
foundry-pipeline/
├── VERSION                  # single source of truth (= "2.0.0")
├── package.json             # npm workspaces
├── packages/
│   ├── core/                # portable: skills, agents, scripts, tracker-adapters, templates, evals
│   ├── claude-code/         # commands/ + hooks/
│   ├── zcode/               # commands/ + hooks/
│   ├── skills-sh/           # skills-only (skills.sh)
│   ├── hermes/              # ~/.hermes/skills symlinks
│   ├── opencode/            # ~/.opencode/skills symlinks
│   ├── antigravity/         # ~/.antigravity/plugins/
│   └── mimocode/            # ~/.mimocode/plugins/
├── scripts/                 # monorepo build, version-sync, changelog, self-test
├── evals/                   # monorepo-level pass^k eval scenarios
├── .github/workflows/       # CI: foundry-self-test, foundry-publish
└── docs/                    # USER_GUIDE, ARCHITECTURE, INSTALL, MIGRATION, …
```

---

## Versioning

**`VERSION` (root) is the single source of truth.** Every `package.json` + `.claude-plugin/*.json` is auto-synced from it.

To bump the version:
```bash
# Edit VERSION (e.g., 2.0.0 → 2.0.1)
echo "2.0.1" > VERSION

# Sync into every package
bash scripts/foundry-version-sync.sh

# Verify
bash scripts/foundry-version-check.sh

# Commit + tag
git add -A
git commit -m "chore(release): bump to v2.0.1"
git tag -a v2.0.1 -m "v2.0.1"
git push origin main v2.0.1
```

`foundry-publish.yml` runs on tag push — creates GitHub release + publishes to skills.sh.

---

## Commit conventions

[Conventional Commits](https://www.conventionalcommits.org/) is enforced by `foundry-changelog.sh`:

| Prefix | Changelog group |
|---|---|
| `feat:` | Added |
| `fix:` | Fixed |
| `perf:` | Performance |
| `refactor:` / `style:` | Changed |
| `docs:` | Docs |
| `build:` | Build |
| `ci:` | CI |
| `test:` | Tests |
| `chore:` | Chore |

Examples:
```
feat: add /foundry:init wizard with tracker picker
fix: local tracker ignores labels containing commas
docs: update USER_GUIDE with end-to-end example
chore(release): bump to v2.0.1
```

---

## Adding a new skill

1. Create `packages/core/skills/<name>/SKILL.md`:
   ```yaml
   ---
   name: <name>
   description: <one-line summary, max 200 chars>
   foundry_version: 2.0.0
   ---

   # <Name>

   <Body — what it does, when to use, behaviour, exit codes>
   ```
2. (Optional) Add a sidecar format doc: `packages/core/skills/<name>/<NAME>-FORMAT.md`.
3. Run `bash scripts/foundry-version-sync.sh` to stamp `foundry_version:`.
4. Add an eval scenario: `packages/core/evals/scenarios/<NN>-<name>-syntax.yaml`.
5. Run `bash scripts/foundry-self-test.sh` + `bash evals/run.sh --scenario <NN>`.

The skill auto-appears in every harness via the monorepo build.

---

## Adding a new slash command

1. Create `packages/claude-code/commands/foundry-<name>.md` and `packages/zcode/commands/foundry-<name>.md` (both — mirror). `commands/sdlc-<name>.md` deprecated aliases are NOT needed (the monorepo is canonical).
2. Frontmatter:
   ```yaml
   ---
   description: <one-line>
   argument-hint: "<args>"
   hide-from-slash-command-tool: "false"
   foundry_version: 2.0.0
   ---
   ```
3. Body: behaviour, exit codes.
4. Optional: implement the actual logic in `packages/core/scripts/foundry-<name>.sh` and reference it from the slash command.

---

## Adding a new tracker adapter

1. Create `packages/core/tracker-adapters/<backend>/adapter.sh`.
2. Source `../interface.sh` (which defines the 7-function API).
3. Implement the 7 functions:
   - `tracker_<backend>_init`
   - `tracker_<backend>_create_issue`
   - `tracker_<backend>_update_status`
   - `tracker_<backend>_add_comment`
   - `tracker_<backend>_get_issue`
   - `tracker_<backend>_list_issues`
   - `tracker_<backend>_link_dep`
4. Add to `tracker_dispatch()` in `interface.sh`:
   ```bash
   case "$TRACKER_ADAPTER" in
     ...
     <backend>) "tracker_<backend>_${fn#tracker_}" "$@" ;;
     ...
   esac
   ```
5. Add to `state.md` template's `tracker:` block documentation.
6. Add eval scenarios in `packages/core/evals/scenarios/`.

---

## Adding a new harness package

1. Create `packages/<harness>/` with:
   - `package.json` (mirror from existing packages; bump `foundry_harness`)
   - `.claude-plugin/plugin.json` (if Claude-Code-compatible)
   - `install.sh` (mirror from existing)
2. Add to root `package.json` `workspaces` array.
3. Add to `scripts/foundry-monorepo-build.sh` (decide: full-copy or symlink).
4. Add install line to `docs/INSTALL.md`.
5. Add eval scenario.

---

## CI

Three workflows run on every PR:
- `foundry-self-test.yml` — shell + JSON syntax + VERSION sanity
- `foundry-version-sync.yml` — every package version matches `VERSION`
- `foundry-monorepo-build.yml` — dry-run build

`foundry-publish.yml` runs on tag push — creates GitHub release + publishes.

---

## Code of conduct

Be kind. Be patient. Assume good faith. We're all here to ship better software.

---

## License

By contributing, you agree your contributions are licensed under the project's MIT license (see [`LICENSE`](LICENSE)).