Recommended: inline `--version` case branch in cli.sh, resolved against script directory

## Architecture Decision

Add one `--version)` case arm to the existing `case "$cmd" in ... esac` dispatch in `src/cli.sh`
(explore.md, spec.md touchpoints), placed before the `*)` fallback. This is the smallest change
that satisfies the spec and matches the file's only existing pattern (a single case statement with
no helper functions, `set -u`, exit-code dispatch). No new file, no new abstraction — a one-command
CLI doesn't warrant a version-printing helper or module.

The `VERSION` file is resolved relative to the script's own location (`dirname "${BASH_SOURCE[0]}"`),
not the caller's `$PWD`. `tests/test.sh` happens to invoke `bash src/cli.sh ...` from the repo root
today, so `$PWD`-relative would also pass, but script-relative costs one extra line and removes a
latent bug (the flag breaking if invoked with a different cwd) — worth it given no constraint forbids it.

## Component Map

- `src/cli.sh` — insert before the `*)` arm:
  ```
  --version)
    dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    ver="$dir/../VERSION"
    if [ -f "$ver" ]; then cat "$ver"; exit 0; else echo "usage: cli.sh <command>" >&2; exit 2; fi
    ;;
  ```
  Reuses the exact existing `"usage: cli.sh <command>"` stderr string (line 7) so both the
  no-args and missing-`VERSION` paths share one usage message — satisfies AC2's "usage:-style"
  requirement without inventing new copy.

- `tests/test.sh` — after the existing `check_exit src/cli.sh bogus 2` line, add a content-checking
  case (the existing `check_exit` helper only checks exit code, not stdout, so AC1's "exact
  contents" requirement needs a small addition, not a reuse of `check_exit`):
  ```
  got="$(bash src/cli.sh --version)"; code=$?
  if [ "$got" = "$(cat VERSION)" ] && [ "$code" = 0 ]; then echo "ok   --version"; else echo "FAIL --version"; fail=1; fi
  ```

## Data Flow

`bash src/cli.sh --version` → `$cmd` = `--version` → case match → resolve `VERSION` path via
script dir → file exists → `cat` (stdout) → `exit 0`. Missing-file path → no stdout → usage
message on stderr → `exit 2`. Test entry point unchanged: `bash tests/test.sh` runs both checks
and exits non-zero if either fails, per the file's existing `fail=0`/`exit $fail` convention.

## Build Sequence

1. Add the `--version)` case arm to `src/cli.sh`.
2. Add the stdout+exit-code check to `tests/test.sh`.
3. Run `bash tests/test.sh` to confirm both `bogus` and `--version` checks pass.

## Critical Details

- `set -u` is already in effect; the new branch introduces no unset-variable risk.
- No change to how `VERSION` is authored/bumped (non-goal respected).
- No `--help` or other flags added (non-goal respected).
- Exit codes: 0 on success, 2 on missing `VERSION`, matching the existing 2-for-usage-error
  convention already used for `bogus` commands.

## Patterns Followed

- Single `case "$cmd" in ... esac` dispatch, no functions — `src/cli.sh:5-10`.
- `usage:`-prefixed stderr message + `exit 2` for error paths — `src/cli.sh:7-8`.
- Flat `check_*` + `fail` accumulator test style — `tests/test.sh:3-6`.

one obvious approach — spec states "no alternatives worth weighing" and the change is a single
case arm plus a single test check; any structural alternative (helper script, separate version
module, sourcing a shared lib) would add indirection this one-command CLI doesn't have anywhere
else and isn't justified by a one-line feature.

## Developed on request: sourced version-module delegation

User objection (2026-09-25, verbatim): "No, I don't want that approach — find me a different one."

Recommended: sourced version-module delegation (`src/version.sh` + thin dispatch call in `cli.sh`)

**Architecture Decision**

The rejected design put both the flag-matching and the VERSION-reading/error logic inline inside one `case` arm in `src/cli.sh`. Instead, extract the version-reading logic into a new sourced library file, `src/version.sh`, exposing one function, `cli_print_version`. `src/cli.sh` sources it at the top and its `--version)` arm becomes a one-line delegation. This keeps `cli.sh` as a pure dispatcher (its header comment already says "dispatches on the first argument" — `src/cli.sh:2`) and moves the actual version-file logic, including where "VERSION" lives, into a dedicated module. It stays plain bash (`source`, no subshell/exec, no new binary dependency) and keeps `VERSION` as the single source of truth, read from exactly one place.

**Component Map**

- `src/version.sh` (new): `cli_print_version()` resolves the repo root from its own `${BASH_SOURCE[0]}` (`dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"`), then `cat`s `"$dir/VERSION"` and `return 0` if it exists, else `return 1` with **no** stderr output — the error message stays owned by `cli.sh`.
- `src/cli.sh` (modified): add `source "$(dirname "${BASH_SOURCE[0]}")/version.sh"` near the top; add
  ```
  --version)
    cli_print_version || { echo "usage: cli.sh <command>" >&2; exit 2; }
    exit 0 ;;
  ```
- `tests/test.sh` (modified): add `check_exit src/cli.sh --version 0`, plus a stdout-content check (`[ "$(bash src/cli.sh --version)" = "$(cat VERSION)" ]`) mirroring the existing `check_exit` helper style (`tests/test.sh:4`).

**Data Flow**

`bash src/cli.sh --version` → `cli.sh` sources `version.sh` (function def only) → case matches `--version` → calls `cli_print_version` → function resolves repo root, reads `VERSION`, writes to stdout, returns 0/1 → `cli.sh` exits 0, or on failure prints the shared `usage:` string and exits 2.

**Build Sequence**

Write `src/version.sh` → wire the `source` line and case arm into `cli.sh` → extend `tests/test.sh` with exit-code and content checks → run `bash tests/test.sh`.

**Critical Details**

The single `usage:` string stays defined once, in `cli.sh`, reused for both the unknown-command default and the missing-`VERSION` case (AC2). `cli_print_version` never calls `exit` itself so it's safely sourceable/testable in isolation. Testing AC2 (missing `VERSION`) needs a repo copy without the file — a follow-up for the plan phase.

**Patterns Followed**: `set -u` and case-based dispatch on `$1` (`src/cli.sh:3-5`), the self-contained bash-function test style of `check_exit` (`tests/test.sh:4`).

Rejected: inline `--version` case branch resolved via `BASH_SOURCE` directly in `cli.sh` — the design the user already explicitly rejected; inlines version-resolution logic into the dispatcher — complexity: low, risk: low, test effort: low.

Rejected: pre-dispatch flag-scanning loop that recognizes `--version` anywhere in `$@` before the case block — changes the CLI's argument model beyond what the spec needs (dispatch is `$1`-based) — complexity: med, risk: med, test effort: med.

Rejected: standalone executable helper (`exec`'d subprocess) instead of a sourced function — forks a process for a one-line read and duplicates the usage-string/exit-code contract across two scripts — complexity: med, risk: low, test effort: low.
