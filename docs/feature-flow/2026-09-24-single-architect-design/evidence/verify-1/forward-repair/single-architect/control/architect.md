Recommended: Inline `--version` case branch in cli.sh, resolved via `BASH_SOURCE`, tested against a VERSION-less copy of the script in a temp dir — a single-file change that keeps VERSION as the sole source of truth and needs no new dependency, config surface, or mutation of the real repo.

## Patterns & Conventions Found

- `src/cli.sh:3-10` — the whole CLI is one `case "$cmd" in ... esac` block under `set -u`, currently with only a catch-all `*)` branch that prints `usage: cli.sh <command>` to stderr and exits 2. New flags are added as sibling `case` arms in this same style.
- `tests/test.sh:4` — a single `check_exit <script> <arg> <want_exit_code>` helper; it redirects both stdout and stderr to `/dev/null`, so it can assert exit codes but not output content. Content-based assertions need a new, separate check written in the same terse inline style (`echo "ok ..."` / `echo "FAIL ..."`, set `fail=1`).
- `tests/test.sh:5` — checks are added as flat top-level lines (`check_exit src/cli.sh bogus 2`), not functions/subtests; new AC checks should follow that flat style and run in sequence, ending with `exit $fail`.
- `VERSION` (repo root) — single line `1.0.0\n`, currently unread by any code; spec requires it stay the single source of truth (no duplicated version string, no build-time injection).
- No existing helper for resolving "script's own directory" — this is new territory; must be introduced correctly per the explore-findings concern (relative to script location, not CWD).

## Architecture Decision

**Approach: in-branch `--version` handling in `src/cli.sh`, path resolved from `BASH_SOURCE`, tested via a copied-script fixture.**

Rationale:
- Smallest change that satisfies every AC and touches only the two files the spec names (`src/cli.sh`, `tests/test.sh`).
- `BASH_SOURCE[0]` correctly locates `VERSION` regardless of the caller's CWD or how the script is invoked (`bash src/cli.sh`, `bash /abs/path/src/cli.sh`, `./cli.sh` from within `src/`, etc.), directly addressing the "relative to script location, not CWD" concern.
- Reuses the existing usage/exit-2 path for the missing-VERSION edge case instead of duplicating the message — the edge-case behavior spec describes ("nothing on stdout, `usage:`-style message on stderr, exit 2") is *identical* to the pre-existing default branch, so a shared `usage()` function is both DRY and the most natural reading of the spec.
- `cat` (not `echo`) preserves the exact byte contents of VERSION including its trailing newline, satisfying "prints exact contents" literally (AC1).
- Testing the missing-VERSION case by copying `cli.sh` into a `mktemp -d` sandbox (with no VERSION file present) avoids ever touching the real repo's VERSION file — no mocking library, no env-var indirection, just plain bash/`cp`/`mktemp`, consistent with "no new dependency."

Trade-off accepted: the temp-dir test fixture duplicates the file layout assumption (`<tmp>/src/cli.sh` expects `<tmp>/VERSION` one level up) — this is intentional coupling to the same relative-path contract the script itself uses, so it also acts as a regression check on that contract.

## Component Design

### `src/cli.sh` (modify)
- **Responsibility**: add version-reporting behavior without disturbing the existing default dispatch.
- **New elements**:
  - `usage()` function — extracts the existing `*)` body (`echo "usage: cli.sh <command>" >&2; exit 2`) so it can be reused by both the missing-VERSION edge case and the true default case.
  - `script_dir` — computed once via `cd "$(dirname "${BASH_SOURCE[0]}")" && pwd` for a robust absolute path independent of CWD.
  - `version_file="$script_dir/../VERSION"`.
  - New `case` arm: `--version)` — if `version_file` doesn't exist, call `usage` (stderr message, exit 2, nothing written to stdout since `cat` is never reached); otherwise `cat "$version_file"; exit 0`.
- **Dependencies**: none beyond bash builtins/`cat`/`dirname`/`cd`/`pwd`.

### `tests/test.sh` (modify)
- **Responsibility**: cover AC1 (exact content + exit 0), AC2 (missing VERSION → usage/stderr/exit 2), keep `fail` aggregation pattern.
- **New checks** (appended after the existing `check_exit` line, before `exit $fail`):
  1. `check_exit src/cli.sh --version 0` — reuses existing helper for the exit-code half of AC1.
  2. A new inline content check comparing `bash src/cli.sh --version` output byte-for-byte against `VERSION` (via `diff <(...) VERSION`), satisfying "prints exact contents" including trailing newline.
  3. A new inline missing-VERSION check: create `tmpdir=$(mktemp -d)`, `mkdir -p "$tmpdir/src"`, `cp src/cli.sh "$tmpdir/src/cli.sh"` (no VERSION at `$tmpdir` root), run `bash "$tmpdir/src/cli.sh" --version`, assert stdout empty, stderr starts with `usage:`, exit code 2; clean up with `trap 'rm -rf "$tmpdir"' EXIT` (or explicit `rm -rf "$tmpdir"` at the end).

## Implementation Map

**`src/cli.sh`** — replace lines 3-10 with:
```bash
set -u

usage() {
  echo "usage: cli.sh <command>" >&2
  exit 2
}

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
version_file="$script_dir/../VERSION"

cmd="${1:-}"
case "$cmd" in
  --version)
    [ -f "$version_file" ] || usage
    cat "$version_file"
    exit 0
    ;;
  *)
    usage
    ;;
esac
```

