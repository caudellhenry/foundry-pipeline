#!/usr/bin/env bash
# session-start.sh — dev-pipeline SessionStart hook
#
# Bootstraps .foundry/ in the current project if missing, then
# prints the current pipeline state so the agent has context on resume.
#
# Reads hook input from stdin (JSON with session_id).
# Writes hook-specific output (additionalContext) to stdout as JSON.

set -euo pipefail

HOOK_INPUT="$(cat)"
SESSION_ID="$(printf '%s' "$HOOK_INPUT" | jq -r '.session_id // ""' 2>/dev/null || true)"
MATCHER="$(printf '%s' "$HOOK_INPUT" | jq -r '.matcher // "startup"' 2>/dev/null || echo startup)"

# Resolve project root (look for .git or fall back to cwd)
PROJECT_ROOT="${DEV_PIPELINE_PROJECT_ROOT:-$(pwd)}"
if [[ ! -d "$PROJECT_ROOT/.git" ]] && [[ -d "$PROJECT_ROOT" ]]; then
  # walk up to find the project root (the directory containing .git, or cwd)
  d="$PROJECT_ROOT"
  while [[ "$d" != "/" ]]; do
    if [[ -d "$d/.git" ]]; then PROJECT_ROOT="$d"; break; fi
    d="$(dirname "$d")"
  done
fi

# Plugin root (this script is in hooks/, so plugin root is one level up)
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"

# 1. Bootstrap .foundry/ if missing
FOUNDRY_DIR="$PROJECT_ROOT/.foundry"
if [[ ! -d "$FOUNDRY_DIR" ]]; then
  bash "$PLUGIN_ROOT/scripts/foundry-init.sh" --quiet
fi

# 2. Read state (or write a fresh one)
STATE_FILE="$FOUNDRY_DIR/state.md"
if [[ ! -f "$STATE_FILE" ]]; then
  cp "$PLUGIN_ROOT/templates/state.md" "$STATE_FILE"
fi

# 3. Stamp session id into state so the loop can be session-aware
if [[ -n "$SESSION_ID" ]]; then
  TMP="$(mktemp)"
  awk -v sid="$SESSION_ID" '
    /^current_phase:/ { print; print "last_session_id: " sid; next }
    /^last_session_id:/ { print "last_session_id: " sid; next }
    { print }
  ' "$STATE_FILE" > "$TMP" && mv "$TMP" "$STATE_FILE"
fi

# 4. Read the current phase + auto_loop + brief status
PHASE="$(grep -E '^current_phase:' "$STATE_FILE" | sed 's/^current_phase:[[:space:]]*//' | head -1)"
AUTO="$(grep -E '^auto_loop:' "$STATE_FILE" | sed 's/^auto_loop:[[:space:]]*//' | head -1)"

# 5. Build a short status line for the agent's context
SUMMARY="dev-pipeline bootstrap: project=$PROJECT_ROOT phase=$PHASE auto_loop=$AUTO matcher=$MATCHER"
LOG_LINE="$(date -u +"%Y-%m-%dT%H:%M:%SZ") session-start matcher=$MATCHER phase=$PHASE auto_loop=$AUTO"

mkdir -p "$FOUNDRY_DIR/logs"
printf '%s\n' "$LOG_LINE" >> "$FOUNDRY_DIR/logs/session-start.log"

# 6. Output JSON for ZCode to surface as additionalContext
jq -nc --arg ctx "$SUMMARY" '{hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: $ctx}}'

exit 0