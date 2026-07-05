#!/usr/bin/env bash
# packages/core/scripts/foundry-patch-push.sh
#
# Push local foundry-pipeline edits to canonical caudellhenry/foundry-pipeline
# via a pull request. Walks the user through:
#   1. Fork detection (auto-fork if missing)
#   2. Branch creation (patch/<user>/<date>-<short-desc>)
#   3. Diff application on top of v$VERSION
#   4. Eval gate (bash evals/run.sh --release-check)
#   5. PR creation (gh pr create with auto-filled template)
#
# Flags:
#   --message=<commit-msg>   Override default commit message
#   --fork=<gh-user>         Override fork detection
#   --skip-evals             Skip the eval gate (DANGEROUS — not recommended)
#   --dry-run                Print what would happen without doing anything
#   --install-dir=DIR        Override install dir detection

set -uo pipefail

CANONICAL_REPO="caudellhenry/foundry-pipeline"

# Parse flags
MESSAGE=""
FORK_OVERRIDE=""
SKIP_EVALS=0
DRY_RUN=0
INSTALL_DIR=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --message=*)        MESSAGE="${1#--message=}"; shift ;;
    --fork=*)           FORK_OVERRIDE="${1#--fork=}"; shift ;;
    --skip-evals)       SKIP_EVALS=1; shift ;;
    --dry-run)          DRY_RUN=1; shift ;;
    --install-dir=*)    INSTALL_DIR="${1#--install-dir=}"; shift ;;
    *) echo "Unknown flag: $1" >&2; exit 2 ;;
  esac
done

# Resolve install dir
if [[ -z "$INSTALL_DIR" ]]; then
  SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  INSTALL_DIR="$(cd "$SCRIPT_PATH/../.." && pwd)"
fi

