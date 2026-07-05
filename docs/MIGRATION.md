# Migration — from v0.1.0 / v1.3.0 → v2.0.0

> Single source of truth: `caudellhenry/foundry-pipeline`. This doc covers migrating from the two predecessor repos.

---

## TL;DR

| From | To | Action |
|---|---|---|
| `caudellhenry/foundry` (v0.1.0, public) | `caudellhenry/foundry-pipeline` (v2.0.0) | Run `foundry-migrate.sh` (auto-detects old install); manual: re-install + re-`/foundry:init` |
| `Skills/foundry` (v1.3.0, workspace-local Zcode) | `caudellhenry/foundry-pipeline` (v2.0.0) | Same; old dir moves to `_archive/` |

The old repos are **archived** at v2.0.0 cutoff; they will not receive further updates. Bug fixes and improvements land in the new repo only.

---

## Automatic migration (recommended)

The new monorepo ships `packages/core/scripts/foundry-migrate.sh`:

```bash
# Detects any old foundry install and offers to:
#   - Copy state.md / board.md into the new location
#   - Re-create issues in your new tracker (if switching backends)
#   - Print the new slash-command surface
bash <new-install>/packages/core/scripts/foundry-migrate.sh
```

It's also invoked automatically on first `/foundry:ship` if `~/.foundry/legacy-marker.txt` is detected.

---

## Manual migration

### From `caudellhenry/foundry` (v0.1.0)

```bash
# 1. Back up existing state
cp -r ~/.foundry ~/.foundry.bak.v0.1.0

# 2. Install v2.0.0 (any harness — see docs/INSTALL.md)

# 3. Copy artefacts forward
cp ~/.foundry.bak.v0.1.0/state.md   ~/.foundry/state.md          # local-tracker only
cp ~/.foundry.bak.v0.1.0/board.md   ~/.foundry/board.md          # local-tracker only
cp -r ~/.foundry.bak.v0.1.0/issues  ~/.foundry/issues            # local-tracker only

# 4. Edit ~/.foundry/state.md frontmatter to add the new tracker block (if you used GitHub/Linear in v0.1.0)
# See docs/TRACKER_GUIDE.md

# 5. Run /foundry:status to verify
```

### From `Skills/foundry` (v1.3.0, Zcode)

```bash
# 1. Archive the old workspace-local copy
mv "/Users/henrycaudell/Agents Workspace/Skills/foundry" \
   "/Users/henrycaudell/Agents Workspace/_archive/Skills-foundry-v1.3.0/"

# 2. Install v2.0.0 (Zcode package — see docs/INSTALL.md)

# 3. Migrate artefacts (same as v0.1.0 above)
cp -r ~/.foundry ~/.foundry.bak.v1.3.0
# ... edit state.md frontmatter ...

# 4. Run /foundry:status
```

---

## Breaking changes

### v0.1.0 → v2.0.0

| v0.1.0 | v2.0.0 | Notes |
|---|---|---|
| `state.json` | `state.md` (frontmatter + prose) | Unified format; migration copies forward |
| `foundry:grill` | `/foundry:grill` | Slash-command syntax change (also accepts `:grill` and `-grill`) |
| 14 skills, MCP-first | 14 skills + tracker-adapter abstraction | New `tracker:` block in state.md |
| No patch detection | Git-aware + checksum patch detection | New `/foundry:patch-*` commands |
| No version stamping | Every SKILL.md has `foundry_version:` | CI guard against drift |
| Single repo, public | Monorepo, 8 packages | One VERSION file drives all |

### v1.3.0 → v2.0.0

| v1.3.0 | v2.0.0 | Notes |
|---|---|---|
| `foundry-idea` (skill name) | `foundry:grill` (slash command) | New portable naming |
| 20 foundry-* + 20 sdlc-* commands | 27 foundry:* commands (no sdlc-* aliases) | Aliases dropped; not needed in monorepo |
| Local-only tracker | local / GitHub / Linear | New abstraction |
| No patch detection | `/foundry:patch-{check,diff,push,reset,skip}` | New |
| workspace-local | GitHub-canonical + install per harness | New |
| `foundry-self-improve` | `/foundry:self-improve` | Same, slash-command form |

---

## Version drift checklist

If you have any old foundry references anywhere (dotfiles, scripts, agent configs), search + replace:

```bash
# Old → new
"foundry:idea"          →  "/foundry:grill"
"foundry:prototype"      →  "/foundry:prototype"
"foundry:prd"            →  "/foundry:prd"
"foundry:research"       →  "/foundry:research"
"foundry:ship"           →  "/foundry:ship"
"foundry:board"          →  "/foundry:board"
"foundry:implement"      →  "/foundry:implement"
"foundry:review"         →  "/foundry:review"
"foundry:qa"             →  "/foundry:qa"
"caudellhenry/foundry"   →  "caudellhenry/foundry-pipeline"   # repo URL
"v0.1.0" / "v1.3.0"     →  "v2.0.0"                            # if referencing the version
```

The new monorepo's slash commands are uniformly namespaced under `/foundry:` (Claude Code / Antigravity / MimoCode style) and `/foundry-` (Hermes / OpenCode style).

---

## See also

- [`docs/ARCHITECTURE.md`](ARCHITECTURE.md)
- [`docs/INSTALL.md`](INSTALL.md)
- [`docs/TRACKER_GUIDE.md`](TRACKER_GUIDE.md)