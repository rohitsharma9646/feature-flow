Recommended: inline `--version` case branch in src/cli.sh, resolving VERSION relative to the script's own directory

## Architecture Decision

Add a `--version)` arm to the existing `case "$cmd" in ... esac` dispatch in `src/cli.sh`, ahead of
the `*)` fallback. Resolve the path to `VERSION` relative to the script's own location (not the
caller's cwd) so the flag works regardless of where `cli.sh` is invoked from — a one-line
robustness improvement consistent with "VERSION stays the single source of truth," since a
cwd-relative lookup would silently break under `cd tests && bash ../src/cli.sh --version`. This is
the smallest change that satisfies the spec and matches the file's existing single-`case` style.

## Component Map

- `src/cli.sh` — modify only.
  - Before the `case` (or inside it), compute `version_file="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/VERSION"`.
  - Add `--version)` arm: if `version_file` exists, `cat "$version_file"; exit 0`; else print
    `usage: VERSION file missing` (or similar `usage:`-prefixed message) to stderr and `exit 2`.
  - Leave the `*)` arm and its `usage: cli.sh <command>` message untouched — it already satisfies
    the generic "unknown command" path and stays the fallback for everything except `--version`.
- `tests/test.sh` — modify only.
  - Add `check_exit src/cli.sh --version 0` using the existing `check_exit` helper (spec's E2E only
    requires exit-code checks; the helper already discards stdout, matching its current style at
    tests/test.sh:4-5).

## Data Flow

`bash src/cli.sh --version` → `cmd="--version"` → case matches → resolve `VERSION` path from
`BASH_SOURCE[0]`'s directory → `cat` file to stdout, `exit 0`. Missing-file path: same match →
existence check fails → stderr message, `exit 2`. No other code path is touched.

## Build Sequence

1. Edit `src/cli.sh`: add path resolution + `--version)` arm.
2. Edit `tests/test.sh`: add the one `check_exit` line for `--version`.
3. Run `bash tests/test.sh` to confirm both old and new checks pass.

## Critical Details

- Use `cat` (not `echo "$(cat ...)"`) so AC1's "exact contents" (including the file's own trailing
  newline) is preserved verbatim.
- `set -u` is already active (src/cli.sh:3); the added code must not reference unset variables.
- Missing-`VERSION` message must start with literal `usage:` per AC2 — reuse the existing
  `usage:` prefix style already used at src/cli.sh:7 for consistency.
- No new dependresidency: `cat`, `dirname`, `cd`, `pwd` are bash builtins/coreutils already implied
  by the script's shebang.

one obvious approach — spec already states "no alternatives worth weighing," and the only real
design freedom (cwd-relative vs script-relative VERSION lookup) is a detail folded into the chosen
approach above, not a structurally different one.
