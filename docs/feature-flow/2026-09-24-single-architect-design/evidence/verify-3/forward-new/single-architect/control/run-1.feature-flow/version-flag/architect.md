Recommended: inline `--version` branch in the existing case statement, reading VERSION via script-relative path

## Architecture Decision
Add a dedicated `--version)` arm to the existing `case "$cmd" in` dispatch in `src/cli.sh`, placed before the current `*)` catch-all. It resolves `VERSION` relative to the script's own directory (not `$PWD`), so the flag works regardless of the caller's working directory — the one robustness detail worth adding beyond the spec's literal wording, since `tests/test.sh` invokes `bash src/cli.sh ...` from the repo root but real users may not. No new dependency, no new file: the spec's "one obvious approach" is correct and the existing dispatch structure already fits a flag naturally.

## Component Map
- `src/cli.sh` (modify): add
  ```
  --version)
    dir="$(dirname "${BASH_SOURCE[0]}")"
    if [ -f "$dir/../VERSION" ]; then cat "$dir/../VERSION"; exit 0; else echo "usage: cli.sh <command>" >&2; exit 2; fi
    ;;
  ```
  placed as a new arm above `*)`. Reuses the exact same usage string already on line 7 so there is only one message to keep in sync.
- `tests/test.sh` (modify): add two `check_exit`-style lines:
  - `check_exit src/cli.sh --version 0` — AC1 (exit code only; test.sh's helper doesn't check stdout, so this alone doesn't verify content — see below).
  - one added stdout-content assertion, e.g. `[ "$(bash src/cli.sh --version)" = "$(cat VERSION)" ] || { echo FAIL...; fail=1; }`, to actually cover AC1's "prints the exact contents" clause, since `check_exit` discards stdout.
  - VERSION-missing case (AC2) is exit-code only (`check_exit`), matching the existing style; no fixture needed since AC1's positive-content check already covers the present-file path.

## Data Flow
Invocation `bash src/cli.sh --version` → `$1` matched in the case statement → script resolves `VERSION`'s path from `BASH_SOURCE[0]`'s directory → file read via `cat` (stdout) or absent → `usage:` message (stderr) + exit 2. No transformation of the version string; it is passed through verbatim per the constraint that VERSION is the single source of truth.

## Build Sequence
1. Add the `--version)` arm in `src/cli.sh`.
2. Add the two assertions to `tests/test.sh` (content check + exit-code check).
3. Run `bash tests/test.sh` to confirm exit 0.

## Critical Details
- `set -u` is already active; `dirname "${BASH_SOURCE[0]}"` is safe under it.
- Exit codes: 0 on success, 2 on missing VERSION, matching the existing `*)` convention exactly (same message and code) so there's no new failure vocabulary.
- No change to `VERSION`'s bump process — only read, never written.
- Testing the missing-VERSION path without disturbing the real file isn't exercised in `tests/test.sh` since doing so would require moving/restoring the repo's actual VERSION; per spec's non-goals (no scope beyond the flag) this is acceptable to leave to the exit-code-only check already listed, run against the real (present) file for AC1 and trusted by code inspection for AC2's branch.

## Patterns Followed
- Dispatch via `case "$cmd" in ... *)` — `src/cli.sh:5-10`.
- Existing usage/exit-2 idiom reused verbatim — `src/cli.sh:7-8`.
- Test style: one `check_exit` line per case, `fail` flag pattern — `tests/test.sh:4-5`.

one obvious approach — spec explicitly states no alternatives worth weighing, and the existing single-file, single-dispatch structure has no seam that would make a different structure (e.g., a separate version.sh sourced by cli.sh) anything but unnecessary indirection for one flag.
