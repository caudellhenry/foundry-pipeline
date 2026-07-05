#!/usr/bin/env bash
# foundry-cleanup.sh — archive per-sprint research and rotated phase logs

set -euo pipefail

PROJECT_ROOT="${DEV_PIPELINE_PROJECT_ROOT:-$(pwd)}"
FOUNDRY_DIR="$PROJECT_ROOT/.foundry"
ARCHIVE="$FOUNDRY_DIR/_archive"

mkdir -p "$ARCHIVE"

TS="$(date -u +"%Y%m%dT%H%M%SZ")"

# Archive research notes whose expiry has passed
if [[ -d "$FOUNDRY_DIR/research" ]]; then
  for f in "$FOUNDRY_DIR/research/"*.md; do
    [[ -f "$f" ]] || continue
    if grep -qE '^expires:[[:space:]]*[0-9-]+' "$f"; then
      EXPIRES="$(grep -E '^expires:' "$f" | sed 's/expires:[[:space:]]*//' | head -1)"
      NOW="$(date -u +"%Y-%m-%d")"
      if [[ "$EXPIRES" < "$NOW" ]]; then
        mv "$f" "$ARCHIVE/${TS}-$(basename "$f")"
        echo "archived expired research: $f"
      fi
    fi
  done
fi

# Rotate logs larger than 1MB
if [[ -d "$FOUNDRY_DIR/logs" ]]; then
  for f in "$FOUNDRY_DIR/logs/"*.log; do
    [[ -f "$f" ]] || continue
    SIZE=$(wc -c < "$f" | tr -d ' ')
    if [[ "$SIZE" -gt 1048576 ]]; then  # 1MB
      mv "$f" "$ARCHIVE/${TS}-$(basename "$f")"
      echo "rotated large log: $f"
    fi
  done
fi

echo "cleanup done."