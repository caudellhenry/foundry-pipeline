#!/usr/bin/env bash
# foundry-init.sh — bootstrap .foundry/ in the current project

set -euo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
PROJECT_ROOT="${DEV_PIPELINE_PROJECT_ROOT:-$(pwd)}"
FOUNDRY_DIR="$PROJECT_ROOT/.foundry"
TEMPLATES="$PLUGIN_ROOT/templates"

QUIET="false"
INTENT=""
# Parse flags safely: only `--key=value` style for values, or trailing positional.
i=1
while [[ $i -le $# ]]; do
  arg="${!i}"
  case "$arg" in
    --quiet|-q) QUIET="true" ;;
    --intent=*) INTENT="${arg#--intent=}" ;;
    --intent)
      i=$((i+1))
      if [[ $i -le $# ]]; then
        INTENT="${!i}"
      fi
      ;;
    *) ;;
  esac
  i=$((i+1))
done

mkdir -p "$FOUNDRY_DIR" \
         "$FOUNDRY_DIR/logs" \
         "$FOUNDRY_DIR/idea" \
         "$FOUNDRY_DIR/research" \
         "$FOUNDRY_DIR/prototype" \
         "$FOUNDRY_DIR/plan/stories" \
         "$FOUNDRY_DIR/tdd" \
         "$FOUNDRY_DIR/qa/evidence" \
         "$FOUNDRY_DIR/qa/review" \
         "$FOUNDRY_DIR/literate" \
         "$FOUNDRY_DIR/eval/scenarios" \
         "$FOUNDRY_DIR/eval/results"

# Copy templates on first bootstrap only (don't overwrite user state)
if [[ ! -f "$FOUNDRY_DIR/state.md" ]]; then
  cp "$TEMPLATES/state.md" "$FOUNDRY_DIR/state.md"
fi
if [[ ! -f "$FOUNDRY_DIR/idea/intent.md" ]]; then
  cp "$TEMPLATES/intent.md" "$FOUNDRY_DIR/idea/intent.md"
fi
if [[ ! -f "$FOUNDRY_DIR/idea/risks.md" ]]; then
  cp "$TEMPLATES/risks.md" "$FOUNDRY_DIR/idea/risks.md"
fi
if [[ ! -f "$FOUNDRY_DIR/prd.md" ]]; then
  cp "$TEMPLATES/prd.md" "$FOUNDRY_DIR/prd.md"
fi
if [[ ! -f "$FOUNDRY_DIR/research/research.md" ]]; then
  cp "$TEMPLATES/research.md" "$FOUNDRY_DIR/research/research.md"
fi
if [[ ! -f "$FOUNDRY_DIR/prototype/notes.md" ]]; then
  cp "$TEMPLATES/prototype-notes.md" "$FOUNDRY_DIR/prototype/notes.md"
fi
if [[ ! -f "$FOUNDRY_DIR/plan/features.md" ]]; then
  cp "$TEMPLATES/features.md" "$FOUNDRY_DIR/plan/features.md"
fi
if [[ ! -f "$FOUNDRY_DIR/plan/board.md" ]]; then
  cp "$TEMPLATES/board.md" "$FOUNDRY_DIR/plan/board.md"
fi
if [[ ! -f "$FOUNDRY_DIR/eval/scenarios/example-add-a-button.yaml" ]]; then
  cp "$TEMPLATES/eval-scenario.yaml" "$FOUNDRY_DIR/eval/scenarios/example-add-a-button.yaml"
fi

# If an intent was passed, write it into intent.md
if [[ -n "$INTENT" ]]; then
  TS="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  TMP="$(mktemp)"
  awk -v intent="$INTENT" -v ts="$TS" '
    /^created:/ { print "created: " ts; next }
    /^updated:/ { print "updated: " ts; next }
    /^## Who/ { print "## Who\n\n_(to be filled by grill-me interview)_\n"; in_block=1; next }
    /^## What/ { in_block=0 }
    in_block && /_\(to be filled by grill-me interview\)_/ { next }
    { print }
    END { print "\n## Initial intent (from /dev argument)\n\n> " intent "\n" }
  ' "$FOUNDRY_DIR/idea/intent.md" > "$TMP"
  mv "$TMP" "$FOUNDRY_DIR/idea/intent.md"
fi

# Ensure current_phase starts at idea on a fresh bootstrap
if ! grep -q '^current_phase:' "$FOUNDRY_DIR/state.md"; then
  printf '\ncurrent_phase: idea\n' >> "$FOUNDRY_DIR/state.md"
fi

# Auto-detect test runner + pre-populate test: block on first bootstrap
if [[ -x "$PLUGIN_ROOT/scripts/foundry-auto-detect-test.sh" ]]; then
  if ! grep -qE '^  cmd: "[^"]' "$FOUNDRY_DIR/state.md" 2>/dev/null; then
    DETECTED="$(DEV_PIPELINE_PROJECT_ROOT="$PROJECT_ROOT" bash "$PLUGIN_ROOT/scripts/foundry-auto-detect-test.sh" 2>/dev/null || true)"
    if [[ -n "$DETECTED" ]]; then
      # Build a temp file with the YAML block and splice it in under "test:"
      TMP="$(mktemp)"
      {
        awk '/^test:/{print; flag=1; next} flag && /^  cmd: ""/{found=1} /^[^ ]/ && /:/ && !/^test:/ && flag && found {flag=0} flag{next} {print}' "$FOUNDRY_DIR/state.md" > "$TMP.src"
        cat "$TMP.src"
      } 2>/dev/null || true
      rm -f "$TMP.src"
      # Simpler approach: rewrite the test: block directly
      TMP="$(mktemp)"
      DETECTED_FILE="$(mktemp)"
      printf '%s\n' "$DETECTED" > "$DETECTED_FILE"
      awk -v dfile="$DETECTED_FILE" '
        BEGIN { in_test=0 }
        /^test:/ { print; in_test=1; next }
        in_test && /^  [a-z_]+:/ {
          key = $0; sub(/^  /, "", key); sub(/:.*/, "", key)
          line = ""
          while ((getline dl < dfile) > 0) {
            if (dl ~ "^  "key":") { line = dl; break }
          }
          close(dfile)
          if (line != "") print line
          else print $0
          next
        }
        in_test && /^[^ ]/ { in_test=0 }
        { print }
      ' "$FOUNDRY_DIR/state.md" > "$TMP"
      mv "$TMP" "$FOUNDRY_DIR/state.md"
      rm -f "$DETECTED_FILE"
    fi
  fi
fi

TS="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
mkdir -p "$FOUNDRY_DIR/logs"
printf '%s\tbootstrap\tproject=%s\tintent=%s\n' "$TS" "$PROJECT_ROOT" "${INTENT:-none}" >> "$FOUNDRY_DIR/logs/bootstrap.log"

if [[ "$QUIET" != "true" ]]; then
  cat <<EOF
dev-pipeline bootstrapped at $FOUNDRY_DIR

  current_phase : idea
  auto_loop     : false
  intent        : ${INTENT:-none}

Next: invoke the Phase 1 skill with
  Use the Skill tool with skill name "foundry-idea"
EOF
fi

exit 0