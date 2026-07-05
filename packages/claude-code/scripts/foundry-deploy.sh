#!/usr/bin/env bash
# foundry-deploy.sh — manage the project's GitHub deploy workflow.
#
# Subcommands:
#   init [TARGET]      detect (or accept) deploy target; write .github/workflows/deploy.yml;
#                      set deploy block in state.md; print required secrets.
#   status [PR_URL]    poll latest deploy for the PR (or HEAD run); print verdict.
#   verify [PR_URL]    exit 0 if deploy succeeded, exit 1 if failed, exit 2 if unknown.
#                      Used by the orchestrator's PR sub-loop as a gate.
#
# Targets: firebase | vercel | netlify | custom
#
# Init is idempotent and non-destructive: existing deploy.yml steps outside
# the `# === FOUNDRY_DEPLOY_STEPS_* ===` markers are preserved.

set -uo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
PROJECT_ROOT="${DEV_PIPELINE_PROJECT_ROOT:-$(pwd)}"
FOUNDRY_DIR="$PROJECT_ROOT/.foundry"
STATE_FILE="$FOUNDRY_DIR/state.md"
WORKFLOW_FILE="$PROJECT_ROOT/.github/workflows/deploy.yml"
TEMPLATE="$PLUGIN_ROOT/templates/deploy.yml"

# ──────────────────────────────────────────────────────────────────────────────
# Helpers
# ──────────────────────────────────────────────────────────────────────────────

# Detect the deploy target from project files (no user input required).
# Order of precedence:
#   1. firebase.json       → firebase
#   2. vercel.json         → vercel
#   3. netlify.toml        → netlify
#   4. Dockerfile          → custom (container)
#   5. nothing             → custom (placeholder)
detect_target() {
  if [[ -f "$PROJECT_ROOT/firebase.json" ]]; then echo "firebase"; return; fi
  if [[ -f "$PROJECT_ROOT/vercel.json" ]] || grep -q '"vercel"' "$PROJECT_ROOT/package.json" 2>/dev/null; then echo "vercel"; return; fi
  if [[ -f "$PROJECT_ROOT/netlify.toml" ]]; then echo "netlify"; return; fi
  if [[ -f "$PROJECT_ROOT/Dockerfile" ]] || [[ -f "$PROJECT_ROOT/docker-compose.yml" ]]; then echo "custom"; return; fi
  echo "custom"
}

# Read existing deploy target from state.md (returns empty if unset).
read_deploy_target() {
  awk '
    /^deploy:[[:space:]]*$/ { f=1; next }
    f && /^  target:[[:space:]]/ { print $2; exit }
  ' "$STATE_FILE" 2>/dev/null
}

# Update or insert the deploy block in state.md.
write_state_deploy() {
  local target="$1"
  local tmp
  tmp="$(mktemp)"
  awk -v target="$target" '
    /^deploy:[[:space:]]*$/ { print; print "  target: " target; print "  initialized_at: \"" strftime("%Y-%m-%dT%H:%M:%SZ", systime()) "\""; skip=1; next }
    skip && /^  / { next }
    skip && !/^  / { skip=0 }
    { print }
  ' "$STATE_FILE" > "$tmp" && mv "$tmp" "$STATE_FILE"

  # If `deploy:` block didn't exist at all, append it.
  if ! grep -q '^deploy:' "$STATE_FILE"; then
    cat >> "$STATE_FILE" <<EOF

deploy:
  target: $target
  initialized_at: "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
EOF
  fi
}

# Required secrets per target (used by `init` and `verify`).
target_secrets() {
  case "$1" in
    firebase) echo "FIREBASE_SERVICE_ACCOUNT GITHUB_TOKEN" ;;
    vercel)   echo "VERCEL_TOKEN VERCEL_ORG_ID VERCEL_PROJECT_ID" ;;
    netlify) echo "NETLIFY_AUTH_TOKEN NETLIFY_SITE_ID" ;;
    custom)   echo "(none — define your own in the workflow)" ;;
    *)        echo "" ;;
  esac
}

