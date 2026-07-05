#!/usr/bin/env bash
# packages/core/tracker-adapters/github/adapter.sh
#
# GitHub Issues tracker adapter.
#
# Auth modes (tried in order):
#   1. GitHub MCP server (if configured in .mcp.json)
#   2. GitHub REST API via `gh` CLI (requires `gh auth login`)
#   3. GitHub REST API via curl (requires $GITHUB_TOKEN env var)
#
# Required state.md frontmatter:
#   tracker:
#     backend: github
#     repo: owner/name      # e.g., caudellhenry/my-saas
#
# Optional:
#   mcp_required: false     # if true, fail loudly if MCP absent

set -uo pipefail

_HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$_HERE/../interface.sh"

# Read repo from state.md if not set
: "${GITHUB_REPO:=}"
: "${GITHUB_MCP_TOOL:=mcp__github__}"
: "${GITHUB_API_BASE:=https://api.github.com}"

_tracker_github_read_repo() {
  if [[ -n "$GITHUB_REPO" ]]; then
    return
  fi
  if [[ -f "$TRACKER_STATE_FILE" ]]; then
    GITHUB_REPO=$(awk '/^tracker:/{flag=1; next} flag && /^  repo:/{print $2; exit} flag && /^[a-z]/{exit}' "$TRACKER_STATE_FILE" 2>/dev/null)
  fi
  if [[ -z "$GITHUB_REPO" ]]; then
    echo "ERROR: tracker.github.repo not set in $TRACKER_STATE_FILE" >&2
    return 1
  fi
}

_tracker_github_has_mcp() {
  # Detect GitHub MCP server in .mcp.json
  local mcp_file="${MCP_FILE:-.mcp.json}"
  [[ -f "$mcp_file" ]] || return 1
  jq -e '.mcpServers.github' "$mcp_file" >/dev/null 2>&1
}

_tracker_github_has_gh() {
  command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1
}

_tracker_github_has_token() {
  [[ -n "${GITHUB_TOKEN:-}" ]]
}

# Pick auth mode; sets GITHUB_AUTH_MODE
_tracker_github_pick_mode() {
  if _tracker_github_has_mcp; then
    GITHUB_AUTH_MODE="mcp"
  elif _tracker_github_has_gh; then
    GITHUB_AUTH_MODE="gh"
  elif _tracker_github_has_token; then
    GITHUB_AUTH_MODE="token"
  else
    GITHUB_AUTH_MODE="none"
    return 1
  fi
}

tracker_github_init() {
  _tracker_github_read_repo || return 1
  if ! _tracker_github_pick_mode; then
    echo "ERROR: GitHub tracker requires one of: MCP server in .mcp.json, `gh auth login`, or \$GITHUB_TOKEN" >&2
    return 1
  fi
  _tracker_log "github adapter initialized: repo=$GITHUB_REPO, mode=$GITHUB_AUTH_MODE"
  echo "{\"backend\":\"github\",\"repo\":\"$GITHUB_REPO\",\"auth_mode\":\"$GITHUB_AUTH_MODE\",\"status\":\"ready\"}"
  return 0
}

# Call GitHub API — abstracts MCP / gh / curl
# Args: METHOD, PATH, [JSON_BODY]
_tracker_github_api() {
  local method="$1"
  local path="$2"
  local body="${3:-}"

  case "$GITHUB_AUTH_MODE" in
    mcp)
      # MCP calls are not directly callable from bash; caller should have used MCP path.
      # For now, fall through to gh mode if MCP path isn't invoked directly.
      ;;
    gh)
      if [[ -n "$body" ]]; then
        gh api --method "$method" -H "Accept: application/vnd.github+json" \
          "repos/$GITHUB_REPO/$path" --input - <<< "$body"
      else
        gh api --method "$method" -H "Accept: application/vnd.github+json" \
          "repos/$GITHUB_REPO/$path"
      fi
      ;;
    token)
      if [[ -n "$body" ]]; then
        curl -sS -X "$method" \
          -H "Authorization: token $GITHUB_TOKEN" \
          -H "Accept: application/vnd.github+json" \
          "$GITHUB_API_BASE/repos/$GITHUB_REPO/$path" \
          -d "$body"
      else
        curl -sS -X "$method" \
          -H "Authorization: token $GITHUB_TOKEN" \
          -H "Accept: application/vnd.github+json" \
          "$GITHUB_API_BASE/repos/$GITHUB_REPO/$path"
      fi
      ;;
  esac
}

# Map foundry status → GitHub label
_tracker_github_status_label() {
  case "$1" in
    ready) echo "foundry:ready" ;;
    in_progress) echo "foundry:in-progress" ;;
    review) echo "foundry:review" ;;
    done) echo "foundry:done" ;;
    blocked) echo "foundry:blocked" ;;
  esac
}

