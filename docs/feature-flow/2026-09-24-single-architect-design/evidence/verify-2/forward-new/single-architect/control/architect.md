Recommended: script-relative VERSION lookup with a dedicated `--version` case branch

## Architecture Decision
Add a `--version)` arm to the existing `case "$cmd" in` dispatch in `src/cli.sh` (before the catch-all `*)` at line 6). Resolve the `VERSION` file path relative to the script's own location (`$(dirname "${BASH_SOURCE[0]}")/../VERSION`), not the caller's `$PWD`. This keeps `--version` correct regardless of the invoking directory, matches the spec's framing of "the repo's VERSION file" (a fixed artifact, not a cwd-relative one), and costs one extra line over a naive `./VERSION` read. `cat` the file to preserve exact byte contents (including/excluding trailing newline as-is) for AC1, then `exit 0`. If the file is absent, write a `usage:`-prefixed message to stderr and `exit 2`, satisfying AC2 and staying consistent with the existing usage-message style already used by the default branch (line 7).

## Component Map
- `src/cli.sh` — insert `--version)` branch above the existing `*)` default. No other branches change; `set -u` already in effect, so use `${BASH_SOURCE[0]}` (safe, always set) rather than `$0`.
- `tests/test.sh` — add two checks:
  1. Reuse `check_exit` for `--version` exit 0, plus a small stdout-equality check (`out=$(bash src/cli.sh --version); [ "$out" = "$(cat VERSION)" ]`) for AC1.
  2. For AC2 (missing VERSION), copy `src/cli.sh` into a throwaway `mktemp -d` tree at `<tmp>/src/cli.sh` with no sibling `VERSION`, run it, assert exit 2 and stderr starts with `usage:`. This avoids mutating the real repo's `VERSION` while still exercising the real missing-file code path, and incidentally proves the script-relative resolution works.

## Data Flow
`bash src/cli.sh --version` → dispatch matches `--version` → compute `VERSION` path relative to script dir → file exists → `cat` to stdout, exit 0. Missing case → stderr `usage:` line → exit 2. No other code path is touched; `bogus` still falls through to the unchanged default branch.

## Build Sequence
1. Add the `--version` branch in `src/cli.sh`.
2. Add the two test checks in `tests/test.sh` (happy path, then temp-dir missing-VERSION path).
3. Run `bash tests/test.sh` to confirm the E2E check.

## Critical Details
- Order matters: `--version)` must precede `*)` in the case statement.
- Use `${BASH_SOURCE[0]}` for path resolution — works under `bash src/cli.sh` and when sourced/executed directly; `set -u` is already active so no unset-variable risk.
- Exact-content requirement (AC1) means no trailing `echo` reformatting — `cat` only.

## Patterns Followed
- Existing usage/exit-2 style at `src/cli.sh:7-8` reused verbatim for the missing-VERSION message.
- `tests/test.sh:4` `check_exit` helper pattern reused for the new exit-code assertions.

one obvious approach — the spec itself states no alternatives were considered, and the only real design choice (script-relative vs cwd-relative VERSION lookup) is a resolution-path detail inside this one approach, not a structural alternative.
