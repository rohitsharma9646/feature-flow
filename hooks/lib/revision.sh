#!/usr/bin/env bash
# Feature Flow revision fingerprint (v0.22.0) — docs/schema/enforcement.md §Revision fingerprint.
# That section reproduces this file byte-for-byte; scripts/checks/revision-binding-guard.sh
# fails CI if the two ever differ. Edit both together.
#
# Run:    bash revision.sh <project-dir>   -> prints the working-tree fingerprint (a git tree id)
# Source: . revision.sh                    -> defines revision_excludes, revision_fingerprint,
#                                             revision_changed_paths (no side effects)
#
# The fingerprint covers the whole git top level: tracked files as they are in the working tree
# plus untracked, non-ignored files — minus Feature Flow's bookkeeping paths (paths.base,
# paths.durable, paths.kb, resolved from <project-dir>/.feature-flow.json) and nested git
# repositories. It is built in a throwaway index; the real index, the working tree and the
# history are never modified. Any failure prints nothing and returns non-zero.

# _rev_canon <absolute-path>: physical path without trailing slashes (the path may not exist).
_rev_canon() {
  local p=$1 d b
  while [ "${#p}" -gt 1 ] && [ "${p%/}" != "$p" ]; do p=${p%/}; done
  if [ -d "$p" ]; then (cd "$p" 2>/dev/null && pwd -P); return; fi
  d=${p%/*}; b=${p##*/}; [ -n "$d" ] || d=/
  if [ -d "$d" ]; then printf '%s/%s\n' "$(cd "$d" && pwd -P)" "$b"; else printf '%s\n' "$p"; fi
}

# revision_excludes <project-dir>: bookkeeping paths, one per line, relative to the git top level.
# Defaults mirror config/defaults.json (paths.base ".feature-flow", paths.durable null,
# paths.kb ".feature-flow-kb"); a key present in .feature-flow.json overrides, null disables.
revision_excludes() {
  local proj top cfg key val abs
  proj=$(cd "$1" 2>/dev/null && pwd -P) || return 1
  top=$(git -C "$proj" rev-parse --show-toplevel 2>/dev/null) || return 1
  top=$(cd "$top" 2>/dev/null && pwd -P) || return 1
  cfg=$proj/.feature-flow.json
  for key in base durable kb; do
    case $key in base) val=.feature-flow ;; durable) val= ;; kb) val=.feature-flow-kb ;; esac
    if [ -f "$cfg" ]; then
      command -v jq >/dev/null 2>&1 || return 1
      val=$(jq -r --arg k "$key" --arg d "$val" \
        '(.paths // {}) as $p | if ($p | has($k)) then ($p[$k] // "") else $d end' "$cfg" 2>/dev/null) || return 1
    fi
    [ -n "$val" ] || continue
    case $val in /*) abs=$val ;; *) abs=$proj/$val ;; esac
    abs=$(_rev_canon "$abs")
    case $abs in
      "$top") continue ;;                       # never exclude the whole repository
      "$top"/*) printf '%s\n' "${abs#"$top"/}" ;;
      *) continue ;;                            # outside the repository: nothing to exclude
    esac
  done
}

# revision_fingerprint <project-dir>: print the fingerprint (a git tree id) of the working tree.
revision_fingerprint() {
  local proj top gitdir ex idx list tree
  command -v git >/dev/null 2>&1 || return 1
  proj=$(cd "$1" 2>/dev/null && pwd -P) || return 1
  top=$(git -C "$proj" rev-parse --show-toplevel 2>/dev/null) || return 1
  gitdir=$(git -C "$proj" rev-parse --absolute-git-dir 2>/dev/null) || return 1
  ex=$(revision_excludes "$proj") || return 1
  idx=$(mktemp) || return 1
  list=$(mktemp) || { rm -f "$idx"; return 1; }
  tree=$(
    export GIT_INDEX_FILE=$idx
    # Start from a copy of the real index so unchanged files keep their stat cache.
    if [ -f "$gitdir/index" ]; then cp "$gitdir/index" "$idx" || exit 1; else rm -f "$idx"; fi
    git -C "$top" add -u -- . >/dev/null 2>&1 || exit 1
    git -C "$top" ls-files -z --others --exclude-standard >"$list" 2>/dev/null || exit 1
    # Nested repositories are listed as "dir/": skip them. Everything else is added literally.
    while IFS= read -r -d '' p; do
      case $p in */) ;; *) printf '%s\0' "$p" ;; esac
    done <"$list" | git --literal-pathspecs -C "$top" add --pathspec-from-file=- --pathspec-file-nul >/dev/null 2>&1 || exit 1
    while IFS= read -r p; do
      [ -n "$p" ] || continue
      git --literal-pathspecs -C "$top" rm -r -q --cached --ignore-unmatch -- "$p" >/dev/null 2>&1 || exit 1
    done <<EOF
$ex
EOF
    git -C "$top" write-tree 2>/dev/null
  )
  local rc=$?
  rm -f "$idx" "$list"
  [ "$rc" -eq 0 ] && [ -n "$tree" ] || return 1
  printf '%s\n' "$tree"
}

# revision_changed_paths <project-dir> <tree-a> <tree-b>: paths that differ, comma-separated,
# at most 10 then "(+N more)"; "changed paths unavailable" when a tree is missing or malformed.
revision_changed_paths() {
  local dir=$1 a=$2 b=$3 out n=0 shown= p id
  for id in "$a" "$b"; do
    case $id in ''|*[!0-9a-f]*) printf 'changed paths unavailable'; return 0 ;; esac
    { [ "${#id}" -eq 40 ] || [ "${#id}" -eq 64 ]; } || { printf 'changed paths unavailable'; return 0; }
  done
  out=$(git -C "$dir" diff-tree -r --name-only "$a" "$b" 2>/dev/null) || { printf 'changed paths unavailable'; return 0; }
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    n=$((n + 1))
    [ "$n" -le 10 ] && shown=${shown:+$shown, }$p
  done <<EOF
$out
EOF
  if [ "$n" -gt 10 ]; then printf '%s (+%d more)' "$shown" "$((n - 10))"; else printf '%s' "${shown:-no paths differ}"; fi
}

# Executed (or piped to `bash -s -- <project-dir>`) rather than sourced: print the fingerprint.
if [ -z "${BASH_SOURCE[0]:-}" ] || [ "${BASH_SOURCE[0]}" = "$0" ]; then
  revision_fingerprint "${1:-.}"
  exit
fi
