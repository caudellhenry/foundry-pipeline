---
phase: execute
status: pending
ticket: <STORY-ID>
platform: github | gitlab
pr_url: null
commit: null
iteration: 0
created: <ISO timestamp>
updated: <ISO timestamp>
---
# PR State — <STORY-ID>

> **Platform-agnostic per-PR state file.** Used by Phase 6 (Execute) when the
> ticket's `exit_criterion` is `pr-green` (or `mr-green`). One file per ticket
> at `.foundry/pr-state/<TICKET>.md`. The verifier (`scripts/verify.sh pr`)
> only PASSes when this file is marked `## Status: green`.

## Status: pending

(`pending` → `green` once `gh pr checks` / `glab ci status` reports zero failures and the agent writes the green flag here.)

## PR / MR
- **Platform**: github | gitlab
- **URL**: <PR_URL or MR_URL>
- **Branch**: <branch name>
- **Title**: <PR title>
- **Body**: <summary + test plan>

## Last check rollup
- <one line per CI check — name + state (success / failure / pending)>

## Fix-up history (one row per iteration)
| Iter | Time | Failing check | Fix commit | Re-push |
|------|------|---------------|-----------|---------|

## Blockers
- (one bullet per blocker, or empty)

## Verifier
- **Status**: pending | green
- **Ran at**: <timestamp>
- **By**: scripts/verify.sh pr <PR_URL>

## Anti-gaming rules (from "Ship PR Until Green")
- [ ] I did NOT modify the check command or exit criteria to force success.
- [ ] I did NOT skip, disable, or bypass checks to pass the exit condition.
- [ ] If stuck after several iterations, I will stop and report blockers instead of gaming metrics.