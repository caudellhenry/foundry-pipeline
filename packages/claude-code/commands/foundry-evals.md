---
description: "/foundry-evals — Run the eval suite (v1.0.0 pass^k discipline per Anthropic A14). Lists scenarios, runs all, or runs a subset. Outputs JSON for CI integration."
argument-hint: "[--scenario=<name>] [--k=<N>] [--release-check] [--json] [--list]"
allowed-tools: ["Bash(${CLAUDE_PLUGIN_ROOT}/scripts/foundry-eval-runner.sh:*)"]
---

# /foundry-evals — pass^k eval harness (Anthropic A14)

The eval suite is a set of real-failure scenarios (per Anthropic's "Demystifying Evals for AI Agents" guidance). Each scenario declares a `task:`, `setup:`, `test_cmd:`, `expect_exit_code:`, and `pass_k:`. The runner executes each scenario `pass_k` times; all trials must pass for the scenario to count as PASS.

## Quick reference

| Invocation | Effect |
|---|---|
| `/foundry-evals` | Run all 10 scenarios with default pass^3 |
| `/foundry-evals --list` | List available scenarios with descriptions |
| `/foundry-evals --scenario=01-hello-world` | Run a single scenario |
| `/foundry-evals --k=1` | Use pass^1 (faster; for dev loop) |
| `/foundry-evals --release-check` | Run only `release_gating: true` scenarios |
| `/foundry-evals --json` | Output as JSON (for CI / dashboards) |

## Where scenarios live

`evals/scenarios/*.yaml`. Each scenario is a self-contained YAML file. The default set shipped in v1.0.0:

| # | Scenario | Type | release-gating |
|---|----------|------|-----------------|
| 01 | hello-world | greenfield | yes |
| 02 | truer-exit-zero | greenfield | yes |
| 03 | false-exit-nonzero | greenfield | yes |
| 04 | pipefail-propagates | greenfield | yes |
| 05 | subshell-isolation | greenfield | yes |
| 06 | script-syntax-check | legacy | no |
| 07 | foundry-self-test-syntax | legacy | yes |
| 08 | foundry-hooks-syntax | legacy | yes |
| 09 | adversarial-cli-args | adversarial | no |
| 10 | adversarial-fail-mode | adversarial | no |

## Output

Human-readable: a summary table with ✅/❌/k_pass-k symbols.
JSON: a structured object with `timestamp`, `scenarios_total`, `passed`, `failed`, `verdict`, and per-scenario `results[]`.
Files: `evals/results/<timestamp>-results.json` (per-scenario results + verdict).

## CI integration

`.github/workflows/foundry-evals.yml` runs `foundry-eval-runner.sh --release-check --json` on every PR. The workflow fails the build if `verdict != PASS`.

## Adding a new scenario

1. Create `evals/scenarios/<NN>-<name>.yaml` with these fields:
   ```yaml
   task: <one-line description>
   test_cmd: <bash command to run; should match expect_exit_code>
   expect_exit_code: <0=pass, non-zero=fail>
   pass_k: <3 recommended; 1 for dev loop>
   release_gating: <true|false; default false>
   # Optional:
   setup: <bash to run before each trial>
   ```
2. Verify with `bash scripts/foundry-eval-runner.sh --scenario=<NN>-<name> --k=1`.
3. Get two-expert signoff on the pass/fail definition (Anthropic A14 quality bar).
4. Bump pass_k to 3 for release.

## Two-expert rule (Anthropic A14)

No eval task ships unless **two maintainers independently agree** on its pass/fail definition. A task that's been around 30 days without being triggered can be pruned (per v1.1.0 auto-prune plan).
