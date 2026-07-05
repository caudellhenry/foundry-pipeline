#!/usr/bin/env bash
# packages/core/tracker-adapters/local/adapter.sh
#
# Local tracker adapter — stores issues as markdown files in .foundry/issues/
# and the board as .foundry/board.md. Zero external dependencies.
#
# Issue file format:
#   .foundry/issues/STORY-001-add-stripe-subscriptions.md
#   with frontmatter: {id, title, status, priority, labels, depends_on, story_points, created_at}
#   and body: the story description
#
# Board file format (.foundry/board.md):
#   Kanban with sections Backlog / Ready / In progress / Review / Done / Blocked.

set -uo pipefail

# Source the interface
_HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$_HERE/../interface.sh"

FOUNDRY_DIR="${FOUNDRY_DIR:-.foundry}"
ISSUES_DIR="$FOUNDRY_DIR/issues"
BOARD_FILE="$FOUNDRY_DIR/board.md"

# Ensure directories exist
tracker_local_init() {
  mkdir -p "$ISSUES_DIR" "$FOUNDRY_DIR/logs"
  # Create .gitkeep if dir is empty (so the dir is tracked)
  [[ -f "$ISSUES_DIR/.gitkeep" ]] || touch "$ISSUES_DIR/.gitkeep"
  if [[ ! -f "$BOARD_FILE" ]]; then
    cat > "$BOARD_FILE" <<'EOF'
# Board

## Backlog

## Ready

## In progress

## Review

## Done

## Blocked

## Parallelisable now

EOF
  fi
  _tracker_log "local adapter initialized at $FOUNDRY_DIR"
  echo '{"backend":"local","status":"ready"}'
  return 0
}

# Generate next issue ID (e.g., STORY-001, ENABLER-001)
_tracker_local_next_id() {
  local prefix="${1:-STORY}"
  local max=0
  for f in "$ISSUES_DIR"/${prefix}-*.md; do
    [[ -f "$f" ]] || continue
    local num
    num=$(basename "$f" | sed -E "s/${prefix}-([0-9]+).*/\1/")
    [[ "$num" =~ ^[0-9]+$ ]] && (( num > max )) && max=$num
  done
  printf '%s-%03d' "$prefix" $((max + 1))
}

