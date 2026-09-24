## Global Constraints

- Never modify the real index, the working tree or history; build in a throwaway GIT_INDEX_FILE.
- Only `git mktemp cp rm` plus shell builtins; functions only, no `set -e`; CLI branch keyed on BASH_SOURCE.
- Bookkeeping excludes: paths.base, paths.durable, paths.kb from .feature-flow.json, defaults .feature-flow / null / .feature-flow-kb.

### Task 2: `hooks/lib/revision.sh` — the shared library (test-first)

**Files:**
- Create: `hooks/lib/revision.sh`
- Modify: `scripts/checks/enforce-gate-guard.sh`

**Covers:** AC3, AC4
**Interfaces:**
- Consumes: none
- Produces: `revision_excludes <project-dir>`, `revision_fingerprint <project-dir>` (prints a tree id), `revision_changed_paths <project-dir> <tree-a> <tree-b>`

- [ ] **Step 1:** Add the lib fixtures to `scripts/checks/enforce-gate-guard.sh`:
  ```bash
  # ---- Revision binding (v0.22.0): hooks/lib/revision.sh ------------------------------
  # Real temporary git repositories — the fingerprint is git state, so fixtures must be too.
  LIB="hooks/lib/revision.sh"
  gitc() { git -C "$1" -c user.name=ff -c user.email=ff@example.invalid "${@:2}"; }
  fp() { bash "$LIB" "$1"; }                  # CLI mode: prints the fingerprint of <project-dir>
  if ! command -v git >/dev/null 2>&1; then
    err "revision fixtures need git on PATH"
  elif [ ! -f "$LIB" ]; then
    err "revision lib missing: $LIB"
  else
    G="$TMP/rev-repo"; mkdir -p "$G/src" "$G/pkg"
    git -C "$G" init -q
    for n in 01 02 03 04 05 06 07 08 09 10 11 12; do printf '%s\n' "$n" > "$G/src/f$n.txt"; done
    printf 'root\n' > "$G/pkg/p.txt"
    printf '.feature-flow/\n' > "$G/.gitignore"              # base ignored; kb deliberately NOT ignored
    printf '{"paths":{"durable":"docs/ff"}}\n' > "$G/.feature-flow.json"
    gitc "$G" add -A && gitc "$G" commit -qm base
  
    base="$(fp "$G")"
    { [ -n "$base" ] && [ "$base" = "$(fp "$G")" ]; } \
      && ok "rev lib: fingerprint is repeatable" || err "rev lib: fingerprint not repeatable ('$base')"
    [ "$base" = "$(git -C "$G" rev-parse 'HEAD^{tree}')" ] \
      && ok "rev lib: clean tree equals HEAD's tree" || err "rev lib: clean tree != HEAD^{tree}"
  
    # AC3 — bookkeeping writes (paths.base, paths.durable, paths.kb) are invisible.
    mkdir -p "$G/.feature-flow/run" "$G/docs/ff/2026-run" "$G/.feature-flow-kb"
    printf '{}\n' > "$G/.feature-flow/run/manifest.json"
    printf '# spec\n' > "$G/docs/ff/2026-run/spec.md"
    printf '# kb\n' > "$G/.feature-flow-kb/entry.md"
    [ "$(fp "$G")" = "$base" ] \
      && ok "rev lib/AC3: writes under paths.base, paths.durable, paths.kb don't change it" \
      || err "rev lib/AC3: bookkeeping writes changed the fingerprint"
    # AC3 — a nested repository (e.g. .claude/worktrees/x) is invisible.
    N="$G/.claude/worktrees/x"; mkdir -p "$N"; git -C "$N" init -q; printf 'n\n' > "$N/n.txt"
    gitc "$N" add -A && gitc "$N" commit -qm nested
    [ "$(fp "$G")" = "$base" ] \
      && ok "rev lib/AC3: nested git repository doesn't change it" \
      || err "rev lib/AC3: nested repository changed the fingerprint"
  
    # AC4 — real code changes are visible; reverting restores the value.
    printf 'edited\n' >> "$G/src/f01.txt"; e1="$(fp "$G")"
    [ -n "$e1" ] && [ "$e1" != "$base" ] && ok "rev lib/AC4: tracked edit changes it" || err "rev lib/AC4: tracked edit not detected"
    git -C "$G" checkout -q -- src/f01.txt
    rm "$G/src/f02.txt"; e2="$(fp "$G")"
    [ -n "$e2" ] && [ "$e2" != "$base" ] && ok "rev lib/AC4: tracked delete changes it" || err "rev lib/AC4: tracked delete not detected"
    git -C "$G" checkout -q -- src/f02.txt
    printf 'new\n' > "$G/src/new.txt"; e3="$(fp "$G")"
    [ -n "$e3" ] && [ "$e3" != "$base" ] && ok "rev lib/AC4: untracked non-ignored file changes it" || err "rev lib/AC4: untracked file not detected"
    # The real index must be byte-identical across fingerprint runs on a dirty tree (sampled
    # right around the calls — the fixture's own `git checkout`s legitimately rewrite it).
    printf 'dirty\n' >> "$G/src/f04.txt"; idx0="$(cksum < "$G/.git/index")"
    fp "$G" >/dev/null; fp "$G" >/dev/null
    [ "$(cksum < "$G/.git/index")" = "$idx0" ] \
      && ok "rev lib: the real .git/index is never modified" || err "rev lib: real index changed"
    printf '04\n' > "$G/src/f04.txt"
    rm "$G/src/new.txt"
    [ "$(fp "$G")" = "$base" ] && ok "rev lib/AC4: revert restores the original value" || err "rev lib/AC4: revert did not restore"
  
    # FS3 — project dir is a subdirectory of the git top level (monorepo package).
    printf '{"paths":{"durable":"docs/ff"}}\n' > "$G/pkg/.feature-flow.json"
    s0="$(fp "$G/pkg")"
    mkdir -p "$G/pkg/.feature-flow/r" "$G/pkg/docs/ff/x"
    printf '{}\n' > "$G/pkg/.feature-flow/r/manifest.json"; printf '# d\n' > "$G/pkg/docs/ff/x/d.md"
    [ -n "$s0" ] && [ "$(fp "$G/pkg")" = "$s0" ] \
      && ok "rev lib/FS3: subdir project — its own bookkeeping paths are excluded" \
      || err "rev lib/FS3: subdir project bookkeeping changed the fingerprint"
    printf 'x\n' >> "$G/src/f03.txt"
    [ "$(fp "$G/pkg")" != "$s0" ] \
      && ok "rev lib/FS3: subdir project — edits elsewhere in the repo are still detected" \
      || err "rev lib/FS3: edit outside the subdir was missed"
    git -C "$G" checkout -q -- src/f03.txt
    rm -rf "$G/pkg/.feature-flow" "$G/pkg/docs" "$G/pkg/.feature-flow.json"
  
    # FS4 — every paths.* form: absolute, trailing slash, null, unset.
    for cfg in "{\"paths\":{\"durable\":\"$G/docs/ff\"}}" '{"paths":{"durable":"docs/ff/"}}' '{"paths":{"durable":"./docs/ff"}}'; do
      printf '%s\n' "$cfg" > "$G/.feature-flow.json"; c0="$(fp "$G")"
      printf '# more\n' > "$G/docs/ff/2026-run/more.md"
      [ -n "$c0" ] && [ "$(fp "$G")" = "$c0" ] \
        && ok "rev lib/FS4: durable form $cfg is excluded" || err "rev lib/FS4: durable form $cfg not excluded"
      rm -f "$G/docs/ff/2026-run/more.md"
    done
    printf '{"paths":{"durable":null}}\n' > "$G/.feature-flow.json"; c0="$(fp "$G")"
    printf '# kb2\n' > "$G/.feature-flow-kb/e2.md"
    [ -n "$c0" ] && [ "$(fp "$G")" = "$c0" ] \
      && ok "rev lib/FS4: durable null + kb unset → default kb still excluded" || err "rev lib/FS4: default kb not excluded"
    printf 'x\n' > "$G/docs/ff/2026-run/code-now.md"
    [ "$(fp "$G")" != "$c0" ] \
      && ok "rev lib/FS4: durable null → docs/ff counts as code" || err "rev lib/FS4: durable null still excluded docs/ff"
    rm -f "$G/docs/ff/2026-run/code-now.md" "$G/.feature-flow-kb/e2.md"
    git -C "$G" checkout -q -- .feature-flow.json
  
    # AC7 / FS1 — changed-path listing: capped, counted; unavailable objects; non-hex ids.
    for n in 01 02 03 04 05 06 07 08 09 10 11 12; do printf 'z\n' >> "$G/src/f$n.txt"; done
    after="$(fp "$G")"
    out="$( . "$LIB"; revision_changed_paths "$G" "$base" "$after" )"
    printf '%s' "$out" | grep -q 'src/f01.txt' && printf '%s' "$out" | grep -q '(+2 more)' \
      && ok "rev lib/AC7: changed paths listed, capped at 10 with '+N more'" || err "rev lib/AC7: bad listing: $out"
    out="$( . "$LIB"; revision_changed_paths "$G" 0123456789abcdef0123456789abcdef01234567 "$after" )"
    [ "$out" = "changed paths unavailable" ] \
      && ok "rev lib/FS1: missing tree object → 'changed paths unavailable'" || err "rev lib/FS1: got: $out"
    out="$( . "$LIB"; revision_changed_paths "$G" '--output=/tmp/x' "$after" )"
    [ "$out" = "changed paths unavailable" ] \
      && ok "rev lib: a non-hex revision is never passed to git" || err "rev lib: non-hex id accepted: $out"
    git -C "$G" checkout -q -- src
    ( . "$LIB"; revision_fingerprint "$TMP/not-a-repo-$$" ) >/dev/null 2>&1 \
      && err "rev lib: fingerprint outside a repo should fail" || ok "rev lib: fingerprint outside a git repo returns non-zero"
  
    # ---- Gate B revision binding (hook) — AC5–AC9, FS1 --------------------------------
    H="$TMP/rev-hook"; mkdir -p "$H/src"; git -C "$H" init -q
    printf 'a\n' > "$H/src/a.txt"; printf '.feature-flow/\n' > "$H/.gitignore"
    gitc "$H" add -A && gitc "$H" commit -qm base
    VOK='# Verify\n\n## Contract mapping\n\n### AC1\n- **Evidence:** `make test` — exit 0\n'
    # mkrb <slug>: run dir inside the git repo, with a verify.md that passes the 0.21.0 Gate B floor
    mkrb() { local d="$H/.feature-flow/$1"; mkdir -p "$d"; printf "$VOK" > "$d/verify.md"; printf '%s' "$d"; }
  ```
- [ ] **Step 2:** **Run:** `bash scripts/checks/enforce-gate-guard.sh` **Expected:** exit 1 — lib cases FAIL (lib absent).
- [ ] **Step 3:** Write `hooks/lib/revision.sh`:
  ```bash
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
  ```
- [ ] **Step 4: Verify** — **Run:** `bash scripts/checks/enforce-gate-guard.sh` **Expected:** exit 0, every lib case ok.
