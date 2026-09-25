Recommended: inline --version branch in cli.sh's existing dispatch, reading VERSION via script-relative path

## Architecture Decision

Add a `--version)` case to the existing `case "$cmd" in ... esac` dispatch in `src/cli.sh`, ahead of
the catch-all `*)`. It reads the repo's `VERSION` file, resolved relative to the script's own
location (not the caller's cwd), prints its contents verbatim, and exits 0. If `VERSION` is
missing, it falls through to the same `usage:`-prefixed stderr message and exit 2 the catch-all
already produces — one message, one exit path, satisfying AC2 without new error-handling code.
This is the smallest change that satisfies the spec: no new file, no dependency, and it reuses the
dispatch structure exactly as-is (README calls it a dispatch on `$1`; this is one more branch).

## Component Map

- `src/cli.sh` — add:
  - a `version_file` resolution: `"$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/VERSION"` (or
    the simpler `"$(dirname "${BASH_SOURCE[0]}")/../VERSION"`, sufficient since the script is only
    ever run via `bash src/cli.sh`) — computed once, before the `case`.
  - `--version)` branch: `if [ -r "$version_file" ]; then cat "$version_file"; exit 0; else echo "usage: cli.sh <command>" >&2; exit 2; fi`
  - No change to the existing `*)` branch or its message.
- `tests/test.sh` — add:
  - a `check_output` helper (stdout-capturing sibling of `check_exit`) to assert
    `bash src/cli.sh --version` prints the exact `VERSION` contents and exits 0 (AC1).
  - a missing-`VERSION` case: copy `src/cli.sh` alone into a scratch temp dir (`mktemp -d`), run it
    there with `--version`, assert stderr starts with `usage:` and exit is 2 (AC2) — this exercises
    the real "file absent" path without touching the repo's own `VERSION`, and cleans up the temp
    dir afterward.

## Data Flow

`bash src/cli.sh --version` → `cmd="--version"` → case match → resolve `version_file` next to the
script → read file → stdout = file contents, exit 0. On resolution failure → stderr `usage:` line,
exit 2 — identical shape to today's unknown-command path.

## Build Sequence

1. Add the script-relative `version_file` variable and the `--version)` branch in `src/cli.sh`.
2. Extend `tests/test.sh` with `check_output` and the missing-file scratch-dir case.
3. Run `bash tests/test.sh` (E2E) to confirm exit 0.

## Critical Details

- Path resolution must use `${BASH_SOURCE[0]}`, not `$0` inside a function, and not assume cwd —
  otherwise `--version` breaks when invoked from outside the repo root.
- `cat` preserves the exact byte content of `VERSION` (including/excluding trailing newline as
  stored) — matches AC1's "exact contents" wording without any trimming.
- No new dependency, no change to how `VERSION` is bumped (non-goals respected).

## Patterns Followed

- `src/cli.sh:4-10` — existing `case "$cmd" in ... *) ... esac` dispatch; new branch slots in
  before `*)`.
- `src/cli.sh:7` — existing `usage:` stderr message and exit-2 convention, reused verbatim for the
  missing-`VERSION` edge case rather than inventing a new message.
- `tests/test.sh:4` — existing `check_exit` helper pattern; the new `check_output` helper mirrors
  its signature/style (positional args, `ok`/`FAIL` echo, `fail=1` accumulation).

one obvious approach — spec names the only approach ("read VERSION and print it... no alternatives worth weighing") and the repo is four files with no structure to choose between.
