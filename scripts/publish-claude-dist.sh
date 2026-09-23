#!/usr/bin/env bash
# Publish the runtime-only Claude plugin tree to the `dist` branch.
#
# Builds the package (scripts/package-claude-plugin.sh), turns it into a git tree with plumbing
# (no checkout, no working-tree changes), and pushes a commit to <remote>/<branch> only when the
# tree differs from the branch tip. Creates the branch (orphan history) if it does not exist yet.
# Run by CI on every push to master; safe to run by hand.
#
# Usage: scripts/publish-claude-dist.sh [--remote NAME] [--branch NAME] [--no-push]
set -euo pipefail

REMOTE="origin"
BRANCH="dist"
PUSH=1
die() { echo "ERROR: $*" >&2; exit 1; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --remote) [[ $# -ge 2 ]] || die "--remote requires a name"; REMOTE="$2"; shift 2 ;;
    --branch) [[ $# -ge 2 ]] || die "--branch requires a name"; BRANCH="$2"; shift 2 ;;
    --no-push) PUSH=0; shift ;;
    -h|--help) sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) die "unknown argument: $1" ;;
  esac
done

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
cd "$REPO_ROOT"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
pkg="$tmp/feature-flow"

bash scripts/package-claude-plugin.sh --output "$pkg" >/dev/null
bash scripts/checks/claude-dist-guard.sh >/dev/null || die "claude-dist guard failed — refusing to publish"

# Build a tree object from the package using a throwaway index.
export GIT_INDEX_FILE="$tmp/index"
git --work-tree="$pkg" add -A .
tree="$(git write-tree)"
unset GIT_INDEX_FILE

source_rev="$(git rev-parse --short HEAD)"
parent=""
if git fetch --quiet "$REMOTE" "refs/heads/$BRANCH:refs/remotes/$REMOTE/$BRANCH" 2>/dev/null; then
  parent="$(git rev-parse "refs/remotes/$REMOTE/$BRANCH")"
  if [[ "$(git rev-parse "$parent^{tree}")" == "$tree" ]]; then
    echo "dist unchanged: $REMOTE/$BRANCH already holds this tree ($tree) — nothing to publish."
    exit 0
  fi
fi

msg="dist: runtime-only plugin build of ${source_rev}"
if [[ -n "$parent" ]]; then
  commit="$(git commit-tree "$tree" -p "$parent" -m "$msg")"
else
  commit="$(git commit-tree "$tree" -m "$msg")"
  echo "creating $REMOTE/$BRANCH (orphan history)"
fi
echo "built $commit (tree $tree) from $source_rev"

if [[ "$PUSH" -eq 1 ]]; then
  git push "$REMOTE" "$commit:refs/heads/$BRANCH"
  echo "published $REMOTE/$BRANCH -> $commit"
else
  echo "--no-push: not pushing"
fi
