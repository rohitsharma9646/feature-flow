# Design: version-flag — a --version flag for src/cli.sh

**Spec:** `.feature-flow/version-flag/spec.md`
**Created:** 2026-09-25

## Chosen approach

Add a `--version)` arm to the existing `case "$cmd" in` dispatch in `src/cli.sh`, above the
catch-all `*)`. The arm resolves `VERSION` relative to the script's own location —
`dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"`, `version_file="$dir/../VERSION"` — so the
flag works from any cwd. If the file is present it is `cat`-ed verbatim (exact contents, AC1) and
the script exits 0; otherwise a `usage:`-prefixed message goes to stderr and the script exits 2
(AC2), matching the existing usage/exit-2 convention (`src/cli.sh:7-8`). The `*)` arm is
unchanged.

Chosen because the spec locks this as the one obvious approach; the only real design sub-choice
is path resolution, and `${BASH_SOURCE[0]}` (not `$0`, not cwd) is what makes the flag
independent of the invocation directory. Full blueprint: `.feature-flow/version-flag/architect.md`.

## Rejected alternatives

| Alternative | Why rejected |
|-------------|--------------|
| none — one obvious approach | Spec names it as the only approach; the change is one branch in a tiny dispatch script. Extracting a version-lookup function/module would be over-engineering with no testability or clarity gain. |

## Trade-off matrix

| Option | Complexity | Risk / operational impact | Test effort |
|--------|------------|----------------------------|--------------|
| Inline `--version` arm, script-relative `VERSION` path (chosen) | low | low | low |

> Single option — no extra axis differentiates anything, so none is added.

## Component map

| File / module | Responsibility | New or modified |
|---------------|----------------|-----------------|
| `src/cli.sh` | `--version)` arm: resolve `VERSION` from `BASH_SOURCE`, print it or fail with `usage:` + exit 2 | modified |
| `tests/test.sh` | `check_exit src/cli.sh --version 0`; stdout equals `cat VERSION`; AC2 check with `VERSION` moved aside and restored | modified |

## Data flow

`bash src/cli.sh --version` → `case` matches `--version` → resolve `<script dir>/../VERSION` →
readable file → `cat` to stdout → exit 0. Missing / unreadable → `usage: ...` on stderr, nothing
on stdout → exit 2. All other commands fall through to the unchanged `*)` arm.

## Risks

- **Path resolution via `BASH_SOURCE`** — mitigates cwd dependence; does not follow symlinks
  (see FS1). Accepted: the spec's invocation is `bash src/cli.sh` and no install/symlink path exists
  in the repo.
- **`set -u`** is active — the new arm must reference only variables it sets.
- **AC2 test mutates the repo** (moves `VERSION` aside) — mitigate with a `trap` restore, or run
  against a temp copy of the script tree.

## Devil's advocate

### Failure scenarios

- **FS1:** `VERSION` present but `cat` fails (file unreadable, or `VERSION` is a directory): if the
  arm guards only with `[ -f ]` and then runs `cat "$version_file"; exit 0`, the command prints a
  `cat:` error, empty stdout, and **exits 0** — a support request sees "success" with no version.
  Guard must be `[ -f "$version_file" ] && [ -r "$version_file" ]` (or propagate `cat`'s status to
  the exit-2 path) so any unreadable state lands in the AC2 branch.
- **FS2:** `cli.sh` invoked through a symlink (e.g. `ln -s .../src/cli.sh ~/bin/cli`):
  `${BASH_SOURCE[0]}` is the symlink path, so `../VERSION` resolves next to `~/bin` and the flag
  reports `usage:` / exit 2 on a correct install. Accepted as out of scope for this spec (no
  symlinked install exists), but the behavior must be the clean AC2 failure — never a wrong file's
  contents or a crash under `set -u`.

### Edge cases & operational risk

- `VERSION` with or without a trailing newline — `cat` preserves it exactly (AC1 is "exact
  contents"); the stdout test compares via `$(...)`, which strips trailing newlines on both sides,
  so it will not catch a newline mismatch. Acceptable: `cat` cannot introduce one.
- `--version` followed by extra args (`--version foo`) — ignored; only `$1` is dispatched.
- AC2 test interrupted mid-run could leave the repo without `VERSION` — use a `trap` restore.
