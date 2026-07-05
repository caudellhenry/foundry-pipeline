#!/usr/bin/env bash
# packages/core/tracker-adapters/linear/adapter.sh
#
# Linear tracker adapter.
#
# Auth modes (tried in order):
#   1. Linear MCP server (if configured in .mcp.json)
#   2. Linear GraphQL API via curl (requires $LINEAR_API_KEY env var)
#
# Required state.md frontmatter:
#   tracker:
#     backend: linear
#     team_id: <UUID>
#     project_id: <UUID>          # optional
#
# Optional:
#   mcp_required: false

set -uo pipefail

_HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$_HERE/../interface.sh"

: "${LINEAR_TEAM_ID:=}"
: "${LINEAR_PROJECT_ID:=}"
: "${LINEAR_API_BASE:=https://api.linear.app/graphql}"
: "${LINEAR_API_KEY:=${LINEAR_API_KEY:-}}"

_tracker_linear_read_config() {
  if [[ -n "$LINEAR_TEAM_ID" && -n "${LINEAR_PROJECT_ID:-}" ]]; then
    return
  fi
  if [[ -f "$TRACKER_STATE_FILE" ]]; then
    LINEAR_TEAM_ID="${LINEAR_TEAM_ID:-$(awk '/^tracker:/{flag=1; next} flag && /^  team_id:/{print $2; exit} flag && /^[a-z]/{exit}' "$TRACKER_STATE_FILE" 2>/dev/null)}"
    LINEAR_PROJECT_ID="${LINEAR_PROJECT_ID:-$(awk '/^tracker:/{flag=1; next} flag && /^  project_id:/{print $2; exit} flag && /^[a-z]/{exit}' "$TRACKER_STATE_FILE" 2>/dev/null)}"
  fi
  if [[ -z "$LINEAR_TEAM_ID" ]]; then
    echo "ERROR: tracker.linear.team_id not set in $TRACKER_STATE_FILE" >&2
    return 1
  fi
}

_tracker_linear_has_mcp() {
  local mcp_file="${MCP_FILE:-.mcp.json}"
  [[ -f "$mcp_file" ]] || return 1
  jq -e '.mcpServers.linear' "$mcp_file" >/dev/null 2>&1
}

_tracker_linear_has_token() {
  [[ -n "$LINEAR_API_KEY" ]]
}

_tracker_linear_pick_mode() {
  if _tracker_linear_has_mcp; then
    LINEAR_AUTH_MODE="mcp"
  elif _tracker_linear_has_token; then
    LINEAR_AUTH_MODE="graphql"
  else
    LINEAR_AUTH_MODE="none"
    return 1
  fi
}

tracker_linear_init() {
  _tracker_linear_read_config || return 1
  if ! _tracker_linear_pick_mode; then
    echo "ERROR: Linear tracker requires MCP server in .mcp.json or \$LINEAR_API_KEY env var" >&2
    return 1
  fi
  _tracker_log "linear adapter initialized: team=$LINEAR_TEAM_ID, mode=$LINEAR_AUTH_MODE"
  echo "{\"backend\":\"linear\",\"team_id\":\"$LINEAR_TEAM_ID\",\"auth_mode\":\"$LINEAR_AUTH_MODE\",\"status\":\"ready\"}"
  return 0
}

# Linear GraphQL POST
# Args: query, variables_json
_tracker_linear_gql() {
  local query="$1"
  local vars="${2:-{}}"
  local payload
  payload=$(jq -n --arg q "$query" --argjson v "$vars" '{query: $q, variables: $v}')

  curl -sS -X POST \
    -H "Authorization: $LINEAR_API_KEY" \
    -H "Content-Type: application/json" \
    "$LINEAR_API_BASE" \
    -d "$payload"
}

# Map foundry status → Linear state name
_tracker_linear_state_name() {
  case "$1" in
    ready) echo "Todo" ;;
    in_progress) echo "In Progress" ;;
    review) echo "In Review" ;;
    done) echo "Done" ;;
    blocked) echo "Blocked" ;;
    *) echo "Backlog" ;;
  esac
}

tracker_linear_create_issue() {
  local title="$1"
  local body="${2:-}"
  local labels="${3:-}"

  # Build variables
  local vars
  vars=$(jq -n \
    --arg title "$title" \
    --arg desc "$body" \
    --arg team "$LINEAR_TEAM_ID" \
    '{input: {title: $title, description: $desc, teamId: $team}}')

  if [[ -n "$LINEAR_PROJECT_ID" ]]; then
    vars=$(echo "$vars" | jq --arg pid "$LINEAR_PROJECT_ID" '.input.projectId = $pid')
  fi

  local response
  response=$(_tracker_linear_gql \
    'mutation($input: IssueCreateInput!) { issueCreate(input: $input) { success issue { id identifier title url } } }' \
    "$vars")

  local success issue_id
  success=$(echo "$response" | jq -r '.data.issueCreate.success')
  issue_id=$(echo "$response" | jq -r '.data.issueCreate.issue.identifier // empty')

  if [[ "$success" != "true" || -z "$issue_id" ]]; then
    echo "ERROR: failed to create Linear issue" >&2
    echo "$response" >&2
    return 1
  fi

  _tracker_log "linear: created issue $issue_id — $title"
  echo "$issue_id"
  return 0
}

