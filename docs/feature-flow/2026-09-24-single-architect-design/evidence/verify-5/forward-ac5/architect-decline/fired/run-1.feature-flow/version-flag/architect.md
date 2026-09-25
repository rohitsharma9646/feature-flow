Recommended: script-relative VERSION lookup with a dedicated `--version` case branch

## Architecture Decision
Add a `--version)` case to the existing `case "$cmd" in ... esac` dispatch in `src/cli.sh`, placed before the catch-all `*)`. Resolve the `VERSION` file path relative to the script's own location (not `$PWD`), so the command works regardless of the caller's working directory — the only choice that keeps `VERSION` a true single source of truth for every invocation path. Use `cat` to emit its contents, preserving exact bytes (including trailing newline) per AC1. On a missing file, print nothing to stdout, emit the same `usage: cli.sh <command>` message to stderr, and exit 2, matching the existing catch-all's exact wording and exit code (reuse, not duplicate, that string).

## Component Map
- `src/cli.sh` — add near the top: `script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"` and `version_file="$script_dir/../VERSION"`. Add case arm:
  `--version) if [ -f "$version_file" ]; then cat "$version_file"; exit 0; else echo "usage: cli.sh <command>" >&2; exit 2; fi ;;`
  placed immediately above the existing `*)` arm. No other arms change.
- `tests/test.sh` — two additions:
  1. `check_exit src/cli.sh --version 0` (reuses existing helper, verifies AC1's exit code).
  2. A stdout-content check: capture `bash src/cli.sh --version`, compare to `cat VERSION`, report `ok`/`FAIL` and set `fail=1` on mismatch (verifies AC1's exact-contents requirement, which `check_exit` alone can't).
  3. An isolated AC2 check: `mktemp -d`, copy only `src/cli.sh` into it (deliberately omit `VERSION`), run `bash <tmp>/cli.sh --version`, assert stderr starts with `usage:` and exit is 2. Copying just the script (not the whole repo) is what makes "VERSION missing" reproducible without touching the real `VERSION` file.

## Data Flow
`bash src/cli.sh --version` → `$1` captured as `cmd` → case match on `--version` → resolve `$script_dir/../VERSION` → file exists → `cat` to stdout → exit 0. Missing-file path short-circuits to the shared usage/exit-2 branch, identical to the existing unknown-command behavior.

## Build Sequence
1. Add `script_dir`/`version_file` resolution and the `--version` case arm in `src/cli.sh`.
2. Add the three test additions to `tests/test.sh` (exit check, content check, isolated-missing-file check).
3. Run `bash tests/test.sh` to confirm all checks pass.

## Critical Details
- Use `${BASH_SOURCE[0]}` (not `$0`) for reliable script-dir resolution under `bash tests/test.sh`'s subshell invocation style.
- Reuse the literal existing usage string rather than inventing new wording — keeps stderr output consistent for both "unknown command" and "VERSION missing" cases, satisfying AC2's `usage:`-prefix requirement trivially.
- `set -u` is already active; `version_file` must be assigned unconditionally before the case statement to avoid unbound-variable errors.
- No new dependency: `cat`, `dirname`, `cd`, `pwd` are already implicitly relied upon by a plain-bash CLI.

## Patterns Followed
- Existing dispatch structure in `src/cli.sh:5-10` (`case "$cmd" in *) ... esac`) — new arm slots in above the catch-all, no restructuring.
- Existing usage/exit-2 convention (`echo "usage: ..." >&2; exit 2` at `src/cli.sh:7-8`) — reused verbatim for the missing-VERSION edge case.
- Existing test style in `tests/test.sh:4-5` (`check_exit` helper, `ok`/`FAIL` echo lines, `fail=1` accumulator, single `exit $fail`) — new checks follow the same shape.

one obvious approach — a single-file bash CLI with one dispatch table and one test script leaves no alternative structure: the flag must live in `cli.sh`'s existing case statement, and the check must live in `tests/test.sh`'s existing pass/fail loop; splitting version-printing into a separate script or sourcing `VERSION` into an env var would add indirection without satisfying any constraint or AC better.

## Developed on request: guard-clause pre-check

User objection (2026-09-25): "No, I don't want that approach — find me a different one." (to the case-arm design above)

Recommended: guard-clause pre-check (handle `--version` before the command `case`, not as a case arm)

**Architecture Decision**: Insert a top-level `if [ "$cmd" = "--version" ]; then …; fi` guard in `src/cli.sh` immediately after `cmd="${1:-}"`, before the `case`. `--version` is a flag, not a command, so it is intercepted in its own conditional rather than folded into the command-dispatch table. The `case` block stays exactly as-is (a pure command router with only its catch-all). Trade-off: one extra top-level `if` instead of reusing the existing construct — negligible cost, cleaner separation of "flags" from "commands" as the router grows.

**Component Map**
- `src/cli.sh`: after line 4, add the guard:
```
if [ "$cmd" = "--version" ]; then
  version_file="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/VERSION"
  if [ -f "$version_file" ]; then cat "$version_file"; exit 0; fi
  echo "usage: cli.sh <command>" >&2
  exit 2
fi
```
  The existing `case`/catch-all (lines 5-10) is untouched.
- `tests/test.sh`: reuse `check_exit` for `--version` → 0; add a stdout-comparison check (`[ "$(bash src/cli.sh --version)" = "$(cat VERSION)" ]`); add a `mktemp -d` sandbox check that copies only `src/cli.sh` into a fresh dir (no sibling `VERSION`) and asserts exit 2, reusing `check_exit`.

**Data Flow**: invocation → `cmd` captured → guard tests `cmd == "--version"` → resolves `VERSION` path relative to `BASH_SOURCE[0]` (cwd-independent) → `cat` + exit 0, or usage-to-stderr + exit 2 → any other `cmd` falls through unchanged into the existing `case`.

**Build Sequence**: add the guard; manually verify `--version` and a missing-file case; extend `tests/test.sh` with the three checks; run `bash tests/test.sh`.

**Critical Details**: path resolution stays cwd-independent; the missing-file error text matches the existing catch-all's `usage:` string verbatim; the sandbox test copies only `cli.sh` (not `VERSION`).

**Patterns Followed**: `set -u` and `cmd="${1:-}"` at `src/cli.sh:3-4`; `usage: cli.sh <command>` at `src/cli.sh:7`; `check_exit` helper at `tests/test.sh:4`.

Rejected: case-arm dispatch (the previously declined design) — folds flag handling into the command-dispatch table, coupling flag parsing to command routing — complexity: low, risk: low, test effort: low
Rejected: getopts-based flag-parsing loop — replaces a single static check with generalized option-parsing machinery, adding indirection with no added behavior for one flag — complexity: med, risk: low, test effort: med
