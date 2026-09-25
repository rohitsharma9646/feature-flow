Recommended: inline `--version` case branch reading VERSION via script-relative path

## Architecture Decision
Add a `--version)` arm to the existing `case "$cmd" in ... esac` dispatch in `src/cli.sh`, alongside the current default arm. It resolves `VERSION` relative to the script's own location (not the caller's cwd) via `dirname "${BASH_SOURCE[0]}"`, so `cli.sh --version` works regardless of where it's invoked from. On success it `cat`s the file (preserving exact bytes, including trailing newline, satisfying AC1) and exits 0; if the file is absent it prints a `usage:`-prefixed message to stderr and exits 2 (AC2), touching nothing on stdout. This is the smallest change that satisfies the spec and matches the file's existing one-branch-per-command convention — no new functions, no new file, no dependency.

## Component Map
- `src/cli.sh` — insert a `--version)` case above the existing `*)` default (src/cli.sh:5-10). New arm: resolve `version_file="$(dirname "${BASH_SOURCE[0]}")/../VERSION"`, `[ -f "$version_file" ]` guard, `cat` + `exit 0` on success, `echo "usage: ..." >&2` + `exit 2` on missing file.
- `tests/test.sh` — add a `check_exit src/cli.sh --version 0` line (reuses existing helper, tests/test.sh:4-5 pattern) plus one new inline check comparing `bash src/cli.sh --version` stdout against `cat VERSION` for content correctness. Add a third check for the missing-VERSION edge case (see below).

## Data Flow
`bash src/cli.sh --version` → case dispatch matches `--version` → path resolved relative to script → file read → contents streamed to stdout unmodified → exit 0. Missing-file path never touches stdout; only stderr + exit 2.

## Build Sequence
1. Add the `--version` arm to `src/cli.sh`.
2. Extend `tests/test.sh` with exit-code and content checks for the happy path.
3. Add a non-destructive missing-VERSION check (see below) and confirm `bash tests/test.sh` exits 0.

## Critical Details
- Use `dirname "${BASH_SOURCE[0]}"`, not `pwd`, so the flag works from any invocation directory — matches the "single source of truth" constraint since it always reads the one real repo `VERSION`.
- `cat` (not `echo "$(cat ...)"`) to avoid trailing-newline stripping — AC1 requires *exact* contents.
- Missing-file test must not delete/rename the real `VERSION` (destructive, racy under parallel test runs). Instead, copy just `src/cli.sh` into a fresh `mktemp -d` sibling `src/` dir (no `../VERSION` alongside it) and invoke it from there — exercises the missing-file branch safely, then `rm -rf` the temp dir.
- `set -u` already active in cli.sh; the new branch introduces no unset-variable risk since `version_file` is always assigned before use.

## Patterns Followed
- Case-statement dispatch on `$1`, `set -u`, `usage: ...` stderr message and exit 2 for the unknown-command path — src/cli.sh:3-10.
- `check_exit` helper style (`bash "$1" "$2" >/dev/null 2>&1; ...`) and single-line `if/then/echo/fail=1` idiom — tests/test.sh:4.

one obvious approach — the fix is a single branch in an existing dispatch statement in a ~10-line file; any alternative (separate version-lookup function/file, wrapper script, sourcing VERSION as a var) adds indirection the spec's constraints (plain bash, no new dependency, VERSION stays sole source of truth) don't call for.
