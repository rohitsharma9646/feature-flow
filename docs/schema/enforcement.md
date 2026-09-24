# Enforcement (Claude Code) — feature-flow manifest contract
> Part of the manifest contract. Core rules and the topic index: `docs/manifest-schema.md`.

## Enforcement (Claude Code)

Two manifest transitions are **machine-enforced** by a `PreToolUse` hook
(`hooks/enforce-gate`), on by default (`toggles.enforce: true`):

- **Gate A** — a write that enters `implement` (`currentPhase: "implement"`, or
  `phases.implement.status` advanced) is **denied** unless the track's sign-off precondition
  holds: `signOff.signed == true` (feature / bugfix-full) or `phases.diagnose.status == "complete"`
  (bugfix-lite).
- **Gate B** — a write that sets `currentPhase: "done"` is **denied** unless the proposed
  terminal phase(s) are `complete` AND the artifact(s) named by `artifacts.verify` (feature) or
  `artifacts.verify` + `artifacts.review` (bugfix) exist on disk, are non-empty, and contain a
  markdown heading. **For `artifacts.verify` specifically** the file must additionally contain
  a `## Contract mapping` heading and at least one captured status token (an exit code or
  HTTP/status code — see §Evidence, Evidence record shape); the check is deliberately shallow —
  it denies an empty-shell report, it does not grade evidence quality or waiver coverage
  (that judgment is `ff-verify`'s prose responsibility). `artifacts.review` keeps the generic
  existence+heading check.
  **On a revision-bound run** (`revisionBound: true`, v0.22.0) Gate B additionally requires that
  review and verify both attested the **current** code: the hook computes the working-tree
  fingerprint (§Revision fingerprint below) and denies unless `phases.review.revision` and
  `phases.verify.revision` are each present and each equal to it. The reason names the phase —
  `<phase> revision not recorded` or `<phase> revision is stale` — and, when stale, the paths that
  changed since that phase ran (at most 10, then `(+N more)`; `changed paths unavailable` when the
  stamped tree object is gone — still a deny, since the ids differ). Two stamps equal to the current
  tree are equal to each other, so no separate "review ≠ verify" comparison exists. This check runs
  only on a `done` write, only after the checks above pass. It is **skipped silently** — Gate B
  exactly as in v0.21.0 — when `revisionBound` is absent (a pre-v0.22.0 run) or no `.git` exists at
  or above the project directory; it **allows loudly** (a `systemMessage`, never a silent allow)
  when a `.git` exists but the fingerprint cannot be computed (no `git` on PATH, a failing git
  command). The terminal commands check the same rule in prose before they write `done` — see
  **Revision agreement** in `docs/schema/terminal-convergence.md` — so Codex, which has no hook,
  follows it too.

The hook matches **`Write`, `Edit`, and `MultiEdit`** (v0.19.0; earlier versions matched only
`Write`, so an Edit could flip `currentPhase` past a gate unchecked). For Edit/MultiEdit the
proposed manifest is reconstructed by applying the edit(s), in order, to the on-disk file —
literal match, first occurrence unless `replace_all` — and the same Gate A/B logic judges the
result. An Edit with an empty `old_string` on a missing or empty file is the tool's create form:
the manifest becomes `new_string` and is gated exactly like a Write. A manifest rewritten through a shell command (`Bash`) is **not** covered: shell text
cannot be parsed reliably, so that path stays prose-gated.

The hook is **fail-open**: it denies only a determinate-illegal transition and otherwise allows
(no manifest write · `jq` absent · unparseable proposed manifest · missing `track`/`currentPhase`
· an Edit whose non-empty `old_string` is not found, or an empty `old_string` on a non-empty
file — Claude Code rejects those edits itself · `toggles.enforce: false`). It is **Claude-Code-only** — the Codex package excludes `hooks/`, so
Codex runs the same workflow under the **prose** gates (the hook backstops the prose; it does not
replace it). Kill switch: set `toggles.enforce: false` in `.feature-flow.json`. Behavioral test:
`scripts/checks/enforce-gate-guard.sh`.

**WP4 constraint.** The unmerged WP4 branch (`feature/p0-integrity-wp4`) replaces this hook with a
launcher for the Go integrity kernel in observe-only mode. Any WP4 merge must **preserve Gates A and
B, including revision binding**, or supersede them with the kernel's enforce mode (its revision
convergence) — it must never regress enforcement to observe-only.

### Revision fingerprint

A revision-bound run identifies "the code" by a **working-tree fingerprint**: a git tree id over the
whole git top level — tracked files as they currently are in the working tree plus untracked,
non-ignored files — minus Feature Flow's bookkeeping paths (`paths.base`, `paths.durable`,
`paths.kb`, resolved from the project's `.feature-flow.json` with `config/defaults.json`'s values as
defaults; `null` disables one) and nested git repositories. It is built in a throwaway index, so the
real index, the working tree and the history are never modified (Feature Flow still never runs
`git add`/`commit` on your behalf); the tree object it writes is unreferenced and `git gc` reaps it.
The same working tree always yields the same id; any code change yields a new one; reverting the
change restores the old one. Bookkeeping writes — the manifest, `review.md` / `verify.md`, evidence,
promoted durable docs, KB entries — never change it.

**How to compute it.** Always execute this exact text — never re-type or paraphrase it: a variant
yields a different id and every `done` would be denied. On Claude Code run the shipped file:
`bash "${CLAUDE_PLUGIN_ROOT}/hooks/lib/revision.sh" "<project dir>"`. Where `hooks/` is not shipped
(Codex), pipe the block below unchanged: `bash -s -- "<project dir>" <<'FF_REVISION'` … block …
`FF_REVISION`. It prints the id and exits 0, or prints nothing and exits non-zero (not a git
repository, `git` missing, or a failing git command) — then record `null` with the reason. The block
is `hooks/lib/revision.sh` byte-for-byte; `scripts/checks/revision-binding-guard.sh` fails CI if they
differ.

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

### Session re-anchor (SessionStart hook)

The `SessionStart` hook (`hooks/session-start`, sources `startup|clear|compact`) appends an
**active-run block** to its discovery pointer: every run under `<cwd>/<paths.base>/` whose
`currentPhase` is not `done`/`abandoned` and whose `closedAt` is null, newest `updatedAt`
first, max 3 (overflow points at `/feature-flow:ff-list`). Each line carries slug, track/tier,
`currentPhase` + that phase's status, autopilot, sign-off (`n/a` on bugfix-lite), the
`/feature-flow:ff-resume <slug>` command, and every `artifacts.<name>` path (a bare name is
shown under the run dir, a slashed path as-is). On `compact` it tells the model it was mid-run
and to re-read the manifest and artifacts from disk; on `startup`/`clear` it is conditional
("if the user's request relates"). It is advisory context, never a gate, and best-effort: no
`jq`, no `cwd`, no active run, or an unparseable manifest simply omits that part.
Claude-Code-only, like the enforcement hook. Behavioral test: `scripts/checks/session-start-guard.sh`.