# Build the deploy steps block for a target. Writes to stdout.
target_deploy_steps() {
  case "$1" in
    firebase)
      cat <<'EOF'
      - name: Firebase Deploy
        uses: FirebaseExtended/action-hosting-deploy@v0
        with:
          repoToken: ${{ secrets.GITHUB_TOKEN }}
          firebaseServiceAccount: ${{ secrets.FIREBASE_SERVICE_ACCOUNT }}
          channelId: live
          projectId: ${{ vars.FOUNDRY_FIREBASE_PROJECT_ID }}
        env:
          DEPLOY_URL: https://${{ vars.FOUNDRY_FIREBASE_PROJECT_ID }}.web.app
EOF
      ;;
    vercel)
      cat <<'EOF'
      - name: Vercel Deploy
        run: npx vercel --prod --token=${{ secrets.VERCEL_TOKEN }}
        env:
          DEPLOY_URL: ${{ steps.deploy.outputs.preview-url }}
      - name: Capture URL
        id: deploy
        run: echo "preview-url=$(npx vercel --token=${{ secrets.VERCEL_TOKEN }} ls --json | jq -r '.[0].url')" >> $GITHUB_OUTPUT
EOF
      ;;
    netlify)
      cat <<'EOF'
      - name: Netlify Deploy
        run: npx netlify deploy --prod --auth=${{ secrets.NETLIFY_AUTH_TOKEN }} --site=${{ secrets.NETLIFY_SITE_ID }}
        env:
          DEPLOY_URL: https://${{ secrets.NETLIFY_SITE_ID }}.netlify.app
EOF
      ;;
    custom)
      cat <<'EOF'
      - name: Custom Deploy
        run: |
          echo "TODO: replace with your deploy steps"
          echo "(e.g., docker build + push, or kubectl apply, or rsync, etc.)"
          exit 1
EOF
      ;;
    *)
      echo "      # ERROR: unknown target '$1'" >&2
      return 1
      ;;
  esac
}

# Replace the FOUNDRY_DEPLOY_STEPS block in deploy.yml with new steps.
# Preserves everything outside the markers. Uses a temp file for the multi-line
# steps content (awk's -v warns on newline in string).
update_deploy_workflow() {
  local target="$1"
  local tmp steps_tmp
  tmp="$(mktemp)"
  steps_tmp="$(mktemp)"
  # shellcheck disable=SC2064
  trap "rm -f '$tmp' '$steps_tmp'" RETURN

  if [[ ! -f "$WORKFLOW_FILE" ]]; then
    # No existing workflow — copy the template as-is, then we'll patch below.
    mkdir -p "$(dirname "$WORKFLOW_FILE")"
    cp "$TEMPLATE" "$WORKFLOW_FILE"
  fi

  target_deploy_steps "$target" > "$steps_tmp"

  # Insert the steps file's content between the markers. We use awk to
  # stream-read the steps file when we hit the START marker and switch back
  # to streaming the input file at the END marker.
  awk -v steps_file="$steps_tmp" '
    /^      # === FOUNDRY_DEPLOY_STEPS_START ===$/ {
      print
      while ((getline line < steps_file) > 0) print line
      close(steps_file)
      skip=1
      next
    }
    /^      # === FOUNDRY_DEPLOY_STEPS_END ===$/ {
      skip=0
      print
      next
    }
    skip { next }
    { print }
  ' "$WORKFLOW_FILE" > "$tmp" && mv "$tmp" "$WORKFLOW_FILE"
}

# ──────────────────────────────────────────────────────────────────────────────
# Subcommands
# ──────────────────────────────────────────────────────────────────────────────

