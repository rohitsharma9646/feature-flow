Recommended: inline --version branch reading VERSION via script-relative path

## Architecture Decision

Add a `--version` case to the existing `case "$cmd" in` dispatch in `src/cli.sh`, resolving
`VERSION`'s path relative to the script's own location (not the caller's cwd), so the flag works
regardless of where `cli.sh` is invoked from. This is the only approach worth building: the spec
already names it as the one obvious solution, the change is a few lines inside the existing
dispatch structure, and it needs no new files, functions, or dependencies.

## Component Map

- `src/cli.sh` — add one case arm above the catch-all `*)`:
  - Compute `dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"` and `version_file="$dir/../VERSION"`.
  - `--version)` arm: if `[ -f "$version_file" ]`, `cat "$version_file"` and `exit 0`; else print
    `usage: cli.sh --version: VERSION file not found` to stderr and `exit 2`.
  - Keep the existing `*)` arm (usage + exit 2) unchanged for all other/unknown commands.

- `tests/test.sh` — add one line exercising the new flag:
  - `check_exit src/cli.sh --version 0` (reuses existing helper, confirms exit code).
  - Add a second, minimal check that stdout equals the `VERSION` file's contents, e.g.:
    `out="$(bash src/cli.sh --version)"; [ "$out" = "$(cat VERSION)" ] && echo ok... || fail=1`.
  - Missing-VERSION edge case (AC2) is not exercised in this shared test file since it requires
    temporarily hiding the real `VERSION`; note it as covered by manual/AC review only, or add a
    subshell test that `mv`s VERSION aside, runs the check, and restores it — acceptable given the
    test script already runs from repo root and has no cleanup trap infrastructure to extend.

## Data Flow

`bash src/cli.sh --version` → `case` matches `--version` → resolve `VERSION` path from
`BASH_SOURCE` → file exists → `cat` prints exact contents to stdout → `exit 0`. If file missing →
stderr usage-style message → `exit 2`. No other command path is touched.

## Build Sequence

1. Add path resolution + `--version)` arm to `src/cli.sh`, before the `*)` fallback.
2. Add the new assertions to `tests/test.sh`.
3. Run `bash tests/test.sh` to confirm both new and existing checks (including `bogus` → exit 2)
   still pass.

## Critical Details

- Path resolution must use `${BASH_SOURCE[0]}`, not `$0`, so the flag works whether invoked as
  `bash src/cli.sh` or `./src/cli.sh` from any cwd — this is the one subtlety not obvious from the
  spec's one-liner description.
- Exact-contents requirement (AC1) means using `cat`, not `echo "$(cat ...)"`, to preserve any
  trailing newline exactly as stored in `VERSION`.
- `set -u` is already active; the new arm must not reference unset variables.
- No new dependency, no change to how `VERSION` is bumped — matches stated constraints/non-goals.

## Patterns Followed

- Existing `case "$cmd" in ... *) ... ;; esac` dispatch structure in `src/cli.sh:5-10`.
- Existing usage/exit-2 convention on stderr, e.g. `echo "usage: cli.sh <command>" >&2; exit 2`
  (`src/cli.sh:7-8`), reused verbatim in style for the missing-VERSION edge case.
- Existing `check_exit` helper pattern in `tests/test.sh:4-5` for exit-code assertions.

one obvious approach — spec explicitly states there are no alternatives worth weighing, and the
change is a single conditional branch inside an already-tiny dispatch script; any restructuring
(e.g., extracting a version-lookup function/module) would be over-engineering for a one-line
feature and adds no testability or clarity benefit here.