# Create an issue file
# Args: title, body, labels (comma-separated)
tracker_local_create_issue() {
  local title="$1"
  local body="${2:-}"
  local labels="${3:-}"

  local prefix="STORY"
  if [[ "$labels" == *"enabler"* ]]; then
    prefix="ENABLER"
  fi
  local id
  id=$(_tracker_local_next_id "$prefix")

  local slug
  slug=$(echo "$title" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g' | sed -E 's/^-|-$//g' | cut -c1-50)
  local file="$ISSUES_DIR/${id}-${slug}.md"

  local ts
  ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  local labels_yaml
  labels_yaml=$(echo "$labels" | tr ',' '\n' | sed 's/^ */  - /' | tr '\n' ' ')

  cat > "$file" <<EOF
---
id: $id
title: $title
status: ready
priority: medium
labels: [${labels}]
created_at: $ts
updated_at: $ts
depends_on: []
blocks: []
---

# $title

$body
EOF

  # Update board
  _tracker_local_append_board "$id" "$title" "Ready"

  _tracker_log "local: created $id — $title"
  echo "$id"
  return 0
}

# Update issue status
# Args: issue_id, status
tracker_local_update_status() {
  local issue_id="$1"
  local status="$2"
  tracker_validate_status "$status" || return 1

  local file
  file=$(ls "$ISSUES_DIR"/${issue_id}-*.md 2>/dev/null | head -1)
  if [[ -z "$file" ]]; then
    echo "ERROR: issue $issue_id not found in $ISSUES_DIR" >&2
    return 1
  fi

  local old_status
  old_status=$(awk '/^status:/{print $2; exit}' "$file")
  local title
  title=$(awk '/^title:/{$1=""; print substr($0,2); exit}' "$file")

  # Update frontmatter
  local ts
  ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  sed -i.bak "s/^status: $old_status/status: $status/" "$file"
  sed -i.bak "s/^updated_at:.*/updated_at: $ts/" "$file"
  rm -f "$file.bak"

  # Move on board
  _tracker_local_remove_board "$issue_id"
  _tracker_local_append_board "$issue_id" "$title" "$status"

  _tracker_log "local: $issue_id $old_status → $status"
  echo "{\"id\":\"$issue_id\",\"status\":\"$status\",\"updated_at\":\"$ts\"}"
  return 0
}

# Add comment
# Args: issue_id, body
tracker_local_add_comment() {
  local issue_id="$1"
  local body="$2"

  local file
  file=$(ls "$ISSUES_DIR"/${issue_id}-*.md 2>/dev/null | head -1)
  if [[ -z "$file" ]]; then
    echo "ERROR: issue $issue_id not found" >&2
    return 1
  fi

  local ts
  ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  echo -e "\n## Comment @ $ts\n\n$body\n" >> "$file"
  _tracker_log "local: added comment to $issue_id"
  echo "{\"id\":\"$issue_id\",\"comment_added_at\":\"$ts\"}"
  return 0
}

# Get issue as JSON
# Args: issue_id
tracker_local_get_issue() {
  local issue_id="$1"

  local file
  file=$(ls "$ISSUES_DIR"/${issue_id}-*.md 2>/dev/null | head -1)
  if [[ -z "$file" ]]; then
    echo "ERROR: issue $issue_id not found" >&2
    return 1
  fi

  awk -v id="$issue_id" '
    BEGIN { in_fm=0; fm_done=0; print "{" }
    /^---$/ {
      if (in_fm && !fm_done) { fm_done=1; print ",\"body\":\""; next }
      in_fm=1; next
    }
    in_fm && !fm_done {
      gsub(/^  /, "")
      gsub(/": /, "\": \"")
      gsub(/, $/, "")
      if (NF == 0) next
      if (first) print ","; first=1
      print "\"" $0
    }
    fm_done {
      gsub(/"/, "\\\"")
      printf "%s", $0
    }
    END { print "\"}" }
  ' "$file"
  return 0
}

# List issues as JSON array
# Args: filter (e.g., "status=ready", "label=enabler", or empty for all)
tracker_local_list_issues() {
  local filter="${1:-}"

  local prefix_match=""
  case "$filter" in
    label=enabler*)  prefix_match="ENABLER-" ;;
    label=story*)    prefix_match="STORY-" ;;
    status=*)        local status_filter="${filter#status=}"; prefix_match="" ;;
  esac

  echo "["
  local first=1
  for f in "$ISSUES_DIR"/*.md; do
    [[ -f "$f" ]] || continue
    local fname
    fname=$(basename "$f")
    [[ "$fname" == ".gitkeep" ]] && continue

    if [[ -n "$prefix_match" && "$fname" != ${prefix_match}* ]]; then
      continue
    fi

    if [[ -n "${status_filter:-}" ]]; then
      local s
      s=$(awk '/^status:/{print $2; exit}' "$f")
      [[ "$s" != "$status_filter" ]] && continue
    fi

    local id
    id=$(echo "$fname" | sed -E 's/^([A-Z]+-[0-9]+)-.*/\1/')
    local title
    title=$(awk '/^title:/{$1=""; print substr($0,2); exit}' "$f")
    local status
    status=$(awk '/^status:/{print $2; exit}' "$f")

    if [[ $first -eq 0 ]]; then echo ","; fi
    first=0
    printf '  {"id":"%s","title":"%s","status":"%s"}' "$id" "$title" "$status"
  done
  echo ""
  echo "]"
  return 0
}

# Link two issues with a dependency
# Args: issue_id, blocks_id
tracker_local_link_dep() {
  local issue_id="$1"
  local blocks_id="$2"

  local file
  file=$(ls "$ISSUES_DIR"/${issue_id}-*.md 2>/dev/null | head -1)
  [[ -z "$file" ]] && { echo "ERROR: issue $issue_id not found" >&2; return 1; }

  sed -i.bak "s/^blocks: \[\]/blocks: [\"$blocks_id\"]/" "$file"
  rm -f "$file.bak"
  _tracker_log "local: $issue_id blocks $blocks_id"
  echo "{\"from\":\"$issue_id\",\"to\":\"$blocks_id\"}"
  return 0
}

# Helpers (private)
_tracker_local_append_board() {
  local id="$1"
  local title="$2"
  local status="$3"

  local section
  case "$status" in
    ready) section="## Ready" ;;
    in_progress) section="## In progress" ;;
    review) section="## Review" ;;
    done) section="## Done" ;;
    blocked) section="## Blocked" ;;
    *) section="## Backlog" ;;
  esac

  # Append to the right section (create section if missing)
  if grep -q "^${section}$" "$BOARD_FILE" 2>/dev/null; then
    awk -v section="$section" -v id="$id" -v title="$title" '
      $0 == section { print; print "- **" id "** — " title; in_section=1; next }
      /^## / { in_section=0 }
      { print }
    ' "$BOARD_FILE" > "$BOARD_FILE.tmp"
    mv "$BOARD_FILE.tmp" "$BOARD_FILE"
  fi
}

_tracker_local_remove_board() {
  local id="$1"
  # Remove the line `- **ID** — ...` from any section
  sed -i.bak "/^- \*\*${id}\*\*/d" "$BOARD_FILE"
  rm -f "$BOARD_FILE.bak"
}

export -f tracker_local_init tracker_local_create_issue tracker_local_update_status \
          tracker_local_add_comment tracker_local_get_issue tracker_local_list_issues \
          tracker_local_link_dep _tracker_local_append_board _tracker_local_remove_board \
          _tracker_local_next_id