#!/usr/bin/env bash
# Build a clean local Codex plugin package from this source checkout.
set -euo pipefail

PLUGIN_NAME="feature-flow"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
OUTPUT="$REPO_ROOT/dist/codex/$PLUGIN_NAME"
DRY_RUN=0
INSTALL_LINK=0

die() {
  echo "ERROR: $*" >&2
  exit 1
}

usage() {
  cat <<'USAGE'
Usage:
  scripts/package-codex-plugin.sh [--output PATH] [--install-link] [--dry-run]

Options:
  --output PATH    Destination package directory.
                   Default: ./dist/codex/feature-flow
  --install-link   Point ~/plugins/feature-flow at the generated package.
  --dry-run        Print the copy plan without writing files.
  -h, --help       Show this help.

The package intentionally includes only Codex runtime content:
  .codex-plugin, skills, commands, agents, templates, config,
  docs/manifest-schema.md, docs/grilling-playbook.md, README.md, LICENSE
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --output)
      [[ $# -ge 2 ]] || die "--output requires a path"
      OUTPUT="$2"
      shift 2
      ;;
    --install-link)
      INSTALL_LINK=1
      shift
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "unknown argument: $1"
      ;;
  esac
done

abs_path() {
  local path="$1"
  local dir
  local base

  dir="$(dirname "$path")"
  base="$(basename "$path")"
  mkdir -p "$dir"
  dir="$(cd "$dir" && pwd -P)"
  printf '%s/%s\n' "$dir" "$base"
}

OUTPUT="$(abs_path "$OUTPUT")"

case "$OUTPUT" in
  /|"$REPO_ROOT"|"$REPO_ROOT"/)
    die "refusing to package into repo root or filesystem root: $OUTPUT"
    ;;
esac

REQUIRED_PATHS=(
  ".codex-plugin"
  "skills"
  "commands"
  "agents"
  "templates"
  "config"
  "docs/manifest-schema.md"
  "docs/grilling-playbook.md"
  "README.md"
  "LICENSE"
)

for rel in "${REQUIRED_PATHS[@]}"; do
  [[ -e "$REPO_ROOT/$rel" ]] || die "required path missing: $rel"
done

echo "Codex package destination: $OUTPUT"

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "Dry run: no files will be written."
else
  rm -rf "$OUTPUT"
  mkdir -p "$OUTPUT"
fi

copy_path() {
  local rel="$1"
  local src="$REPO_ROOT/$rel"
  local dest="$OUTPUT/$rel"

  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "copy $rel"
    return
  fi

  mkdir -p "$(dirname "$dest")"
  if [[ -d "$src" ]]; then
    mkdir -p "$dest"
    rsync -a --delete "$src/" "$dest/"
  else
    cp -p "$src" "$dest"
  fi
}

for rel in "${REQUIRED_PATHS[@]}"; do
  copy_path "$rel"
done

if [[ "$DRY_RUN" -eq 0 ]]; then
  for forbidden in .git .feature-flow .claude-plugin hooks scripts tests node_modules; do
    if [[ -e "$OUTPUT/$forbidden" ]]; then
      die "forbidden path copied into package: $forbidden"
    fi
  done
fi

if [[ "$INSTALL_LINK" -eq 1 ]]; then
  link_path="$HOME/plugins/$PLUGIN_NAME"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "link $link_path -> $OUTPUT"
  else
    mkdir -p "$HOME/plugins"
    if [[ -e "$link_path" && ! -L "$link_path" ]]; then
      die "$link_path exists and is not a symlink"
    fi
    ln -sfn "$OUTPUT" "$link_path"
    echo "Updated $link_path -> $OUTPUT"
  fi
fi

echo "Codex package ready."
