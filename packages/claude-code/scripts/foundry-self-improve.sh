#!/usr/bin/env bash
# foundry-self-improve.sh — wrapper that runs the skill-improver meta-skill
#
# Usage: foundry-self-improve.sh [--since YYYY-MM-DD] [--commit]
#
# Stages 1-3 always; Stage 5 (commit) only with --commit.

set -euo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
SKILL_IMPROVER="${SKILL_IMPROVER:-$HOME/.zcode/skills/skill-improver}"
# Default workspace: Agents Workspace (where Skills/ and Knowledge Base/ live)
WORKSPACE="${WORKSPACE:-/Users/henrycaudell/Agents Workspace}"

# Fallback: SKILL_IMPROVER might be a symlink; resolve to find scripts
if [[ ! -x "$SKILL_IMPROVER/scripts/capture.sh" ]]; then
  # Try the canonical source path
  if [[ -x "/Users/henrycaudell/Agents Workspace/Skills/skill-improver/scripts/capture.sh" ]]; then
    SKILL_IMPROVER="/Users/henrycaudell/Agents Workspace/Skills/skill-improver"
  else
    echo "ERROR: skill-improver not found at $SKILL_IMPROVER" >&2
    echo "Set SKILL_IMPROVER env var or install the skill first." >&2
    exit 1
  fi
fi

SINCE="$(date -u +"%Y-%m-%d" -v-7d 2>/dev/null || date -u -d "7 days ago" +"%Y-%m-%d" 2>/dev/null || date -u +"%Y-%m-%d")"
COMMIT="false"
TMPDIR_LOCAL="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_LOCAL"' EXIT

while [[ $# -gt 0 ]]; do
  case "$1" in
    --since) SINCE="${2:-}"; shift 2 ;;
    --commit) COMMIT="true" ;;
    -h|--help) cat <<'EOF'
usage: foundry-self-improve.sh [--since YYYY-MM-DD] [--commit]
EOF
      exit 0
      ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

echo "============================================="
echo "/foundry-self-improve — skill-improver wrapper"
echo "============================================="
echo ""
echo "skill-improver: $SKILL_IMPROVER"
echo "workspace:      $WORKSPACE"
echo "since:          $SINCE"
echo "commit:         $COMMIT"
echo ""

# Stage 1 — capture
echo "▶ Stage 1: capture"
bash "$SKILL_IMPROVER/scripts/capture.sh" \
  --since "$SINCE" \
  --workspace "$WORKSPACE" \
  --out "$TMPDIR_LOCAL/capture.json" >/dev/null
CAPTURE="$TMPDIR_LOCAL/capture.json"

python3 -c "
import json
with open('$CAPTURE') as f:
    d = json.load(f)
counts = d['counts']
print('  captured: ' + ', '.join(f'{k}={v}' for k, v in counts.items()))
"

echo ""

# Stage 2 — classify
echo "▶ Stage 2: classify"
bash "$SKILL_IMPROVER/scripts/classify.sh" "$CAPTURE" > "$TMPDIR_LOCAL/classify.json"
CLASSIFY="$TMPDIR_LOCAL/classify.json"

python3 -c "
import json
with open('$CLASSIFY') as f:
    d = json.load(f)
s = d['summary']
print(f'  patterns matched: {s[\"patterns_matched\"]}, total matches: {s[\"total_match_count\"]}')
top = sorted(d['patterns'].items(), key=lambda kv: -kv[1]['matches'])[:5]
for k, v in top:
    if v['matches'] > 0:
        print(f'    - {k}: {v[\"matches\"]}')
"

echo ""

# Stage 3 — propose
echo "▶ Stage 3: propose"
DRAFT="$WORKSPACE/.skill-improver/$(date -u +"%Y-%m-%d")-improvements.md"
mkdir -p "$(dirname "$DRAFT")"
bash "$SKILL_IMPROVER/scripts/propose.sh" "$CLASSIFY" --out "$DRAFT"
echo "  draft: $DRAFT"
echo ""

# Stage 4 — review
echo "▶ Stage 4: review (manual)"
echo ""
echo "  → Open the draft: $DRAFT"
echo "  → Approve / edit / reject each entry."
echo "  → Re-run with --commit when ready."
echo ""

if [[ "$COMMIT" == "true" ]]; then
  echo "▶ Stage 5: commit"
  bash "$SKILL_IMPROVER/scripts/commit.sh" "$DRAFT"
  echo ""
  echo "Done. Approved entries appended to Knowledge Base/analysis/.learnings/."
else
  echo "(Pass --commit to also append approved entries to the Knowledge Base.)"
fi

exit 0