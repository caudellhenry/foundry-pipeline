---
description: "/foundry-test-config — View or edit the test config in state.md (test.cmd, coverage_cmd, coverage_threshold, lint_cmd, typecheck_cmd, etc.). v1.2.0."
argument-hint: "[<key> <value> | --auto-detect]"
allowed-tools: ["Bash(${CLAUDE_PLUGIN_ROOT}/scripts/foundry-state.sh:*)", "Bash(${CLAUDE_PLUGIN_ROOT}/scripts/foundry-auto-detect-test.sh:*)"]
---

# /foundry-test-config — View / edit test config (v1.2.0)

The `test:` block in `.foundry/state.md` controls what `verify_execute` actually runs. Auto-populated by `foundry-auto-detect-test.sh` on first bootstrap, but you can override.

## View current config

```bash
bash scripts/foundry-test-config.sh
```

Or read it directly:

```bash
grep -A 20 '^test:' .foundry/state.md
```

## Re-run auto-detection

```bash
bash scripts/foundry-auto-detect-test.sh --apply
```

This re-inspects `package.json` / `pyproject.toml` / `go.mod` / `Cargo.toml` and writes the proposed `test:` block back to `state.md`.

## Edit a single key

```bash
# Set a test runner
bash scripts/foundry-state.sh set-test-config runner vitest

# Set the test command
bash scripts/foundry-state.sh set-test-config cmd "npx vitest run"

# Set per-story filter template (use {path} placeholder)
bash scripts/foundry-state.sh set-test-config per_story_cmd_template "npx vitest run {path}"

# Set coverage command + threshold + baseline
bash scripts/foundry-state.sh set-test-config coverage_cmd "npx vitest run --coverage"
bash scripts/foundry-state.sh set-test-config coverage_threshold 80
bash scripts/foundry-state.sh set-coverage-baseline    # read latest from a test run

# Set lint + typecheck
bash scripts/foundry-state.sh set-test-config lint_cmd "npx eslint ."
bash scripts/foundry-state.sh set-test-config typecheck_cmd "npx tsc --noEmit"

# Set timeout (seconds)
bash scripts/foundry-state.sh set-test-config timeout 600

# Explicit opt-out (no test suite yet)
bash scripts/foundry-state.sh set-test-config skip_tests true
```

## Models

```bash
bash scripts/foundry-state.sh set-models writer sonnet
bash scripts/foundry-state.sh set-models reviewer lite
bash scripts/foundry-state.sh set-models cross_reviewer lite
bash scripts/foundry-state.sh set-models qa_planner sonnet
```

## Verify the config

After editing, run a single-ticket verify to confirm everything wires up:

```bash
bash scripts/verify.sh execute STORY-001
```

If the runner JSON shows `"verdict": "PASS"`, you're good. If it shows `"verdict": "FAIL"`, the `reason` field tells you which gate failed.