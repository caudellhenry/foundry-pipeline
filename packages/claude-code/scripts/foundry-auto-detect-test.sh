#!/usr/bin/env bash
# foundry-auto-detect-test.sh — Detect test runner + commands from project files
#
# Inspects package.json, pyproject.toml, go.mod, Cargo.toml in the project root
# and emits a YAML block suitable for state.md frontmatter under the `test:` key.
#
# usage:
#   foundry-auto-detect-test.sh           # prints YAML to stdout
#   foundry-auto-detect-test.sh --apply   # also writes to .foundry/state.md (preserves other fields)
#
# Detection matrix:
#   package.json + jest   → runner=jest,   cmd="npm test --silent",  coverage="npm test -- --coverage --silent"
#   package.json + vitest → runner=vitest, cmd="npx vitest run",     coverage="npx vitest run --coverage"
#   package.json + mocha  → runner=mocha,  cmd="npm test",            coverage=""
#   pyproject.toml + pytest → runner=pytest, cmd="pytest -q",         coverage="pytest --cov=. --cov-report=term"
#   go.mod                → runner=go-test, cmd="go test ./...",      coverage="go test -cover ./..."
#   Cargo.toml            → runner=cargo-test, cmd="cargo test",      coverage="cargo test --no-fail-fast"
#   bun.lockb/package.json with "bun" → runner=bun,  cmd="bun test"
#
# Typecheck/lint heuristics:
#   TS in package.json dependencies         → typecheck_cmd="npx tsc --noEmit"
#   eslint in package.json devDependencies  → lint_cmd="npx eslint ."
#   ruff in pyproject                       → lint_cmd="ruff check ."
#   mypy in pyproject                       → typecheck_cmd="mypy ."
#   golangci-lint on PATH                   → lint_cmd="golangci-lint run"

set -euo pipefail

PROJECT_ROOT="${DEV_PIPELINE_PROJECT_ROOT:-$(pwd)}"
STATE_FILE="$PROJECT_ROOT/.foundry/state.md"

# Parse flags
APPLY="false"
for arg in "$@"; do
  case "$arg" in
    --apply) APPLY="true" ;;
    *) ;;
  esac
done

RUNNER="unknown"
CMD=""
COVERAGE_CMD=""
LINT_CMD=""
TYPECHECK_CMD=""

# --- Node / package.json ---
if [[ -f "$PROJECT_ROOT/package.json" ]]; then
  # Try to extract scripts.test
  if command -v jq >/dev/null 2>&1; then
    PACKAGE_TEST="$(jq -r '.scripts.test // ""' "$PROJECT_ROOT/package.json" 2>/dev/null || true)"
  else
    PACKAGE_TEST="$(grep -E '"test"[[:space:]]*:' "$PROJECT_ROOT/package.json" | sed -E 's/.*"test"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/' | head -1)"
  fi

  if grep -qE '"vitest"' "$PROJECT_ROOT/package.json" 2>/dev/null; then
    RUNNER="vitest"
    CMD="npx vitest run"
    COVERAGE_CMD="npx vitest run --coverage"
  elif grep -qE '"jest"' "$PROJECT_ROOT/package.json" 2>/dev/null; then
    RUNNER="jest"
    CMD="npx jest --silent"
    COVERAGE_CMD="npx jest --silent --coverage"
  elif grep -qE '"mocha"' "$PROJECT_ROOT/package.json" 2>/dev/null; then
    RUNNER="mocha"
    CMD="npx mocha"
    COVERAGE_CMD=""
  elif grep -qE '"bun"' "$PROJECT_ROOT/package.json" 2>/dev/null && [[ -f "$PROJECT_ROOT/bun.lockb" || -f "$PROJECT_ROOT/bun.lock" ]]; then
    RUNNER="bun"
    CMD="bun test"
    COVERAGE_CMD="bun test --coverage"
  elif [[ -n "$PACKAGE_TEST" ]]; then
    RUNNER="node-test"
    CMD="npm test"
  fi

  # Typecheck: TS?
  if grep -qE '"typescript"' "$PROJECT_ROOT/package.json" 2>/dev/null || [[ -f "$PROJECT_ROOT/tsconfig.json" ]]; then
    TYPECHECK_CMD="npx tsc --noEmit"
  fi
  # Lint: eslint?
  if grep -qE '"eslint"' "$PROJECT_ROOT/package.json" 2>/dev/null; then
    LINT_CMD="npx eslint ."
  fi
fi

# --- Python / pyproject.toml ---
if [[ -z "$CMD" && -f "$PROJECT_ROOT/pyproject.toml" ]]; then
  if grep -qE 'pytest' "$PROJECT_ROOT/pyproject.toml" 2>/dev/null; then
    RUNNER="pytest"
    CMD="pytest -q"
    COVERAGE_CMD="pytest --cov=. --cov-report=term -q"
  fi
  if grep -qE 'ruff' "$PROJECT_ROOT/pyproject.toml" 2>/dev/null; then
    LINT_CMD="ruff check ."
  fi
  if grep -qE 'mypy' "$PROJECT_ROOT/pyproject.toml" 2>/dev/null; then
    TYPECHECK_CMD="mypy ."
  fi
fi

# --- Go ---
if [[ -z "$CMD" && -f "$PROJECT_ROOT/go.mod" ]]; then
  RUNNER="go-test"
  CMD="go test ./..."
  COVERAGE_CMD="go test -cover ./..."
  if command -v golangci-lint >/dev/null 2>&1; then
    LINT_CMD="golangci-lint run"
  fi
fi

# --- Rust ---
if [[ -z "$CMD" && -f "$PROJECT_ROOT/Cargo.toml" ]]; then
  RUNNER="cargo-test"
  CMD="cargo test"
  COVERAGE_CMD="cargo test --no-fail-fast"
fi

# Emit YAML
cat <<EOF
runner: $RUNNER
cmd: "$CMD"
per_story_cmd_template: ""
timeout: 300
coverage_cmd: "$COVERAGE_CMD"
coverage_threshold: 0
coverage_baseline: null
lint_cmd: "$LINT_CMD"
typecheck_cmd: "$TYPECHECK_CMD"
skip_tests: false
cache_by_commit: true
EOF

# Apply to state.md if requested
if [[ "$APPLY" == "true" ]]; then
  if [[ ! -f "$STATE_FILE" ]]; then
    echo "ERROR: state.md not found at $STATE_FILE — run /dev first" >&2
    exit 1
  fi
  TMP="$(mktemp)"
  awk -v runner="$RUNNER" -v cmd="$CMD" -v cov_cmd="$COVERAGE_CMD" -v lint_cmd="$LINT_CMD" -v tc_cmd="$TYPECHECK_CMD" '
    BEGIN { in_test = 0 }
    /^test:/ { in_test = 1; print; next }
    in_test && /^  runner:/ { print "  runner: " runner; next }
    in_test && /^  cmd:/ { print "  cmd: \"" cmd "\""; next }
    in_test && /^  coverage_cmd:/ { print "  coverage_cmd: \"" cov_cmd "\""; next }
    in_test && /^  lint_cmd:/ { print "  lint_cmd: \"" lint_cmd "\""; next }
    in_test && /^  typecheck_cmd:/ { print "  typecheck_cmd: \"" tc_cmd "\""; next }
    in_test && /^[^ ]/ { in_test = 0 }
    { print }
  ' "$STATE_FILE" > "$TMP"
  mv "$TMP" "$STATE_FILE"
  echo "✓ test: block updated in $STATE_FILE"
fi