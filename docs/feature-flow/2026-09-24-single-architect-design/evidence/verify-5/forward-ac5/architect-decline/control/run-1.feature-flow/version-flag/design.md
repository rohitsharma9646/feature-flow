# Design: version-flag — a --version flag for src/cli.sh

**Spec:** `.feature-flow/version-flag/spec.md`
**Created:** 2026-09-25

## Chosen approach

Add a `--version)` arm to the existing `case "$cmd" in` dispatch in `src/cli.sh`, ahead of the
catch-all `*)`. The arm resolves `VERSION` relative to the script's own location
(`"$(dirname "${BASH_SOURCE[0]}")/../VERSION"`), not the caller's cwd, and:

- file present and readable → `cat` it to stdout (exact bytes, trailing newline preserved — never
  `echo "$(cat …)"`, which strips it) and exit with `cat`'s status (0 on success) — AC1;
- file missing/unreadable → print a `usage:`-prefixed message to stderr, nothing on stdout,
  `exit 2` — AC2, matching the existing default-case error style (`src/cli.sh:7-8`).

Why this one: the `case` statement is the tool's only dispatch mechanism, the spec already settled
on "read `VERSION` and print it", and "plain bash, no new dependency" leaves no structurally
different design. Full blueprint: `.feature-flow/version-flag/architect.md`.

## Rejected alternatives

| Alternative | Why rejected |
|-------------|--------------|
| — (one obvious approach) | Architect: spec states no alternatives worth weighing; single `case` dispatch to extend; plain-bash constraint rules out other shapes. Confirmed by user 2026-09-25. |

## Trade-off matrix

| Option | Complexity | Risk / operational impact | Test effort |
|--------|------------|----------------------------|--------------|
| `--version)` case arm, VERSION resolved from script dir (chosen) | low | low | low |

## Component map

| File / module | Responsibility | New or modified |
|---------------|----------------|-----------------|
| `src/cli.sh` | New `--version)` arm before `*)`; resolves and prints `VERSION`, or usage error + exit 2 | modified |
| `tests/test.sh` | AC1 exact-content check (compare `cli.sh --version` output with `VERSION`); AC2 missing-VERSION check via a copy of `cli.sh` in a temp dir with no `VERSION` sibling | modified |

## Data flow

`bash src/cli.sh --version` → `cmd=$1` → `case` matches `--version` → path =
`<script dir>/../VERSION` → readable? → `cat` bytes to stdout, exit 0.
Not readable/missing → `usage: cli.sh --version: VERSION file not found` to stderr, exit 2, empty stdout.

## Risks

- Test for AC2 must not mutate the real `VERSION` (see FS1) — mitigated by running a temp-dir copy
  of `cli.sh` instead of moving `VERSION` aside.
- `cat` failing after the existence check (see FS2) — mitigated by testing readability (`-r`) and
  propagating `cat`'s exit status instead of a hard-coded `exit 0`.

## Devil's advocate

### Failure scenarios

- **FS1:** The AC2 test moves the real `VERSION` aside (`mv VERSION VERSION.bak` + trap) and the test
  process is killed (SIGKILL, CI timeout) before the trap restores it — the repo is left with no
  `VERSION`, so every later `--version` call and any release tooling reading it breaks. The test must
  exercise the missing-file path without touching the real `VERSION` (temp-dir copy of `cli.sh`), and
  `VERSION` must be byte-identical after `bash tests/test.sh` runs.
- **FS2:** `VERSION` exists but is unreadable (e.g. mode 000, or `VERSION` is a directory): a naive
  `[ -f … ] && cat …; exit 0` prints a `cat:` error, emits nothing on stdout, and still exits 0 —
  a silent false success. The arm must exit 2 with a `usage:` stderr message (or at least non-zero)
  whenever it cannot print the contents.

### Edge cases & operational risk

- `cli.sh` invoked through a symlink from another directory: `BASH_SOURCE[0]` is the symlink path,
  so `VERSION` is looked up next to the link and the flag reports exit 2. No symlinked install exists
  today — accepted, not resolved (`readlink -f` would add a GNU-specific dependency).
- `VERSION` without a trailing newline: `cat` prints it as-is — exact contents, per AC1.
- Extra arguments after `--version` are ignored (spec only defines `$1`).
- No migration; `VERSION` bumping at release time is unchanged (non-goal).