tracker_linear_update_status() {
  local issue_id="$1"
  local status="$2"
  tracker_validate_status "$status" || return 1

  local state_name
  state_name=$(_tracker_linear_state_name "$status")

  # Get stateId by name (we need to query the workflow states for the team)
  local states_response
  states_response=$(_tracker_linear_gql \
    'query($teamId: String!) { workflowStates(filter: {team: {id: {eq: $teamId}}}) { nodes { id name } } }' \
    "{\"teamId\":\"$LINEAR_TEAM_ID\"}")

  local state_id
  state_id=$(echo "$states_response" | jq -r --arg name "$state_name" \
    '.data.workflowStates.nodes[] | select(.name == $name) | .id' | head -1)

  if [[ -z "$state_id" ]]; then
    echo "ERROR: Linear state '$state_name' not found for team $LINEAR_TEAM_ID" >&2
    return 1
  fi

  # Update issue
  local vars
  vars=$(jq -n --arg id "$issue_id" --arg sid "$state_id" \
    '{input: {id: $id, stateId: $sid}}')

  local response
  response=$(_tracker_linear_gql \
    'mutation($input: IssueUpdateInput!) { issueUpdate(input: $input) { success } }' "$vars")

  local success
  success=$(echo "$response" | jq -r '.data.issueUpdate.success')
  if [[ "$success" != "true" ]]; then
    echo "ERROR: failed to update Linear issue $issue_id" >&2
    echo "$response" >&2
    return 1
  fi

  _tracker_log "linear: $issue_id → $status ($state_name)"
  echo "{\"id\":\"$issue_id\",\"status\":\"$status\"}"
  return 0
}

tracker_linear_add_comment() {
  local issue_id="$1"
  local body="$2"

  local vars
  vars=$(jq -n --arg id "$issue_id" --arg body "$body" \
    '{input: {issueId: $id, body: $body}}')

  local response
  response=$(_tracker_linear_gql \
    'mutation($input: CommentCreateInput!) { commentCreate(input: $input) { success comment { id } } }' "$vars")

  local success comment_id
  success=$(echo "$response" | jq -r '.data.commentCreate.success')
  comment_id=$(echo "$response" | jq -r '.data.commentCreate.comment.id // empty')

  if [[ "$success" != "true" ]]; then
    echo "ERROR: failed to add Linear comment" >&2
    echo "$response" >&2
    return 1
  fi

  _tracker_log "linear: added comment $comment_id to $issue_id"
  echo "{\"id\":\"$issue_id\",\"comment_id\":\"$comment_id\"}"
  return 0
}

tracker_linear_get_issue() {
  local issue_id="$1"
  _tracker_linear_gql \
    'query($id: String!) { issue(id: $id) { id identifier title description state { name } url } }' \
    "{\"id\":\"$issue_id\"}" \
    | jq '.data.issue'
}

tracker_linear_list_issues() {
  local filter="${1:-}"
  local state_name=""
  case "$filter" in
    status=ready) state_name="Todo" ;;
    status=in_progress) state_name="In Progress" ;;
    status=review) state_name="In Review" ;;
    status=done) state_name="Done" ;;
    status=blocked) state_name="Blocked" ;;
  esac

  local filter_args="{\"team\":{\"id\":{\"eq\":\"$LINEAR_TEAM_ID\"}}}"
  if [[ -n "$state_name" ]]; then
    filter_args=$(echo "$filter_args" | jq --arg s "$state_name" '.state = {name: {eq: $s}}')
  fi

  local vars
  vars=$(jq -n --argjson f "$filter_args" '{filter: $f, first: 100}')

  _tracker_linear_gql \
    'query($filter: IssueFilter!, $first: Int!) { issues(filter: $filter, first: $first) { nodes { id identifier title state { name } url } } }' \
    "$vars" \
    | jq '[.data.issues.nodes[] | {id: .identifier, title: .title, status: (.state.name | ascii_downcase | gsub(" "; "_")), url: .url}]'
}

tracker_linear_link_dep() {
  local issue_id="$1"
  local blocks_id="$2"

  # Linear's relation API: issueRelationCreate
  local vars
  vars=$(jq -n --arg iid "$issue_id" --arg bid "$blocks_id" \
    '{input: {issueId: $iid, relatedIssueId: $bid, type: "blocks"}}')

  local response
  response=$(_tracker_linear_gql \
    'mutation($input: IssueRelationCreateInput!) { issueRelationCreate(input: $input) { success } }' "$vars")

  local success
  success=$(echo "$response" | jq -r '.data.issueRelationCreate.success')
  if [[ "$success" != "true" ]]; then
    echo "ERROR: failed to link Linear issues" >&2
    echo "$response" >&2
    return 1
  fi

  _tracker_log "linear: $issue_id blocks $blocks_id"
  echo "{\"from\":\"$issue_id\",\"to\":\"$blocks_id\"}"
  return 0
}

export -f tracker_linear_init tracker_linear_create_issue tracker_linear_update_status \
          tracker_linear_add_comment tracker_linear_get_issue tracker_linear_list_issues \
          tracker_linear_link_dep _tracker_linear_read_config _tracker_linear_pick_mode \
          _tracker_linear_has_mcp _tracker_linear_has_token _tracker_linear_gql \
          _tracker_linear_state_name