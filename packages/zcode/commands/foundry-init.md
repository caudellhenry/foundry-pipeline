---
description: First-run wizard — pick tracker (local / GitHub / Linear), validate, write state.md frontmatter
argument-hint: "[--tracker=local|github|linear] [--auto-detect-tests]"
hide-from-slash-command-tool: "false"
foundry_version: 2.0.0
---

# `/foundry:init`

First-run wizard for the foundry pipeline.

## Behaviour

1. **Tracker picker** — interactive prompt (or `--tracker=local|github|linear`):
   - **local** (default) — `.foundry/board.md` + `.foundry/issues/*.md`
   - **github** — GitHub Issues via MCP / REST API
   - **linear** — Linear via MCP / REST API

2. **Credentials** — for github/linear, prompts for repo/team and validates by creating + deleting a test issue.

3. **Test runner auto-detect** — `--auto-detect-tests` runs `scripts/foundry-auto-detect-test.sh` and writes the `test:` block in `state.md`.

4. **State write** — writes `state.md` frontmatter:
   ```yaml
   pipeline: foundry
   current_phase: idea
   foundry_version: 2.0.0
   tracker:
     backend: local | github | linear
     repo: owner/name       # if github
     team_id: ...           # if linear
   test:
     cmd: ...
     coverage_cmd: ...
     lint_cmd: ...
     typecheck_cmd: ...
     coverage_threshold: ...
   signoff:
     user_signed_off: false
   ```

5. **.mcp.json** — if github or linear, appends the appropriate MCP server entry.

## Files written

- `.foundry/state.md`
- `.foundry/board.md` (if local)
- `.foundry/issues/.gitkeep` (if local)
- `.mcp.json` (if github or linear)

## Exit codes

- 0 — success
- 1 — user cancelled
- 2 — validation failed (e.g., test issue couldn't be created)