cmd_init() {
  local target="${1:-}"
  if [[ -z "$target" ]]; then
    target=$(detect_target)
    echo "Detected deploy target: $target"
  fi
  case "$target" in
    firebase|vercel|netlify|custom) ;;
    *) echo "ERROR: unknown target '$target' (expected firebase|vercel|netlify|custom)" >&2; exit 2 ;;
  esac

  # Replace the deploy steps block in the workflow file.
  if [[ -f "$TEMPLATE" ]]; then
    mkdir -p "$(dirname "$WORKFLOW_FILE")"
    if [[ ! -f "$WORKFLOW_FILE" ]]; then
      cp "$TEMPLATE" "$WORKFLOW_FILE"
    fi
    update_deploy_workflow "$target"
  else
    echo "ERROR: template not found at $TEMPLATE" >&2
    exit 1
  fi

  # Update state.md.
  if [[ -d "$FOUNDRY_DIR" ]]; then
    write_state_deploy "$target"
  fi

  # Surface the required secrets (the user must set these manually in GH repo settings).
  echo ""
  echo "✓ Deploy workflow configured for target: $target"
  echo "  Wrote: $WORKFLOW_FILE"
  echo ""
  echo "Required secrets (set in GitHub repo Settings → Secrets and variables → Actions):"
  for s in $(target_secrets "$target"); do
    echo "  - $s"
  done
  echo ""
  echo "Required variables (set in GitHub repo Settings → Secrets and variables → Variables):"
  case "$target" in
    firebase) echo "  - FOUNDRY_FIREBASE_PROJECT_ID (your Firebase project ID)" ;;
    *) echo "  - (none)" ;;
  esac
}

cmd_status() {
  local pr_url="${1:-}"
  if ! command -v gh >/dev/null 2>&1; then
    echo "ERROR: 'gh' CLI not installed" >&2
    exit 2
  fi
  if [[ -n "$pr_url" ]]; then
    gh pr checks "$pr_url" 2>&1
  else
    gh run list --workflow=deploy.yml --limit=1 --json status,conclusion,name,url,headBranch,createdAt 2>&1
  fi
}

cmd_verify() {
  local pr_url="${1:-}"
  if ! command -v gh >/dev/null 2>&1; then
    echo "ERROR: 'gh' CLI not installed" >&2
    exit 2
  fi
  if [[ -z "$pr_url" ]]; then
    echo "ERROR: verify requires a PR URL (e.g., https://github.com/owner/repo/pull/42)" >&2
    exit 2
  fi

  # Get the latest run for this PR's deploy workflow.
  local runs_json
  runs_json=$(gh pr checks "$pr_url" 2>/dev/null || echo "[]")

  # Look for the "deploy" check; success means deploy succeeded.
  local deploy_status
  deploy_status=$(echo "$runs_json" | jq -r '.[] | select(.name | test("[Dd]eploy"; "g")) | .conclusion' | head -1)

  case "$deploy_status" in
    success)
      echo "✓ Deploy succeeded for $pr_url"
      exit 0
      ;;
    failure|cancelled|skipped|timed_out)
      echo "✗ Deploy $deploy_status for $pr_url" >&2
      exit 1
      ;;
    "")
      # No deploy check found — is there a deploy target configured?
      local target
      target=$(read_deploy_target)
      if [[ -z "$target" || "$target" == "none" ]]; then
        echo "(no deploy target configured — verify SKIP)" >&2
        exit 2  # orchestrator treats 2 as SKIP (same as verify.sh pr)
      else
        echo "✗ No deploy check found for $pr_url (target=$target)" >&2
        exit 1
      fi
      ;;
    *)
      echo "? Deploy status unknown: $deploy_status" >&2
      exit 2
      ;;
  esac
}

cmd_help() {
  cat <<'EOF'
foundry-deploy.sh — manage the project's GitHub deploy workflow.

Subcommands:
  init [TARGET]      detect (or accept) deploy target; write .github/workflows/deploy.yml;
                    set deploy block in state.md; print required secrets.
                    TARGET: firebase | vercel | netlify | custom (auto-detected if omitted)
  status [PR_URL]    poll latest deploy (or all checks on a PR)
  verify [PR_URL]    exit 0 if deploy succeeded, 1 if failed, 2 if unknown/SKIP
  help               show this message

Examples:
  foundry-deploy.sh init                       # auto-detect target
  foundry-deploy.sh init firebase              # force Firebase target
  foundry-deploy.sh status                     # show latest deploy
  foundry-deploy.sh verify https://github.com/me/repo/pull/42
EOF
}

# ──────────────────────────────────────────────────────────────────────────────
# Dispatch
# ──────────────────────────────────────────────────────────────────────────────

case "${1:-help}" in
  init)    shift; cmd_init "$@" ;;
  status)  shift; cmd_status "$@" ;;
  verify)  shift; cmd_verify "$@" ;;
  help|-h|--help) cmd_help ;;
  *) echo "ERROR: unknown subcommand '$1' (try 'help')" >&2; exit 2 ;;
esac