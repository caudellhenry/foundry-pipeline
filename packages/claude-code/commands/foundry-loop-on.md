---
description: "/foundry-loop-on — Enable auto-loop on Phases 6/7 (Dev/QA). The stop-hook will keep the loop running until convergence (8-gate check + user signoff). v1.2.0: validates test config before enabling."
argument-hint: ""
allowed-tools: ["Bash(${CLAUDE_PLUGIN_ROOT}/scripts/foundry-state.sh:*)", "Bash(${CLAUDE_PLUGIN_ROOT}/scripts/foundry-auto-detect-test.sh:*)"]
---

# /foundry-loop-on — Enable auto-loop (with test config validation)

Sets `auto_loop: true` in `.foundry/state.md`. The stop-hook (`hooks/stop-hook.sh`) will keep the Ralph loop running until convergence (8-gate check + `/foundry-signoff`), or until `DEV_PIPELINE_MAX_ITER` is reached (default 50).

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/foundry-state.sh" set-loop on
```

## v1.2.0 — Pre-flight validation

Before enabling the loop, this command now validates the **test config** in `state.md` `test:` block. If `test.cmd` is empty AND `test.skip_tests` is not `true`, you get a warning:

```
⚠ test.cmd is empty. /foundry-execute will fail verify_execute.
  Fix one of:
    (a) bash scripts/foundry-auto-detect-test.sh --apply   (auto-detect from project files)
    (b) bash scripts/foundry-state.sh set-test-config cmd "pnpm test"
    (c) bash scripts/foundry-state.sh set-test-config skip_tests true   (explicit opt-out)
```

If you also haven't set `coverage_baseline`, you'll be reminded to do so after the first verify_execute run:

```
ℹ coverage_baseline not set. After first ticket, run:
    bash scripts/foundry-state.sh set-coverage-baseline
```

## WARNING

AFK behaviour. The agent will iterate across turns without waiting for you, except when:
- A new human-gated decision is needed (e.g., the user is asked a question).
- A new feature / PRD amendment is required (which loops back to Phase 4).
- `DEV_PIPELINE_MAX_ITER` is hit (default 50).
- The 8-gate convergence check passes — the loop surfaces a "Ready for /foundry-signoff" decision and waits for you.

Pair with `/foundry-status` periodically to check progress. To pause: `/foundry-loop-off`.