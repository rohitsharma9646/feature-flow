Recommended: inline --version case branch in src/cli.sh, VERSION path resolved relative to script location

## Architecture Decision

Add a `--version)` arm to the existing `case "$cmd" in` dispatch in `src/cli.sh`, ahead of the
catch-all `*)`. The branch resolves `VERSION` relative to the script's own directory (not the
caller's cwd) so `--version` works regardless of where `cli.sh` is invoked from, `cat`s the file to
stdout (preserving exact byte content, per AC1), and `exit 0`. If the file is missing, it prints a
`usage:`-prefixed message to stderr and `exit 2`, matching the existing default-case style. This is
the only sane approach for a two-line spec constrained to "plain bash, no new dependency" — the case
statement is already the tool's sole dispatch mechanism (explore.md), so a new arm is the smallest
change that is also the idiomatic way this file already grows.

## Component Map

- `src/cli.sh` — add one `case` arm:
  - `version_file="$(dirname "${BASH_SOURCE[0]}")/../VERSION"` computed once near the top (or inline
    in the arm) so the flag doesn't depend on cwd.
  - `--version)` arm: `if [ -f "$version_file" ]; then cat "$version_file"; exit 0; else echo "usage: cli.sh --version: VERSION file not found" >&2; exit 2; fi`
- `tests/test.sh` — add one `check_exit`-style line for the missing-VERSION exit-2 case (reusing the
  existing `check_exit` helper, which only checks exit code) plus a new stdout-content check, since
  `check_exit` discards stdout. Add a small `check_version_output` helper (or inline `[ "$(bash src/cli.sh --version)" = "$(cat VERSION)" ]`) to assert AC1's exact-content requirement; `check_exit src/cli.sh --version 0` alone only covers the exit code.

## Data Flow

`bash src/cli.sh --version` → `$1` captured as `cmd` → case match on `--version` → resolve
`VERSION` path from `BASH_SOURCE[0]` → file exists → `cat` streams file bytes to stdout → `exit 0`.
Missing-file path: same match → `[ -f ... ]` false → stderr usage line → `exit 2`, no stdout output.

## Build Sequence

1. Add the `version_file` path computation and `--version)` arm in `src/cli.sh`.
2. Extend `tests/test.sh` with the two new checks (content match, and exit 2 covered by a
   VERSION-missing scenario — see below).
3. Run `bash tests/test.sh` to confirm E2E.

## Critical Details

- **Path resolution**: use `${BASH_SOURCE[0]}` (not `$0`) so the lookup is robust if `cli.sh` is
  ever sourced or invoked via a symlink/relative path from another directory; this matches the only
  safe way to locate a sibling file in bash without adding a dependency.
- **Exact-content requirement (AC1)**: `cat` (not `echo "$(cat ...)"`) preserves the file's trailing
  newline and exact bytes; using command substitution would strip trailing newlines and silently
  violate AC1.
- **Missing-VERSION test (AC2)**: `tests/test.sh` cannot easily delete the real `VERSION` file
  in-place without affecting other checks; the cleanest test-level approach is to invoke a copy of
  `cli.sh` from a temp dir with no `VERSION` sibling, or `mv VERSION VERSION.bak`, run the check, then
  restore in a trap — keep this contained to a single new test line/block so it doesn't destabilize
  existing checks. This is a test-file detail for the plan phase, not a src/cli.sh design change.
- **No interaction with the existing default case**: `--version` must be matched before `*)` in the
  same `case`, and no other branches exist to conflict with (explore.md: `cli.sh` currently has only
  the catch-all).

## Patterns Followed

- Dispatch stays a single `case "$cmd" in` in `src/cli.sh:5` — the new arm is added alongside the
  existing `*)` arm (`src/cli.sh:6-9`), not a separate if/elif chain.
- Error style matches the existing usage message: `usage: cli.sh <command>` to stderr with `exit 2`
  (`src/cli.sh:7-8`) — the new missing-VERSION message follows the same `usage: ...` / stderr / exit
  2 convention.
- Test style matches `tests/test.sh`'s existing `check_exit` helper (`tests/test.sh:4`) and its
  flat, no-framework sequential-check pattern (`tests/test.sh:5`).

one obvious approach — the spec itself states "no alternatives worth weighing," the codebase has exactly one dispatch mechanism (a single case statement) to extend, and the constraint (plain bash, no new dependency) rules out any structurally different design.
