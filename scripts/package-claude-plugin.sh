#!/usr/bin/env bash
# Build the runtime-only Claude Code plugin tree from this source checkout.
#
# Claude Code copies a plugin's ENTIRE directory into the user's cache (there is no ignore or
# allowlist mechanism), and clones the marketplace repo too. So the tree users install from must
# contain only runtime files. This script assembles exactly that from an allowlist; CI publishes
# it to the `dist` branch (scripts/publish-claude-dist.sh), which users add as
# `claude plugin marketplace add rohitsharma9646/feature-flow#dist`.
set -euo pipefail

PLUGIN_NAME="feature-flow"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
OUTPUT="$REPO_ROOT/dist/claude/$PLUGIN_NAME"
DRY_RUN=0

die() { echo "ERROR: $*" >&2; exit 1; }

usage() {
  cat <<'USAGE'
Usage:
  scripts/package-claude-plugin.sh [--output PATH] [--dry-run]

Options:
  --output PATH  Destination directory. Default: ./dist/claude/feature-flow
  --dry-run      Print the copy plan without writing files.
  -h, --help     Show this help.

The package contains only Claude runtime content:
  .claude-plugin (plugin.json + a marketplace.json serving the plugin from "./"),
  commands, agents, skills, hooks, templates, config,
  docs/manifest-schema.md, docs/grilling-playbook.md, README.md, LICENSE.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --output) [[ $# -ge 2 ]] || die "--output requires a path"; OUTPUT="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown argument: $1" ;;
  esac
done

# Resolve OUTPUT to a canonical absolute path without creating anything (a dry run writes nothing),
# then refuse any destination whose `rm -rf` would be destructive: /, $HOME, the repo root or any
# ancestor of it, or an existing non-empty directory that is not a previous package.
OUTPUT="$(python3 -c 'import os, sys; print(os.path.realpath(sys.argv[1]))' "$OUTPUT")"
case "$OUTPUT" in
  /|"$REPO_ROOT"|"$(cd "$HOME" 2>/dev/null && pwd -P)")
    die "refusing to package into /, \$HOME or the repo root: $OUTPUT" ;;
esac
case "$REPO_ROOT/" in
  "$OUTPUT"/*) die "refusing to package into an ancestor of the repo: $OUTPUT" ;;
esac
if [[ -d "$OUTPUT" && -n "$(ls -A "$OUTPUT")" && ! -f "$OUTPUT/.claude-plugin/plugin.json" ]]; then
  die "refusing to replace a non-empty directory that is not a previous package: $OUTPUT"
fi

RUNTIME_PATHS=(
  "commands"
  "agents"
  "skills"
  "hooks"
  "templates"
  "config"
  "docs/manifest-schema.md"
  "docs/grilling-playbook.md"
  "README.md"
  "LICENSE"
  ".claude-plugin/plugin.json"
)

for rel in "${RUNTIME_PATHS[@]}" ".claude-plugin/marketplace.json"; do
  [[ -e "$REPO_ROOT/$rel" ]] || die "required path missing: $rel"
done

echo "Claude package destination: $OUTPUT"
if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "Dry run: no files will be written."
  for rel in "${RUNTIME_PATHS[@]}"; do echo "copy $rel"; done
  echo "generate .claude-plugin/marketplace.json (plugin source \"./\")"
  exit 0
fi

rm -rf "$OUTPUT"
mkdir -p "$OUTPUT"
for rel in "${RUNTIME_PATHS[@]}"; do
  mkdir -p "$(dirname "$OUTPUT/$rel")"
  if [[ -d "$REPO_ROOT/$rel" ]]; then
    cp -R "$REPO_ROOT/$rel" "$OUTPUT/$rel"
  else
    cp -p "$REPO_ROOT/$rel" "$OUTPUT/$rel"
  fi
done

# The dist tree is its own marketplace: same metadata as master's, but the plugin is served from
# the tree itself ("./") — master's entry points at the dist branch instead.
python3 - "$REPO_ROOT/.claude-plugin/marketplace.json" "$OUTPUT/.claude-plugin/marketplace.json" <<'PY'
import json, sys
src, dst = sys.argv[1], sys.argv[2]
m = json.load(open(src))
for p in m["plugins"]:
    if p["name"] == "feature-flow":
        p["source"] = "./"
with open(dst, "w") as f:
    json.dump(m, f, indent=2)
    f.write("\n")
PY

# Safety net: nothing dev-only may ride along inside an allowlisted directory.
if found="$(cd "$OUTPUT" && find . \( -name '*.go' -o -name '.git' -o -name '.feature-flow' \
      -o -name '.feature-flow.json' -o -name 'go.mod' -o -name 'go.sum' \) -print -quit)" && [[ -n "$found" ]]; then
  die "dev-only file copied into the package: $found"
fi

echo "Claude package ready."
