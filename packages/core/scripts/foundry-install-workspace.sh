#!/usr/bin/env bash
# packages/core/scripts/foundry-install-workspace.sh
#
# Workspace install pattern — ONE canonical clone, symlinks into every
# harness plugin dir (home + workspace). `git pull` in the clone updates
# every harness at once.
#
# Default source: $WORKSPACE/Skills/foundry-pipeline
# Default workspace root: $HOME/Agents Workspace
#
# Flags:
#   --source=<dir>        Canonical clone (default: $WORKSPACE/Skills/foundry-pipeline)
#   --workspace=<dir>     Workspace root (default: $HOME/Agents Workspace)
#   --copy                Copy instead of symlink (same as FOUNDRY_INSTALL_COPY=1)
#   --home-only           Only install to $HOME/<harness>/...
#   --workspace-only      Only install to $WORKSPACE/<dot-harness>/...
#   --harness=<name>      Restrict to one harness (e.g. antigravity)
#   -h, --help            Show this help
#
# Idempotent: re-running updates the symlinks in place.

set -uo pipefail

CANONICAL_REPO="caudellhenry/foundry-pipeline"
PLUGIN_NAME="foundry-pipeline"

# Harness registry — entry per harness:
#   <harness_id>|<package_subdir>|<home_subdir>|<workspace_subdir>
# home_subdir / workspace_subdir use a {ver} placeholder for the version.
# Both home and workspace paths are prefixed with the dotted harness dir
# (e.g. .claude/, .zcode/) — that's where each harness looks.
HARVESTS=(
  "claude-code|claude-code|.claude/plugins/cache/{ver}|.claude/plugins/cache/{ver}"
  "zcode|zcode|.zcode/cli/plugins/cache/{ver}|.zcode/cli/plugins/cache/{ver}"
  "hermes|hermes|.hermes/skills/foundry-*|.hermes/skills/foundry-*"
  "opencode|opencode|.opencode/skills/foundry-*|.opencode/skills/foundry-*"
  "antigravity|antigravity|.antigravity/plugins/{ver}|.antigravity/plugins/{ver}"
  "mimocode|mimocode|.mimocode/plugins/{ver}|.mimocode/plugins/{ver}"
  "skills-sh|skills-sh|.skills-sh/skills/foundry-*|.skills-sh/skills/foundry-*"
  "minimax|minimax|.minimax/skills/foundry-*|.minimax/skills/foundry-*"
  "cursor|cursor|.cursor/skills/foundry-*|.cursor/skills/foundry-*"
  "codex|codex|.codex/skills/foundry-*|.codex/skills/foundry-*"
  "windsurf|windsurf|.windsurf/skills/foundry-*|.windsurf/skills/foundry-*"
  "cline|cline|.cline/skills/foundry-*|.cline/skills/foundry-*"
  "gemini|gemini|.gemini/skills/foundry-*|.gemini/skills/foundry-*"
)

SOURCE_DIR=""
WORKSPACE_DIR=""
HOME_ONLY=0
WORKSPACE_ONLY=0
HARNESS_FILTER=""

# Force copy via flag OR env
COPY_MODE="${FOUNDRY_INSTALL_COPY:-0}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --source=*)        SOURCE_DIR="${1#--source=}"; shift ;;
    --workspace=*)     WORKSPACE_DIR="${1#--workspace=}"; shift ;;
    --copy)            COPY_MODE=1; shift ;;
    --home-only)       HOME_ONLY=1; shift ;;
    --workspace-only)  WORKSPACE_ONLY=1; shift ;;
    --harness=*)       HARNESS_FILTER="${1#--harness=}"; shift ;;
    -h|--help)
      cat <<'HELP'
foundry-install-workspace.sh — workspace install pattern

Usage:
  foundry-install-workspace.sh [flags]

Flags:
  --source=<dir>        Canonical clone (default: $WORKSPACE/Skills/foundry-pipeline)
  --workspace=<dir>     Workspace root (default: $HOME/Agents Workspace)
  --copy                Copy instead of symlink (same as FOUNDRY_INSTALL_COPY=1)
  --home-only           Only install to $HOME/<harness>/...
  --workspace-only      Only install to $WORKSPACE/<dot-harness>/...
  --harness=<name>      Restrict to one harness
  -h, --help            Show this help

Supported harnesses (13):
  claude-code  zcode  hermes  opencode  antigravity  mimocode  skills-sh
  minimax  cursor  codex  windsurf  cline  gemini

Escape hatch:
  FOUNDRY_INSTALL_COPY=1   force copy instead of symlink

Idempotent — re-running just refreshes symlinks.
HELP
      exit 0
      ;;
    *) echo "Unknown flag: $1" >&2; exit 2 ;;
  esac
done

# Defaults — workspace root is the parent of Skills/
WORKSPACE_DIR="${WORKSPACE_DIR:-$HOME/Agents Workspace}"
SOURCE_DIR="${SOURCE_DIR:-$WORKSPACE_DIR/Skills/foundry-pipeline}"