**`tests/test.sh`** — insert after the existing `check_exit src/cli.sh bogus 2` line, before `exit $fail`:
```bash
check_exit src/cli.sh --version 0

if diff <(bash src/cli.sh --version 2>/dev/null) VERSION >/dev/null 2>&1; then
  echo "ok   src/cli.sh --version prints exact VERSION contents"
else
  echo "FAIL src/cli.sh --version content does not match VERSION"
  fail=1
fi

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT
mkdir -p "$tmpdir/src"
cp src/cli.sh "$tmpdir/src/cli.sh"
out=$(bash "$tmpdir/src/cli.sh" --version 2>"$tmpdir/stderr.txt")
rc=$?
err=$(cat "$tmpdir/stderr.txt")
if [ "$rc" = "2" ] && [ -z "$out" ] && [[ "$err" == usage:* ]]; then
  echo "ok   missing VERSION -> usage on stderr, exit 2, empty stdout"
else
  echo "FAIL missing VERSION case (rc=$rc out='$out' err='$err')"
  fail=1
fi
```
Note: `tests/test.sh` must keep running from the repo root (as today, since `src/cli.sh` and `VERSION` are referenced by relative path in the `diff` check) — this is unchanged from current behavior.

## Data Flow

1. User runs `bash src/cli.sh --version` (from any CWD).
2. `script_dir` resolves to the absolute directory containing `cli.sh` (i.e. `<repo>/src`), independent of CWD.
3. `version_file` = `<repo>/src/../VERSION` = `<repo>/VERSION`.
4. `case` matches `--version`; existence check on `version_file`.
   - Exists → `cat` streams file bytes to stdout unmodified → `exit 0`.
   - Missing → `usage` prints `usage: cli.sh <command>` to stderr → `exit 2`, stdout untouched.
5. `tests/test.sh` (run from repo root) exercises both paths: the real repo copy for the success case (AC1), and a temp-dir copy lacking VERSION for the failure case (AC2), then aggregates `fail` and exits accordingly, satisfying the E2E requirement (`bash tests/test.sh` exits 0).

## Build Sequence

- [ ] Edit `src/cli.sh`: add `usage()`, `script_dir`, `version_file`, and the `--version` case arm; refactor the old `*)` body to call `usage`.
- [ ] Manually sanity-check from repo root: `bash src/cli.sh --version` prints `1.0.0` and `echo $?` is `0`.
- [ ] Manually sanity-check from another CWD: `(cd /tmp && bash /tmp/ff-forward-TWXxnO/src/cli.sh --version)` still works (confirms BASH_SOURCE-based resolution, not CWD-based).
- [ ] Edit `tests/test.sh`: add the three new checks (exit-code, content-diff, missing-VERSION sandbox) before `exit $fail`.
- [ ] Run `bash tests/test.sh`; confirm all lines print `ok` and overall exit code is `0`.
- [ ] Confirm the existing `check_exit src/cli.sh bogus 2` check still passes unmodified (regression on default branch).

## Critical Details

- **Error handling**: `set -u` is preserved; no new unset-variable risk since `cmd`, `script_dir`, `version_file` are all assigned before use. `[ -f "$version_file" ]` is the sole missing-VERSION detection — no need to distinguish "file missing" from "unreadable" per spec (only "missing" is specified).
- **Exact-contents semantics**: use `cat`, not `echo "$(cat ...)"` or `printf`, to avoid trailing-newline mutation — this is the detail that makes AC1's "exact contents" literally true at the byte level, verified in tests via `diff` (not string-equality via `$(...)`, which would silently strip trailing newlines on both sides and mask a regression).
- **CWD independence**: the one property explicitly flagged in the explore findings — solved by `BASH_SOURCE`-derived `script_dir` rather than a bare `VERSION` or `./VERSION` relative read.
- **Test isolation**: the missing-VERSION test never touches the real `VERSION` file; it copies only `cli.sh` into an isolated `mktemp -d` sandbox that intentionally omits the VERSION file, then cleans up via `trap ... EXIT`. This keeps the check hermetic and safe to run in CI/parallel.
- **No new dependencies**: only bash builtins plus `cat`, `dirname`, `cp`, `mktemp`, `diff` — all already implicitly available in this bash-only project; no jq/awk/sed introduced.
- **Non-goals respected**: no `--help` flag, no VERSION-bump tooling change, no build-time version injection.

Rejected: env-var VERSION-path override (e.g. `CLI_VERSION_FILE`) for testability — adds an untested-for config surface not in the spec's touchpoints and muddies "VERSION stays single source of truth" by giving callers a way to point at a different file; the temp-dir-copy technique achieves the same test isolation with zero production-code surface added — complexity: low, risk: med, test effort: low.

Rejected: CWD-relative lookup (`cat VERSION` or `cat ./VERSION`) — simplest possible one-liner, but breaks AC1 whenever `cli.sh` is invoked from a directory other than the repo root, directly violating the explore-findings concern about script-location vs CWD resolution; not a viable alternative given the constraint — complexity: low, risk: high, test effort: low.

Rejected: separate `src/version.sh` helper sourced by `cli.sh` — cleaner separation if the CLI were larger or had many subcommands, but for a ~10-line single-file script it adds a file and an indirection layer outside the spec's stated touchpoints (`src/cli.sh`, `tests/test.sh` only), over-engineering a one-branch feature — complexity: med, risk: low, test effort: med.
