---
description: "/foundry-eval — Run the agent-eval harness. Tests the foundry against fixed scenarios to catch prompt drift."
argument-hint: "[scenario-name]"
allowed-tools: ["Bash(${CLAUDE_PLUGIN_ROOT}/scripts/foundry-state.sh:*)", "Bash(${CLAUDE_PLUGIN_ROOT}/scripts/verify.sh:*)"]
---

# /foundry-eval — Run agent eval

Runs the agent-eval harness against a scenario (or all scenarios if none specified). Produces a JSON grade per scenario and rolls them into `eval/results/debt.md`.

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/foundry-state.sh" eval [scenario-name]
```

The script:
1. Reads `.foundry/eval/scenarios/<name>.yaml`.
2. Runs the agent in a fresh context with the scenario's challenge.
3. Captures the artefacts and process log.
4. Grades on 5 axes (functional correctness, process discipline, prompt hygiene, communication clarity, resource efficiency).
5. Writes `.foundry/eval/results/<timestamp>-<scenario>.json`.
6. Updates `.foundry/eval/results/debt.md`.

Pass threshold: ≥ 70. Sticky failures (3 in a row) trigger a prompt-debt alarm.

See `skills/foundry-agent-eval/SKILL.md` for the full discipline.