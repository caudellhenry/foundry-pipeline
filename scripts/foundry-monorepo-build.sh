#!/usr/bin/env bash
# scripts/foundry-monorepo-build.sh
#
# Builds every package from packages/core/:
#   - claude-code, zcode: full rsync of core into the package
#   - skills-sh, hermes, opencode, antigravity, mimocode: symlink core's skills/ subdirs
# Also regenerates each package's .foundry-version-manifest.json (sha256 of every file).
#
# Idempotent. Pass DRY_RUN=1 to print without writing.

set -euo pipefail

DRY_RUN="${DRY_RUN:-0}"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CORE_DIR="$REPO_ROOT/packages/core"
VERSION="$(tr -d '[:space:]' < "$REPO_ROOT/VERSION")"

if [[ ! -d "$CORE_DIR" ]]; then
  echo "ERROR: $CORE_DIR not found." >&2
  exit 1
fi

run() {
  if [[ "$DRY_RUN" == "1" ]]; then
    printf '  DRY-RUN: %s\n' "$*"
  else
    eval "$@"
  fi
}

echo "Building foundry-pipeline monorepo @ v$VERSION (DRY_RUN=$DRY_RUN)"
echo ""

# 1. Sync version first
run "bash \"$REPO_ROOT/scripts/foundry-version-sync.sh\""

# 2. For each package, decide full-copy vs symlink
for pkg_dir in "$REPO_ROOT"/packages/*/; do
  pkg_name="$(basename "$pkg_dir")"
  echo "--- $pkg_name ---"

  case "$pkg_name" in
    core)
      echo "  (core — no copy needed)"
      ;;

    claude-code|zcode)
      # Full rsync of core into package (excluding package.json + .claude-plugin)
      for sub in skills agents tracker-adapters templates evals scripts lib; do
        src="$CORE_DIR/$sub"
        dst="$pkg_dir/$sub"
        if [[ -d "$src" ]]; then
          run "mkdir -p '$dst'"
          if [[ "$DRY_RUN" == "1" ]]; then
            printf '  DRY-RUN: rsync -a --delete %q/ %q/\n' "$src" "$dst"
          else
            rsync -a --delete "$src/" "$dst/"
            echo "  rsync $src → $dst"
          fi
        fi
      done
      ;;

    skills-sh|hermes|opencode|antigravity|mimocode)
      # Symlink only skills (these packages carry skills-only)
      run "mkdir -p '$pkg_dir/skills'"
      for skill_dir in "$CORE_DIR/skills/"*/; do
        [[ -d "$skill_dir" ]] || continue
        skill_name="$(basename "$skill_dir")"
        link_target="../../core/skills/$skill_name"
        link_path="$pkg_dir/skills/$skill_name"
        if [[ "$DRY_RUN" == "1" ]]; then
          printf '  DRY-RUN: ln -sfn %q %q\n' "$link_target" "$link_path"
        else
          ln -sfn "$link_target" "$link_path"
          echo "  symlink $link_path → $link_target"
        fi
      done
      ;;

    *)
      echo "  (unknown package — skipping)"
      ;;
  esac

  # 3. Generate .foundry-version-manifest.json (sha256 of every file under package, sorted)
  manifest="$pkg_dir/.foundry-version-manifest.json"
  if [[ "$DRY_RUN" == "1" ]]; then
    printf '  DRY-RUN: write manifest → %s\n' "${manifest#$REPO_ROOT/}"
  else
    cd "$pkg_dir"
    {
      echo "{"
      echo "  \"foundry_version\": \"$VERSION\","
      echo "  \"generated_at\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\","
      echo "  \"package\": \"$pkg_name\","
      echo "  \"files\": {"
      first=1
      while IFS= read -r -d '' f; do
        rel="${f#"$pkg_dir"/}"
        sha="$(shasum -a 256 "$f" 2>/dev/null | awk '{print $1}')"
        if [[ $first -eq 0 ]]; then echo ","; fi
        printf '    "%s": "%s"' "$rel" "$sha"
        first=0
      done < <(find . -type f \
                  -not -path "./node_modules/*" \
                  -not -path "./.git/*" \
                  -not -name ".foundry-version-manifest.json" \
                  -print0 | sort -z)
      echo ""
      echo "  }"
      echo "}"
    } > "$manifest"
    echo "  manifest → ${manifest#$REPO_ROOT/} ($(jq '.files | length' "$manifest") files)"
    cd "$REPO_ROOT"
  fi

  echo ""
done

echo "Build complete."
exit 0