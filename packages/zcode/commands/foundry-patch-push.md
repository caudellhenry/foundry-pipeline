---
description: Push local foundry-pipeline edits to canonical caudellhenry/foundry-pipeline via PR
argument-hint: "[--fork=<your-gh-user>] [--message=<commit-message>]"
hide-from-slash-command-tool: "false"
foundry_version: 2.0.0
---

# `/foundry:patch-push`

Push local edits upstream as a PR to `caudellhenry/foundry-pipeline`.

## Behaviour — interactive

1. **Fork detection** — if you don't have a fork, prompts to create one via `gh repo fork caudellhenry/foundry-pipeline --clone=false`.
2. **Branch creation** — checks out `patch/<your-gh-user>/<YYYY-MM-DD>-<short-desc>` on your fork.
3. **Diff application** — applies the local diff on top of `v2.0.0`.
4. **Eval gate** — runs `bash evals/run.sh --release-check`. Aborts if any release-gating scenario fails.
5. **PR creation** — opens a PR with auto-filled template (see below).
6. **Confirmation** — prints PR URL and waits for user confirmation to keep the local branch alive (in case they want to iterate).

## PR template (auto-filled)

```markdown
## Local patch

- **Source harness**: <claude-code | zcode | …>
- **Source version**: v2.0.0
- **Files touched**: 3 (skills/ship/SKILL.md, scripts/foundry-loop.sh, …)
- **Pass^k**: PASS (8/8 scenarios)
- **Author**: @<your-gh-user>

## Diff summary

<git diff --stat v2.0.0..HEAD>

## Checklist

- [ ] I have read CONTRIBUTING.md
- [ ] I have run `bash scripts/foundry-self-test.sh` locally
- [ ] My changes follow the conventional-commits format
```

## Exit codes

- 0 — PR opened
- 1 — eval gate failed
- 2 — user cancelled
- 3 — git/GitHub CLI error