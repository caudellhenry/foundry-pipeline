#!/usr/bin/env bash
# post-tool-use.sh — dev-pipeline PostToolUse hook
#
# 1. Logs the tool call summary under .foundry/logs/<phase>.log.
# 2. Calls foundry-context-check.sh — if it recommends rotation, surfaces the
#    recommendation as additionalContext.
# 3. For Write/Edit on tracked files, stashes the diff for later
#    literate-diff production.

set -euo pipefail

HOOK_INPUT="$(cat)"
TOOL_NAME="$(printf '%s' "$HOOK_INPUT" | jq -r '.tool_name // ""' 2>/dev/null || true)"

PROJECT_ROOT="${DEV_PIPELINE_PROJECT_ROOT:-$(pwd)}"
FOUNDRY_DIR="$PROJECT_ROOT/.foundry"
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
STATE_FILE="$FOUNDRY_DIR/state.md"

mkdir -p "$FOUNDRY_DIR/logs"

PHASE="unknown"
if [[ -f "$STATE_FILE" ]]; then
  PHASE="$(grep -E '^current_phase:' "$STATE_FILE" | sed 's/^current_phase:[[:space:]]*//' | head -1)"
fi

TS="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
SHORT="$(printf '%s' "$HOOK_INPUT" | head -c 240 | tr -d '\n')"
printf '%s\tphase=%s\ttool=%s\t%s\n' "$TS" "$PHASE" "$TOOL_NAME" "$SHORT" >> "$FOUNDRY_DIR/logs/${PHASE}.log"

# Context-rotation check (non-blocking recommendation)
ROT=""
if [[ -x "$PLUGIN_ROOT/scripts/foundry-context-check.sh" ]]; then
  ROT="$(bash "$PLUGIN_ROOT/scripts/foundry-context-check.sh" 2>/dev/null || true)"
fi

# Literate-diff staging for Write/Edit
if [[ "$TOOL_NAME" == "Write" || "$TOOL_NAME" == "Edit" ]]; then
  FPATH="$(printf '%s' "$HOOK_INPUT" | jq -r '.tool_input.file_path // .tool_input.path // ""' 2>/dev/null || true)"
  if [[ -n "$FPATH" ]]; then
    mkdir -p "$FOUNDRY_DIR/literate/staging"
    printf '%s\t%s\n' "$TS" "$FPATH" >> "$FOUNDRY_DIR/literate/staging/files.log"
  fi
fi

# Build output
if [[ -n "$ROT" && "$ROT" != "ok" ]]; then
  jq -nc --arg r "$ROT" '{hookSpecificOutput: {hookEventName: "PostToolUse", additionalContext: ("dev-pipeline: " + $r)}}'
else
  jq -nc '{hookSpecificOutput: {hookEventName: "PostToolUse", additionalContext: "dev-pipeline: post-tool ok"}}'
fi

exit 0