# Validate source
if [[ ! -f "$SOURCE_DIR/VERSION" ]]; then
  echo "ERROR: $SOURCE_DIR does not look like foundry-pipeline (no VERSION file)" >&2
  echo "Hint: clone first:" >&2
  echo "  git clone https://github.com/$CANONICAL_REPO.git \"$SOURCE_DIR\"" >&2
  echo "  cd \"$SOURCE_DIR\" && git checkout v2.0.0   # pin to release" >&2
  exit 1
fi

VERSION="$(tr -d '[:space:]' < "$SOURCE_DIR/VERSION")"
echo "Installing foundry-pipeline v$VERSION (workspace pattern)"
echo "  source:    $SOURCE_DIR"
echo "  workspace: $WORKSPACE_DIR"
echo "  mode:      $([[ "$COPY_MODE" == "1" ]] && echo 'copy' || echo 'symlink')"
echo ""

# Build the monorepo first so packages/<pkg> are populated.
echo "Building monorepo..."
(cd "$SOURCE_DIR" && bash scripts/foundry-monorepo-build.sh >/dev/null)
echo ""

total_links=0
for entry in "${HARVESTS[@]}"; do
  IFS='|' read -r hid pkg home_tpl ws_tpl <<< "$entry"

  if [[ -n "$HARNESS_FILTER" && "$HARNESS_FILTER" != "$hid" ]]; then
    continue
  fi

  pkg_dir="$SOURCE_DIR/packages/$pkg"
  if [[ ! -d "$pkg_dir" ]]; then
    echo "  SKIP  $hid — packages/$pkg not found"
    continue
  fi

  # HOME target
  if [[ "$WORKSPACE_ONLY" != "1" ]]; then
    home_target="${home_tpl//\{ver\}/$VERSION}"
    home_dest="$HOME/$home_target"
    home_parent="$(dirname "$home_dest")"
    # For skills-sh style per-skill links, expand the wildcard to per-skill symlinks.
    if [[ "$home_target" == *"foundry-*"* ]]; then
      mkdir -p "$home_parent"
      home_count=0
      for skill_dir in "$pkg_dir/skills/"*/; do
        [[ -d "$skill_dir" ]] || continue
        skill_name="$(basename "$skill_dir")"
        link_name="foundry-${skill_name}"
        dest="$home_parent/$link_name"
        if [[ "$COPY_MODE" == "1" ]]; then
          rm -rf "$dest" 2>/dev/null
          cp -R "$skill_dir" "$dest"
        else
          ln -sfn "$skill_dir" "$dest"
        fi
        home_count=$((home_count + 1))
      done
      echo "  HOME  $hid  → $home_count skills in $home_parent"
      total_links=$((total_links + home_count))
    else
      mkdir -p "$home_parent"
      if [[ "$COPY_MODE" == "1" ]]; then
        rm -rf "$home_dest" 2>/dev/null
        cp -R "$pkg_dir" "$home_dest"
      else
        ln -sfn "$pkg_dir" "$home_dest"
      fi
      echo "  HOME  $hid  → $home_dest"
      total_links=$((total_links + 1))
    fi
  fi

  # WORKSPACE target
  if [[ "$HOME_ONLY" != "1" ]]; then
    ws_target="${ws_tpl//\{ver\}/$VERSION}"
    ws_dest="$WORKSPACE_DIR/$ws_target"
    ws_parent="$(dirname "$ws_dest")"
    if [[ "$ws_target" == *"foundry-*"* ]]; then
      mkdir -p "$ws_parent"
      ws_count=0
      for skill_dir in "$pkg_dir/skills/"*/; do
        [[ -d "$skill_dir" ]] || continue
        skill_name="$(basename "$skill_dir")"
        link_name="foundry-${skill_name}"
        dest="$ws_parent/$link_name"
        if [[ "$COPY_MODE" == "1" ]]; then
          rm -rf "$dest" 2>/dev/null
          cp -R "$skill_dir" "$dest"
        else
          ln -sfn "$skill_dir" "$dest"
        fi
        ws_count=$((ws_count + 1))
      done
      echo "  WORK  $hid  → $ws_count skills in $ws_parent"
      total_links=$((total_links + ws_count))
    else
      mkdir -p "$ws_parent"
      if [[ "$COPY_MODE" == "1" ]]; then
        rm -rf "$ws_dest" 2>/dev/null
        cp -R "$pkg_dir" "$ws_dest"
      else
        ln -sfn "$pkg_dir" "$ws_dest"
      fi
      echo "  WORK  $hid  → $ws_dest"
      total_links=$((total_links + 1))
    fi
  fi
done

echo ""
echo "✓ Installed $total_links link(s) for v$VERSION"
echo ""
echo "To update later:"
echo "  cd \"$SOURCE_DIR\" && git pull && git checkout v\$(tr -d '[:space:]' < VERSION)"
echo "  bash \"$SOURCE_DIR/packages/core/scripts/foundry-install-workspace.sh\""
exit 0