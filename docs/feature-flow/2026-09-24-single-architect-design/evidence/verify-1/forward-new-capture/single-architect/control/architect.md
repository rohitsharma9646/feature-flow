Recommended: Script-relative VERSION lookup with a dedicated `--version` case branch and byte-exact `cat`

## Patterns & Conventions Found

- `src/cli.sh:3-10` — single `case "$cmd" in ... *) usage; exit 2 ;; esac` dispatch, `set -u`, no functions, no helper libs. Any new flag must be a new `case` arm added *before* the catch-all `*)`.
- The usage message is a literal, duplicated-by-hand string: `"usage: cli.sh <command>"` (`src/cli.sh:7`). AC2 requires a message that "starts with `usage:`" — reusing the exact existing string satisfies this with zero new vocabulary.
- `tests/test.sh:4` defines one helper, `check_exit`, which only checks exit code (stdout/stderr both discarded to `/dev/null`). AC1/AC2 need stdout-content and stderr-prefix assertions that don't exist yet — new helper(s) are needed, following the same one-liner, `fail=1`-on-mismatch style already established.
- `VERSION` (repo root, content `1.0.0\n`) is currently unread by anything — it's the designated single source of truth per constraints.
- Everything in this repo assumes invocation from the repo root (`tests/test.sh` calls `bash "$1"` with the relative path `src/cli.sh`), but nothing currently makes `cli.sh` itself CWD-independent.

## Architecture Decision

Resolve `VERSION` **relative to the script's own location** (`BASH_SOURCE[0]`), not relative to the caller's CWD, and print it with `cat` (not `echo`) so trailing-newline fidelity is exact regardless of whether `VERSION` ends with a newline or not.

Rationale:
- `cat "$VERSION_FILE"` streams the file's bytes unmodified → satisfies "prints the exact contents" precisely, including edge cases (no trailing newline, embedded blank lines, etc.). `echo "$(cat VERSION)"` or `printf '%s\n' "$(<file)"` would strip/alter trailing newlines via command substitution — wrong.
- Script-relative resolution (`script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"`, `version_file="$script_dir/../VERSION"`) makes `--version` work correctly no matter what the caller's CWD is, which is what lets AC2 be tested cleanly: copy just `src/cli.sh` into an isolated temp directory (no sibling `VERSION`) and invoke it there — the real repo's `VERSION` is never touched or deleted, and the script's own lookup logic (not a CWD trick in the test) is what's being exercised. This is more robust than a CWD-relative `VERSION` literal and costs only 2 extra lines.
- Reusing the exact existing usage string for both the unknown-command branch and the missing-VERSION branch keeps "usage:" as a single conceptual message and avoids inventing new copy (non-goal: no `--help`, so keep the message minimal and unchanged in wording).

## Component Design

