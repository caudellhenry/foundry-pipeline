---
description: Disciplined 6-step diagnosis loop for hard bugs and performance regressions
argument-hint: "<symptom-or-bug>"
hide-from-slash-command-tool: "false"
foundry_version: 2.0.0
---

# `/foundry:diagnose`

Backed by the `diagnose` skill (`packages/core/skills/diagnose/SKILL.md`).

## Behaviour — 6-step disciplined loop

1. **Reproduce** — minimal, reliable reproduction
2. **Minimise** — strip to smallest failing case
3. **Hypothesise** — list possible root causes ranked by likelihood
4. **Instrument** — add logging/probes to confirm/deny
5. **Fix** — smallest change that fixes the root cause
6. **Regression-test** — add a test that fails before the fix and passes after

## When to use

A failure's cause is not obvious within one look.

## Exit codes

- 0 — diagnosis complete, fix verified by regression test
- 1 — could not reproduce