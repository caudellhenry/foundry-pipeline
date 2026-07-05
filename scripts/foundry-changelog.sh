#!/usr/bin/env bash
# scripts/foundry-changelog.sh
#
# Generates (or prints) a Conventional-Commits-derived changelog section for the
# current VERSION range (defaults: last tag → HEAD).
#
# Categories: feat, fix, perf, refactor, docs, build, ci, chore, test, style
# Groups:     Added (feat), Fixed (fix), Performance (perf), Changed (refactor+style),
#             Docs (docs), Build (build), CI (ci), Tests (test), Chore (chore).

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

RANGE_FROM="${RANGE_FROM:-}"
RANGE_TO="${RANGE_TO:-HEAD}"

if [[ -z "$RANGE_FROM" ]]; then
  if git describe --tags --abbrev=0 >/dev/null 2>&1; then
    RANGE_FROM="$(git describe --tags --abbrev=0)"
  else
    RANGE_FROM="(initial commit)"
  fi
fi

emit_group() {
  local label="$1"
  local regex="$2"
  local -a commits
  mapfile -t commits < <(git log --pretty=format:"%h %s" "$RANGE_FROM..$RANGE_TO" 2>/dev/null \
                          | grep -E "$regex" || true)
  if [[ "${#commits[@]}" -gt 0 ]]; then
    echo "### $label"
    echo ""
    for c in "${commits[@]}"; do
      echo "- $c"
    done
    echo ""
  fi
}

echo "## Changelog: $RANGE_FROM → $RANGE_TO"
echo ""
emit_group "Added"      "^feat(\([^)]+\))?!?:"
emit_group "Fixed"      "^fix(\([^)]+\))?!?:"
emit_group "Performance" "^perf(\([^)]+\))?!?:"
emit_group "Changed"    "^(refactor|style)(\([^)]+\))?!?:"
emit_group "Docs"       "^docs(\([^)]+\))?!?:"
emit_group "Build"      "^build(\([^)]+\))?!?:"
emit_group "CI"         "^ci(\([^)]+\))?!?:"
emit_group "Tests"      "^test(\([^)]+\))?!?:"
emit_group "Chore"      "^chore(\([^)]+\))?!?:"

exit 0