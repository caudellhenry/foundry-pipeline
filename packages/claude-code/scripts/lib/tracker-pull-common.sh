#!/usr/bin/env bash
# scripts/lib/tracker-pull-common.sh
#
# Shared helpers for "pull a tracker issue into a foundry story" flow.
# Used by:
#   - foundry-tracker-pull-issue.sh (one-shot, manual)
#   - tracker_ingest_new in foundry-loop.sh (bulk, every loop iteration)
#
# Backend-specific data is passed via environment variables (cleaner than 10+
# positional args; the backends parse their own APIs and just stuff the result
# into these vars before invoking the helpers).
#
# Required env vars (set by caller):
#   TRACKER_PULL_SID                local story SID (e.g. STORY-42)
#   TRACKER_PULL_TITLE              issue title
#   TRACKER_PULL_BODY               issue body/description (markdown; may be empty)
#   TRACKER_PULL_IMPORTED_FROM      "linear" | "github"
#   TRACKER_PULL_TRACKER_ID_FIELD   frontmatter field name (e.g. linear_issue_uuid, github_issue_id)
#   TRACKER_PULL_TRACKER_ID_VALUE   value for that field
#   TRACKER_PULL_TRACKER_URL        canonical issue URL
#   TRACKER_PULL_TRACKER_HUMAN_ID   human-readable id (e.g. HAC-42 or #42)
#   TRACKER_PULL_PRIORITY           priority label (P0/P1/P2/P3/P4)
#   TRACKER_PULL_STATE              human-readable state at import time
#
# Optional:
#   TRACKER_PULL_DRY_RUN            "1" to skip file writes (just print what would happen)
#   TRACKER_PULL_PARENT_FEATURE     parent feature ID (default F-IMPORT)
#   TRACKER_PULL_ESTIMATE           estimate (default M)
#   TRACKER_PULL_BLOCKED_BY         JSON array (default [])
#   TRACKER_PULL_BLOCKS             JSON array (default [])
#   TRACKER_PULL_FOUNDRY_DIR        foundry directory (default .foundry)
#   TRACKER_PULL_BOARD_SECTION      board section to add to (default Ready)

set -uo pipefail

# Defaults — read-only after this point in the helper functions.
: "${TRACKER_PULL_FOUNDRY_DIR:=.foundry}"
: "${TRACKER_PULL_BOARD_SECTION:=Ready}"
: "${TRACKER_PULL_PARENT_FEATURE:=F-IMPORT}"
: "${TRACKER_PULL_ESTIMATE:=M}"
: "${TRACKER_PULL_BLOCKED_BY:=[]}"
: "${TRACKER_PULL_BLOCKS:=[]}"

# Internal: log a line to .foundry/logs/tracker-pull.log. Best-effort.
_tracker_pull_log() {
  mkdir -p "$TRACKER_PULL_FOUNDRY_DIR/logs" 2>/dev/null || true
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [pull] $*" >> "$TRACKER_PULL_FOUNDRY_DIR/logs/tracker-pull.log" 2>/dev/null || true
}