# Create issue
# Args: title, body, labels (comma-separated)
tracker_github_create_issue() {
  local title="$1"
  local body="${2:-}"
  local labels="${3:-}"

  # Convert comma-separated labels to JSON array
  local labels_json
  labels_json=$(echo "$labels" | tr ',' '\n' | sed 's/^[[:space:]]*//' | sed '/^$/d' | jq -R . | jq -s .)

  local payload
  payload=$(jq -n \
    --arg title "$title" \
    --arg body "$body" \
    --argjson labels "$labels_json" \
    '{title: $title, body: $body, labels: $labels}')

  local response
  response=$(_tracker_github_api POST "issues" "$payload")
  local issue_number
  issue_number=$(echo "$response" | jq -r '.number // empty')

  if [[ -z "$issue_number" ]]; then
    echo "ERROR: failed to create GitHub issue" >&2
    echo "$response" >&2
    return 1
  fi

  _tracker_log "github: created issue #$issue_number — $title"
  echo "$issue_number"
  return 0
}

# Update status (adds a foundry status label + removes others)
# Args: issue_id (number), status
tracker_github_update_status() {
  local issue_id="$1"
  local status="$2"
  tracker_validate_status "$status" || return 1

  local new_label
  new_label=$(_tracker_github_status_label "$status")

  # Get current labels
  local current
  current=$(_tracker_github_api GET "issues/$issue_id" | jq -r '.labels[].name')

  # Remove other foundry:* labels
  local to_remove
  to_remove=$(echo "$current" | grep '^foundry:' | grep -v "^${new_label}$" || true)
  for lbl in $to_remove; do
    _tracker_github_api DELETE "issues/$issue_id/labels/$(printf '%s' "$lbl" | jq -sRr @uri)" >/dev/null
  done

  # Add new label if not already present
  if ! echo "$current" | grep -q "^${new_label}$"; then
    _tracker_github_api POST "issues/$issue_id/labels" "{\"labels\":[\"$new_label\"]}" >/dev/null
  fi

  # Close if done
  if [[ "$status" == "done" ]]; then
    _tracker_github_api PATCH "issues/$issue_id" '{"state":"closed"}' >/dev/null
  elif [[ "$status" == "ready" ]]; then
    _tracker_github_api PATCH "issues/$issue_id" '{"state":"open"}' >/dev/null
  fi

  _tracker_log "github: #$issue_id → $status"
  echo "{\"id\":\"$issue_id\",\"status\":\"$status\"}"
  return 0
}

# Add comment
# Args: issue_id, body
tracker_github_add_comment() {
  local issue_id="$1"
  local body="$2"
  local payload
  payload=$(jq -n --arg body "$body" '{body: $body}')
  local response
  response=$(_tracker_github_api POST "issues/$issue_id/comments" "$payload")
  local comment_id
  comment_id=$(echo "$response" | jq -r '.id // empty')
  [[ -z "$comment_id" ]] && { echo "ERROR: failed to add comment" >&2; echo "$response" >&2; return 1; }
  _tracker_log "github: added comment $comment_id to #$issue_id"
  echo "{\"id\":\"$issue_id\",\"comment_id\":\"$comment_id\"}"
  return 0
}

# Get issue as JSON
# Args: issue_id
tracker_github_get_issue() {
  _tracker_github_api GET "issues/$1"
}

# List issues as JSON array
# Args: filter (e.g., "status=ready", "label=enabler")
tracker_github_list_issues() {
  local filter="${1:-}"
  local labels="foundry:story,foundry:enabler"
  case "$filter" in
    label=enabler*) labels="foundry:enabler" ;;
    label=story*) labels="foundry:story" ;;
    status=*)
      local status="${filter#status=}"
      labels="$(_tracker_github_status_label "$status"),foundry:story,foundry:enabler"
      ;;
  esac

  local label_param
  label_param=$(echo "$labels" | tr ',' '\n' | jq -R . | jq -s 'join(",")')
  local state="open"
  [[ "$filter" == "status=done" ]] && state="closed"

  _tracker_github_api GET "issues?labels=$label_param&state=$state&per_page=100" \
    | jq '[.[] | {id: (.number|tostring), title: .title, status: (.labels | map(select(.name | startswith("foundry:"))) | first | .name | sub("^foundry:"; "") // "backlog"), url: .html_url}]'
}

# Link two issues (GitHub supports issue references in body; we add a comment)
# Args: issue_id, blocks_id
tracker_github_link_dep() {
  local issue_id="$1"
  local blocks_id="$2"
  local body="Blocked by #$blocks_id — auto-linked by foundry."
  local payload
  payload=$(jq -n --arg body "$body" '{body: $body}')
  _tracker_github_api POST "issues/$issue_id/comments" "$payload" >/dev/null
  _tracker_log "github: #$issue_id blocks #$blocks_id"
  echo "{\"from\":\"$issue_id\",\"to\":\"$blocks_id\"}"
  return 0
}

export -f tracker_github_init tracker_github_create_issue tracker_github_update_status \
          tracker_github_add_comment tracker_github_get_issue tracker_github_list_issues \
          tracker_github_link_dep _tracker_github_read_repo _tracker_github_pick_mode \
          _tracker_github_has_mcp _tracker_github_has_gh _tracker_github_has_token \
          _tracker_github_api _tracker_github_status_label