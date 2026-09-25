Recommended: inline --version case branch reading VERSION relative to script location

## Architecture Decision
Add a `--version)` case to the existing `case "$cmd" in ... esac` dispatch in `src/cli.sh`, matching the single dispatch point already used for `*)`. Resolve `VERSION`'s path relative to the script's own directory (not `$PWD`) so the flag works regardless of the caller's working directory, and to keep `VERSION` as the single source of truth without duplicating its content into the script.

## Component Map
- `src/cli.sh` — add one case arm before the catch-all `*)`:
  - compute `dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"`
  - `version_file="$dir/../VERSION"`
  - if `[ -f "$version_file" ]`: `cat "$version_file"; exit 0`
  - else: `echo "usage: cli.sh --version: VERSION file not found" >&2; exit 2`
- `tests/test.sh` — add one `check_exit` line: `check_exit src/cli.sh --version 0`, plus an output-content check (new small helper or inline `[ "$(bash src/cli.sh --version)" = "$(cat VERSION)" ]`) since `check_exit` only asserts exit code, not stdout content, and AC1 requires exact content match.

## Data Flow
`$1` → case match on `--version` → path resolution via `BASH_SOURCE[0]` → file-existence check → `cat VERSION` to stdout (AC1) or usage message to stderr (AC2) → exit code.

## Build Sequence
1. Add the `--version)` arm in `src/cli.sh`, keeping `*)` as the final fallback.
2. Extend `tests/test.sh` with the exit-code check and a content-match check.
3. Run `bash tests/test.sh` to confirm E2E passes.

## Critical Details
- Use `${BASH_SOURCE[0]}` (not `$0`) for correct path resolution if the script is ever sourced; plain bash, no new dependency, satisfies the constraint.
- Missing-`VERSION` message must start with `usage:` per AC2 — do not rely on `cat`'s own error text, which doesn't match that prefix.
- `set -u` is already active; the new branch introduces no unset-variable reads.
- No stdout output on the missing-file path (AC2 requires none); `cat` is only invoked after the existence check, so no partial output risk.

## Patterns Followed
- Reuses the existing single `case "$cmd" in` dispatch structure at `src/cli.sh:5` rather than adding a second conditional layer.
- Matches the existing `usage:`-prefixed stderr + `exit 2` convention already used in the catch-all branch (`src/cli.sh:7-8`).
- Follows `tests/test.sh`'s existing `check_exit` one-liner-per-case style (`tests/test.sh:5`).

one obvious approach — spec states no alternatives worth weighing, and the only structural choice (resolving VERSION via script directory vs. cwd) is a detail folded into the design above, not a competing architecture.