# Write the story file from env vars. Idempotent: if the file already exists,
# the helper returns 0 without modifying it. Caller decides whether to overwrite.
tracker_pull_write_story_file() {
  local sid="${TRACKER_PULL_SID:-}"
  local stories_dir="$TRACKER_PULL_FOUNDRY_DIR/plan/stories"
  local story_file="$stories_dir/${sid}.md"

  if [[ -z "$sid" ]]; then
    echo "ERROR: TRACKER_PULL_SID not set" >&2
    return 1
  fi

  if [[ "${TRACKER_PULL_DRY_RUN:-0}" == "1" ]]; then
    echo "[DRY-RUN] would write story file: $story_file"
    echo "  sid=$sid title=$TRACKER_PULL_TITLE imported_from=$TRACKER_PULL_IMPORTED_FROM"
    echo "  ${TRACKER_PULL_TRACKER_ID_FIELD}=$TRACKER_PULL_TRACKER_ID_VALUE"
    return 0
  fi

  mkdir -p "$stories_dir" "$TRACKER_PULL_FOUNDRY_DIR/tdd" "$TRACKER_PULL_FOUNDRY_DIR/qa/evidence"

  if [[ -f "$story_file" ]]; then
    _tracker_pull_log "story file exists, skipping: $story_file"
    return 0
  fi

  local now
  now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  # Escape title for inclusion in YAML double-quoted scalar.
  local title_yaml
  title_yaml=$(printf '%s' "$TRACKER_PULL_TITLE" | sed 's/\\/\\\\/g; s/"/\\"/g')

  local tmp
  tmp="$(mktemp -t foundry-pull.XXXXXX)"

  # Note: the imported_from-specific URL + human_id fields use
  # ${TRACKER_PULL_IMPORTED_FROM}_url and ${TRACKER_PULL_IMPORTED_FROM}_human_id
  # (e.g. linear_url, github_url) — bash expands the brace then appends _url.
  cat > "$tmp" <<EOF
---
sid: $sid
title: "$title_yaml"
status: ready
imported_from: $TRACKER_PULL_IMPORTED_FROM
${TRACKER_PULL_TRACKER_ID_FIELD}: $TRACKER_PULL_TRACKER_ID_VALUE
${TRACKER_PULL_IMPORTED_FROM}_url: $TRACKER_PULL_TRACKER_URL
${TRACKER_PULL_IMPORTED_FROM}_human_id: $TRACKER_PULL_TRACKER_HUMAN_ID
parent_feature: $TRACKER_PULL_PARENT_FEATURE
priority: $TRACKER_PULL_PRIORITY
estimate: $TRACKER_PULL_ESTIMATE
blocked_by: $TRACKER_PULL_BLOCKED_BY
blocks: $TRACKER_PULL_BLOCKS
tdd_plan: $TRACKER_PULL_FOUNDRY_DIR/tdd/${sid}.md
evidence_plan: $TRACKER_PULL_FOUNDRY_DIR/qa/evidence/${sid}.md
created: $now
updated: $now
---

# $sid: $TRACKER_PULL_TITLE

> Imported from $TRACKER_PULL_IMPORTED_FROM issue $TRACKER_PULL_TRACKER_HUMAN_ID ($TRACKER_PULL_TRACKER_URL).
> State at import: $TRACKER_PULL_STATE.

## Description

$TRACKER_PULL_BODY

## Acceptance criteria
<!-- Populated by writer sub-agent — see $TRACKER_PULL_FOUNDRY_DIR/tdd/${sid}.md -->

## Vertical slice
<!-- Populated by writer sub-agent -->

## TDD test plan (Phase 6)
<!-- Populated by writer sub-agent -->

## Evidence plan (Phase 7)
<!-- Populated by writer sub-agent -->

## Out of scope
<!-- Populated by writer sub-agent -->
EOF
  mv "$tmp" "$story_file"
  _tracker_pull_log "wrote story: $story_file"
  echo "  ✓ wrote: $story_file"
  return 0
}

# Append the SID to the configured section of plan/board.md. Idempotent:
# if the SID already appears anywhere in the file, skip silently.
tracker_pull_add_to_board() {
  local sid="${TRACKER_PULL_SID:-}"
  local title="${TRACKER_PULL_TITLE:-}"
  local board_file="$TRACKER_PULL_FOUNDRY_DIR/plan/board.md"
  local section="${TRACKER_PULL_BOARD_SECTION}"

  if [[ -z "$sid" ]]; then
    echo "ERROR: TRACKER_PULL_SID not set" >&2
    return 1
  fi

  if [[ "${TRACKER_PULL_DRY_RUN:-0}" == "1" ]]; then
    echo "[DRY-RUN] would add '$sid — $title' to ## $section in $board_file"
    return 0
  fi

  if [[ ! -f "$board_file" ]]; then
    echo "  (board file missing: $board_file — skipping)"
    return 0
  fi

  # Already in any section? Skip.
  if grep -qE "(^|[^A-Za-z0-9_-])${sid}([^A-Za-z0-9_-]|$)" "$board_file"; then
    _tracker_pull_log "$sid already on board, skipping"
    return 0
  fi

  local tmp
  tmp="$(mktemp)"
  awk -v sid="$sid" -v title="$title" -v section="## $section" '
    $0 == section { found=1; print; next }
    found && /^$/ { print "- [ ] " sid " — " title; found=0; print; next }
    { print }
  ' "$board_file" > "$tmp" && mv "$tmp" "$board_file"
  _tracker_pull_log "added $sid to ## $section"
  echo "  ✓ added $sid to ## $section in board.md"
  return 0
}

# Advance current_phase=execute (so /foundry-loop-on picks it up next iter).
# Only flips if the state file exists; otherwise no-op.
tracker_pull_advance_phase() {
  local state_file="$TRACKER_PULL_FOUNDRY_DIR/state.md"

  if [[ "${TRACKER_PULL_DRY_RUN:-0}" == "1" ]]; then
    echo "[DRY-RUN] would set current_phase=execute in $state_file"
    return 0
  fi

  if [[ ! -f "$state_file" ]]; then
    return 0
  fi

  local now
  now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  local tmp
  tmp="$(mktemp)"
  awk -v now="$now" '
    /^current_phase:/ { print "current_phase: execute"; next }
    /^phases:/ { in_ph=1 }
    in_ph && /^  execute:/ { in_ex=1; next }
    in_ex && /^  status:/ { print "  status: in_progress"; in_ex=0; next }
    in_ex && /^  started:/ { print "  started: \"" now "\""; next }
    { print }
  ' "$state_file" > "$tmp" && mv "$tmp" "$state_file"
  _tracker_pull_log "advanced current_phase=execute"
}

export -f _tracker_pull_log tracker_pull_write_story_file \
          tracker_pull_add_to_board tracker_pull_advance_phase