**`/tmp/ff-forward-wHpM7S/src/cli.sh`** (modify)
- Add two lines after `cmd="${1:-}"` to compute `script_dir` and `version_file`.
- Add a `--version)` arm before `*)` that: if `version_file` exists and is a regular file, `cat` it and `exit 0`; else print the usage line to stderr and `exit 2`.
- No stdout on the failure path (only `cat` ever writes to stdout, and it's skipped entirely when the file is missing) — satisfies AC2's "nothing on stdout" naturally, no `>/dev/null` needed.
- Keep `set -u` and the existing `*)` branch byte-for-byte unchanged.

**`/tmp/ff-forward-wHpM7S/tests/test.sh`** (modify)
- Add `check_version_ok()`: runs `bash src/cli.sh --version`, captures exit code and stdout to a temp file, asserts exit 0 and `cmp -s "$out" VERSION` (byte-exact comparison against the real file — avoids `$( )` newline-stripping pitfalls).
- Add `check_version_missing()`: `mktemp -d`, `cp src/cli.sh "$tmpdir/"`, run `bash "$tmpdir/cli.sh" --version` with stdout/stderr captured to separate temp files, assert exit 2, stdout file is empty (`[ ! -s "$out" ]`), and stderr matches `^usage:` (`grep -q '^usage:' "$err"`). Clean up temp dir/files (use `trap` or explicit `rm -rf` at the end of the function).
- Keep `check_exit src/cli.sh bogus 2` (existing line) untouched — it's still valid coverage for the default branch.
- Call both new checks, keep `exit $fail` as the final line.

**`/tmp/ff-forward-wHpM7S/VERSION`** — unchanged, remains the single source of truth.

**`/tmp/ff-forward-wHpM7S/README.md`** — not touched (non-goal is limited to not adding `--help`/other flags; README has no per-flag documentation section to extend, so leave it as is to avoid scope creep).

## Data Flow

1. User/tests invoke `bash src/cli.sh --version` (any CWD).
2. `cmd="--version"` matches the new `case` arm.
3. `script_dir` resolves to the absolute directory containing `cli.sh` (via `BASH_SOURCE[0]` + `dirname` + `cd`/`pwd`), independent of CWD.
4. `version_file="$script_dir/../VERSION"` → repo root's `VERSION`.
5. If present: `cat "$version_file"` streams exact bytes to stdout, `exit 0`.
6. If absent: `echo "usage: cli.sh <command>" >&2; exit 2` — stdout untouched (empty).
7. `tests/test.sh` asserts both branches: real-repo run (AC1) and copied-to-tempdir run with no sibling `VERSION` (AC2).
8. `bash tests/test.sh` aggregates `fail` across all `check_*` calls and exits 0 only if every check passed (E2E).

## Build Sequence

1. Edit `src/cli.sh`:
   - [ ] Add `script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"` after `cmd="${1:-}"`.
   - [ ] Add `version_file="$script_dir/../VERSION"`.
   - [ ] Insert `--version)` case arm before `*)`, implementing the cat-or-usage/exit-2 logic above.
   - [ ] Leave `*)` branch and `set -u` untouched.
2. Edit `tests/test.sh`:
   - [ ] Add `check_version_ok()` helper (temp file + `cmp -s` against repo-root `VERSION`).
   - [ ] Add `check_version_missing()` helper (temp dir, copy `cli.sh`, run in isolation, assert exit 2 / empty stdout / `usage:`-prefixed stderr, clean up).
   - [ ] Invoke both new helpers after the existing `check_exit` call.
   - [ ] Confirm `exit $fail` still terminates the script.
3. Manually trace both ACs against the new code (no execution needed for this design phase, but verify logic by inspection):
   - [ ] AC1: `cat` of real `VERSION` → stdout `1.0.0\n`, exit 0.
   - [ ] AC2: missing `VERSION` in temp dir → no stdout, `usage:`-prefixed stderr, exit 2.
4. Confirm no other file (README, manifest) needs changes given the stated non-goals.

## Critical Details

- **Newline fidelity**: `cat` guarantees byte-exact output; the test's `cmp -s "$out" VERSION` is likewise byte-exact (safer than `[ "$(cat "$out")" = "$(cat VERSION)" ]`, which would silently pass even if trailing newlines differed, since command substitution strips trailing newlines).
- **Isolation for AC2**: copying `cli.sh` alone (not `VERSION`) into a fresh `mktemp -d` directory is the mechanism that lets the test exercise "VERSION missing" without ever deleting or mutating the real repo-root `VERSION` — important since `VERSION` is the single source of truth and must remain untouched by the test run.
- **Error message reuse**: both the unknown-command and missing-VERSION paths emit the identical existing `"usage: cli.sh <command>"` string — satisfies "starts with `usage:`" without inventing new wording, consistent with the non-goal of not building out `--help`.
- **No new dependencies**: `cat`, `dirname`, `cd`, `pwd`, `mktemp`, `cmp`, `grep` are all POSIX/coreutils, already implicitly available given `bash` + existing test infra.
- **Order of `case` arms matters**: `--version)` must precede `*)` or it will never match.
- **Cleanup**: `check_version_missing` must remove its `mktemp -d` directory and any temp output files on both success and failure paths to avoid leaking `/tmp` entries across repeated test runs (use `rm -rf "$tmpdir" "$out" "$err"` at the end of the function, or a `trap ... RETURN`/EXIT if the shell dialect in use supports it inside a function — plain `rm -rf` at function end is simplest and matches the codebase's terse style).

Rejected: CWD-relative VERSION lookup (`cat VERSION` / `cat "./VERSION"`, no BASH_SOURCE resolution) — simpler by 2 lines, but ties correct AC1 behavior to the caller's working directory being the repo root (nowhere enforced or documented), and makes the AC2 isolation test rely on an extra `cd` into the temp dir rather than the script's own logic, which is a weaker/less direct test of "missing VERSION" behavior — complexity: low, risk: med, test effort: low.
Rejected: Embed the version string at build/release time instead of reading VERSION at runtime (e.g., a generated `src/version.sh` or sed-substituted constant) — directly violates the stated constraint that VERSION stays the single source of truth and "no new dependency"/no new build step is implied by "plain bash"; adds a generation step with no benefit here — complexity: med, risk: med, test effort: med.