# Detect harness (for PR template)
HARNESS="${HARNESS:-unknown}"
case "$INSTALL_DIR" in
  */claude-code/*) HARNESS="claude-code" ;;
  */zcode/*)       HARNESS="zcode" ;;
  */hermes/*)      HARNESS="hermes" ;;
  */opencode/*)    HARNESS="opencode" ;;
  */antigravity/*) HARNESS="antigravity" ;;
  */mimocode/*)    HARNESS="mimocode" ;;
  */skills-sh/*)   HARNESS="skills-sh" ;;
esac

# Get current gh user
GH_USER=$(gh api user --jq .login 2>/dev/null || echo "")
if [[ -z "$GH_USER" ]]; then
  echo "ERROR: could not detect GitHub user. Run 'gh auth login' first." >&2
  exit 1
fi

# Get current version
if [[ -f "$INSTALL_DIR/VERSION" ]]; then
  VERSION="$(tr -d '[:space:]' < "$INSTALL_DIR/VERSION")"
else
  echo "ERROR: VERSION file not found at $INSTALL_DIR/VERSION" >&2
  exit 1
fi

# Detect fork
FORK="$FORK_OVERRIDE"
if [[ -z "$FORK" ]]; then
  echo "Checking fork status..."
  if gh repo view "${GH_USER}/${CANONICAL_REPO}" >/dev/null 2>&1; then
    FORK="$GH_USER"
    echo "Found existing fork: ${FORK}/${CANONICAL_REPO}"
  else
    echo "No fork of ${CANONICAL_REPO} found at ${GH_USER}/."
    read -r -p "Fork ${CANONICAL_REPO} to your account? [y/N] " response
    if [[ "$response" =~ ^[Yy]$ ]]; then
      if [[ "$DRY_RUN" -eq 1 ]]; then
        echo "DRY-RUN: gh repo fork ${CANONICAL_REPO} --clone=false"
        FORK="$GH_USER"
      else
        gh repo fork "${CANONICAL_REPO}" --clone=false >/dev/null
        FORK="$GH_USER"
      fi
    else
      echo "Cancelled."
      exit 1
    fi
  fi
fi

# Branch name
DATE=$(date -u +%Y-%m-%d)
SHORT_DESC="local-patch"
if [[ -n "$MESSAGE" ]]; then
  SHORT_DESC=$(echo "$MESSAGE" | head -1 | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g' | sed -E 's/^-|-$//g' | cut -c1-50)
fi
BRANCH="patch/${GH_USER}/${DATE}-${SHORT_DESC}"

# Compute diff (against v$VERSION)
echo "Computing diff against canonical v$VERSION..."
DIFF_FILE="/tmp/foundry-patch-$$.diff"

if [[ -d "$INSTALL_DIR/.git" ]]; then
  # git-aware
  git -C "$INSTALL_DIR" diff "v${VERSION}..HEAD" > "$DIFF_FILE" 2>/dev/null || echo "" > "$DIFF_FILE"
  FILES_TOUCHED=$(git -C "$INSTALL_DIR" diff --name-only "v${VERSION}..HEAD" | wc -l | tr -d ' ')
else
  # file-checksum mode — just compute which files differ
  manifest=$(curl -sSfL "https://raw.githubusercontent.com/${CANONICAL_REPO}/v${VERSION}/packages/claude-code/.foundry-version-manifest.json" 2>/dev/null || echo "")
  diff -ruN "/tmp/foundry-empty" "$INSTALL_DIR" > "$DIFF_FILE" 2>/dev/null || echo "" > "$DIFF_FILE"
  FILES_TOUCHED=0
fi

if [[ ! -s "$DIFF_FILE" ]]; then
  echo "ERROR: no local changes detected. Run /foundry:patch-check first." >&2
  rm -f "$DIFF_FILE"
  exit 1
fi

echo "Found $FILES_TOUCHED changed file(s)."

# Eval gate
if [[ "$SKIP_EVALS" -eq 0 ]]; then
  echo "Running eval gate..."
  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "DRY-RUN: bash evals/run.sh --release-check (would run)"
  else
    (cd "$INSTALL_DIR/.." && bash evals/run.sh --release-check) || {
      echo "EVAL GATE FAILED. Aborting push." >&2
      echo "Fix the failing scenarios and retry, or pass --skip-evals (not recommended)." >&2
      rm -f "$DIFF_FILE"
      exit 1
    }
  fi
fi

# Clone fork into a working dir
WORK_DIR="/tmp/foundry-patch-work-$$"
echo "Cloning fork into $WORK_DIR..."
if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "DRY-RUN: gh repo clone ${FORK}/${CANONICAL_REPO} $WORK_DIR"
else
  gh repo clone "${FORK}/${CANONICAL_REPO}" "$WORK_DIR" >/dev/null 2>&1 || {
    echo "ERROR: failed to clone fork" >&2
    rm -f "$DIFF_FILE"
    exit 1
  }
fi

# Checkout base + create branch
if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "DRY-RUN: git -C $WORK_DIR checkout v${VERSION} && git checkout -b ${BRANCH}"
else
  (cd "$WORK_DIR" && git checkout "v${VERSION}" >/dev/null 2>&1 && git checkout -b "$BRANCH" >/dev/null 2>&1) || {
    echo "ERROR: failed to checkout base + branch" >&2
    rm -rf "$WORK_DIR" "$DIFF_FILE"
    exit 1
  }
fi

# Apply diff
echo "Applying diff..."
if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "DRY-RUN: git apply $DIFF_FILE"
else
  (cd "$WORK_DIR" && git apply "$DIFF_FILE") || {
    echo "ERROR: failed to apply diff (conflicts?)" >&2
    rm -rf "$WORK_DIR" "$DIFF_FILE"
    exit 1
  }
fi

# Commit
COMMIT_MSG="${MESSAGE:-chore(patch): local edits from ${HARNESS} install

Source harness: ${HARNESS}
Source version: v${VERSION}
Files touched: ${FILES_TOUCHED}
}"
if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "DRY-RUN: git commit -m '$COMMIT_MSG'"
else
  (cd "$WORK_DIR" && git add -A && git commit -m "$COMMIT_MSG") || {
    echo "ERROR: commit failed" >&2
    rm -rf "$WORK_DIR" "$DIFF_FILE"
    exit 1
  }
fi

# Push branch
if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "DRY-RUN: git push origin $BRANCH"
else
  (cd "$WORK_DIR" && git push origin "$BRANCH" --force-with-lease) || {
    echo "ERROR: push failed" >&2
    rm -rf "$WORK_DIR" "$DIFF_FILE"
    exit 1
  }
fi

# Open PR
PR_BODY=$(cat <<EOF
## Local patch

- **Source harness**: ${HARNESS}
- **Source version**: v${VERSION}
- **Files touched**: ${FILES_TOUCHED}
- **Author**: @${GH_USER}

## Checklist

- [ ] I have read [CONTRIBUTING.md](../blob/main/CONTRIBUTING.md)
- [ ] I have run \`bash scripts/foundry-self-test.sh\` locally
- [ ] My changes follow the conventional-commits format
EOF
)

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "DRY-RUN: gh pr create --repo ${CANONICAL_REPO} --base main --head ${FORK}:${BRANCH} --title '...' --body '...'"
  echo "Would open PR against ${CANONICAL_REPO}:main from ${FORK}:${BRANCH}"
else
  (cd "$WORK_DIR" && gh pr create \
    --repo "${CANONICAL_REPO}" \
    --base main \
    --head "${FORK}:${BRANCH}" \
    --title "${MESSAGE:-Local patch from ${HARNESS} v${VERSION}}" \
    --body "$PR_BODY") || {
    echo "ERROR: PR creation failed" >&2
    rm -rf "$WORK_DIR" "$DIFF_FILE"
    exit 1
  }
fi

# Cleanup
rm -rf "$WORK_DIR" "$DIFF_FILE"
echo ""
echo "Patch push complete."
exit 0