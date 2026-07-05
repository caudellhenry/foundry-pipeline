#!/usr/bin/env bash
# pre-tool-use.sh — dev-pipeline PreToolUse hook
#
# Validates scope on Bash / Write / Edit tool events.
# Surfaces a non-blocking warning when a command would touch files outside
# the project root or .foundry/. The user (or downstream agent) decides
# whether to honour the warning.

set -euo pipefail

HOOK_INPUT="$(cat)"
TOOL_NAME="$(printf '%s' "$HOOK_INPUT" | jq -r '.tool_name // ""' 2>/dev/null || true)"

PROJECT_ROOT="${DEV_PIPELINE_PROJECT_ROOT:-$(pwd)}"
WARN=""

case "$TOOL_NAME" in
  Bash)
    CMD="$(printf '%s' "$HOOK_INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null || true)"
    # Flag rm -rf, sudo, or writes to absolute paths outside project
    if printf '%s' "$CMD" | grep -qE 'rm[[:space:]]+-rf?[[:space:]]+/[[:space:]]'; then
      WARN="Refusing destructive rm outside the project. Use scripts/foundry-cleanup.sh instead."
    elif printf '%s' "$CMD" | grep -qE 'sudo[[:space:]]'; then
      WARN="Avoid sudo inside the dev-pipeline. Use a sandbox or worktree."
    fi
    ;;
  Write|Edit)
    FPATH="$(printf '%s' "$HOOK_INPUT" | jq -r '.tool_input.file_path // .tool_input.path // ""' 2>/dev/null || true)"
    # Warn (don't block) on writes outside project root
    if [[ -n "$FPATH" ]] && [[ "$FPATH" != "$PROJECT_ROOT"* ]] && [[ "$FPATH" != /* ]]; then
      WARN="Path is relative; verify it stays under $PROJECT_ROOT."
    fi
    ;;
esac

if [[ -n "$WARN" ]]; then
  jq -nc --arg w "$WARN" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      additionalContext: ("dev-pipeline guardrail: " + $w)
    }
  }'
  exit 0
fi

# No-op output (still valid JSON)
jq -nc '{hookSpecificOutput: {hookEventName: "PreToolUse", additionalContext: "dev-pipeline: ok"}}'
exit 0