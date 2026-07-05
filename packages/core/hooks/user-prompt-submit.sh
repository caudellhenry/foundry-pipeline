#!/usr/bin/env bash
# user-prompt-submit.sh — dev-pipeline UserPromptSubmit hook
#
# Logs the user's prompt and surfaces the current phase to the agent.

set -euo pipefail

HOOK_INPUT="$(cat)"
PROMPT="$(printf '%s' "$HOOK_INPUT" | jq -r '.prompt // ""' 2>/dev/null || true)"

PROJECT_ROOT="${DEV_PIPELINE_PROJECT_ROOT:-$(pwd)}"
FOUNDRY_DIR="$PROJECT_ROOT/.foundry"
STATE_FILE="$FOUNDRY_DIR/state.md"

mkdir -p "$FOUNDRY_DIR/logs"

PHASE="(no-pipeline)"
AUTO="false"
if [[ -f "$STATE_FILE" ]]; then
  PHASE="$(grep -E '^current_phase:' "$STATE_FILE" | sed 's/^current_phase:[[:space:]]*//' | head -1)"
  AUTO="$(grep -E '^auto_loop:' "$STATE_FILE" | sed 's/^auto_loop:[[:space:]]*//' | head -1)"
fi

TS="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
# Log first 200 chars of prompt (avoid huge logs)
SHORT="$(printf '%s' "$PROMPT" | head -c 200)"
printf '%s\tphase=%s\tauto=%s\tprompt=%s\n' "$TS" "$PHASE" "$AUTO" "$SHORT" >> "$FOUNDRY_DIR/logs/prompts.log"

SUMMARY="dev-pipeline: current_phase=$PHASE auto_loop=$AUTO"
jq -nc --arg ctx "$SUMMARY" '{hookSpecificOutput: {hookEventName: "UserPromptSubmit", additionalContext: $ctx}}'

exit 0