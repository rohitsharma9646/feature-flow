Recommended: inline `--version` case branch in src/cli.sh, reading repo-root VERSION via script-relative path

## Architecture Decision

Add a `--version)` case arm to the existing `case "$cmd" in` dispatch in `src/cli.sh`, alongside
the current `*)` fallback. Resolve the repo root relative to the script's own location (not `$PWD`)
so the flag works regardless of the caller's working directory — the one piece of robustness worth
the extra line, since `tests/test.sh` and real users may invoke `cli.sh` from anywhere. Print the
file with `cat` (not `$(...)` + `echo`) so byte-for-byte contents, including any trailing newline,
pass through unmodified per AC1. This is the smallest change that satisfies the spec and matches the
file's existing single-dispatch, no-function style.

## Component Map

- `src/cli.sh` (modify) — insert `--version)` arm before the `*)` catch-all:
  - Compute `script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"` and
    `version_file="$script_dir/../VERSION"`.
  - If `-f "$version_file"`: `cat "$version_file"; exit 0`.
  - Else: reuse the existing `echo "usage: cli.sh <command>" >&2; exit 2` (same message already
    used by the fallback branch, satisfying AC2's `usage:`-prefix requirement for free).
- `tests/test.sh` (modify) — add two checks after the existing `check_exit` call:
  - Success case: run `bash src/cli.sh --version`, capture stdout and exit code, assert exit 0 and
    output equals `$(cat VERSION)`.
  - Missing-file case: `mv VERSION VERSION.bak`, run `bash src/cli.sh --version` capturing stderr
    only, assert exit 2 and stderr starts with `usage:`, then `mv VERSION.bak VERSION` inside a
    `trap ... RETURN`/explicit restore so the file is put back even if an assertion fails mid-check.

## Data Flow

`bash src/cli.sh --version` → `cmd="--version"` → case match → path resolved from `BASH_SOURCE` →
file-existence check → `cat VERSION` to stdout / `exit 0`, or `usage:` to stderr / `exit 2`. No
other module touches VERSION; it remains the single source of truth (constraint satisfied — nothing
parses or transforms it).

## Build Sequence

1. Add the `--version` branch to `src/cli.sh`.
2. Extend `tests/test.sh` with the two new checks (success, missing-file with restore).
3. Run `bash tests/test.sh` to confirm exit 0.

## Critical Details

- Use `${BASH_SOURCE[0]}` not `$0` for path resolution, consistent with plain-bash constraint and
  robust to symlink/invocation-dir variance.
- The missing-file test mutates the real `VERSION` file in place; must restore it unconditionally
  (trap or explicit mv-back) so a failed assertion doesn't leave the repo without `VERSION`.
- Reuse the literal existing usage string rather than inventing a second message, keeping one usage
  format in the file.
- No new dependencies; `cat`/`case`/`[ -f ]` are already used or trivially plain bash.

## Patterns Followed

- Single `case "$cmd" in ... *) ... esac` dispatch, `src/cli.sh:5-10`.
- `set -u` and `${1:-}` default-empty pattern already at `src/cli.sh:3-4`, kept unchanged.
- Existing `usage:`-to-stderr, exit-2 convention at `src/cli.sh:7-8`, reused verbatim for AC2.
- Test style of small inline shell functions plus a `fail` accumulator in `tests/test.sh:3-4`.

one obvious approach — the spec itself states this (a single `--version` branch reading `VERSION`)
is the only approach worth weighing, and nothing in the codebase (one dispatch file, one test file)
suggests a genuinely different structure (e.g., extracting a version module) that isn't
over-engineering for a two-branch flag.
