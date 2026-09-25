# Design: version-flag — a --version flag for src/cli.sh

**Spec:** `.feature-flow/version-flag/spec.md`
**Created:** 2026-09-25

## Chosen approach

**Guard-clause pre-check.** Right after `cmd="${1:-}"` in `src/cli.sh` (line 4), and before the
`case`, add a top-level `if [ "$cmd" = "--version" ]` guard. The guard:

1. resolves `VERSION` relative to the script's own location
   (`$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/VERSION`), so the result is the same
   whatever the caller's working directory;
2. if the file exists: `cat` it, exit 0 (AC1);
3. otherwise: print `usage: cli.sh <command>` to stderr, exactly the catch-all's text, then exit 2
   (AC2).

The existing `case` block stays untouched and remains a pure command router. `--version` is a
flag, not a command, so it is handled before dispatch rather than added as a case arm.

Why this one: the user declined the case-arm design ("No, I don't want that approach — find me a
different one"). The architect was re-dispatched once with that objection, and this is its
recommendation (`architect.md` § Developed on request: guard-clause pre-check). It meets the
signed spec with one conditional and no new dependency.

## Rejected alternatives

| Alternative | Why rejected |
|-------------|--------------|
| Case-arm dispatch: `--version)` arm inside the existing `case` | Declined by the user. It also mixes flag handling into the command-dispatch table. |
| `getopts`-based flag-parsing loop | Adds general option-parsing machinery for a single flag, with no extra behaviour. More code and more tests. |

## Trade-off matrix

| Option | Complexity | Risk / operational impact | Test effort |
|--------|------------|----------------------------|--------------|
| Guard-clause pre-check (chosen) | low | low | low |
| Case-arm dispatch | low | low | low |
| `getopts` loop | med | low | med |

> No extra axis: performance, security, and cost score the same for every option.

## Component map

| File / module | Responsibility | New or modified |
|---------------|----------------|-----------------|
| `src/cli.sh` | `--version` guard ahead of the `case`: resolve `VERSION` relative to the script, then print it (exit 0) or show usage on stderr (exit 2) | modified |
| `tests/test.sh` | `check_exit src/cli.sh --version 0`; a stdout check that `bash src/cli.sh --version` equals `cat VERSION`; a missing-file check that copies only `cli.sh` into a `mktemp -d` sandbox and expects exit 2 with a stderr line starting `usage:` | modified |

## Data flow

`bash src/cli.sh --version` → `cmd="--version"` → guard matches → `VERSION` path resolved from
`BASH_SOURCE[0]` → file present: bytes copied to stdout, exit 0 / file absent: `usage:` message on
stderr, exit 2. Any other `cmd` skips the guard and reaches the existing `case` unchanged.

## Risks

- The script-relative lookup assumes the `src/` → `../VERSION` layout. Accepted: that is the repo's
  layout and the spec's touchpoint. See FS2 for the symlink case.
- The usage text is duplicated between the guard and the catch-all. Accepted as a small cost: AC2
  requires matching text, and the test asserts the `usage:` prefix.

## Devil's advocate

### Failure scenarios

- **FS1:** `VERSION` exists but can't be read (for example `chmod 000`, or it is a directory).
  The `[ -f ]` test passes or misleads, `cat` fails and writes an error to stderr, and the
  unconditional `exit 0` still reports success with empty stdout. Support gets a blank version and
  a "success" exit code. Mitigation for plan/implement: exit 0 only if `cat` succeeds (for example
  `[ -r "$f" ] && cat "$f" && exit 0`), and fall through to the usage/exit-2 path otherwise.
- **FS2:** the script is run through a symlink (for example `ln -s …/src/cli.sh
  /usr/local/bin/cli`). `BASH_SOURCE[0]` then points at the symlink's directory, the lookup goes to
  `/usr/local/VERSION`, and a working install prints usage and exits 2. The spec only requires
  `bash src/cli.sh --version`, so plan should either resolve the symlink (plain bash:
  `readlink -f` where it exists) or explicitly waive this case at verify.
- **FS3:** the user's environment has `CDPATH` set. The subshell `cd` inside `$( … )` can print the
  directory it changed to on stdout. That output ends up in the resolved path, the `VERSION` lookup
  fails, and the flag exits 2 on a perfectly good checkout. Mitigation: `CDPATH= cd -- "…"` (or
  `cd … >/dev/null`).

### Edge cases & operational risk

- A trailing newline in `VERSION` is printed as-is by `cat` (satisfies AC1's "exact contents"). The
  test's `$( … )` comparison strips trailing newlines, so it is slightly lenient about this.
- An empty `VERSION` prints nothing and exits 0. The spec doesn't cover this; it is allowed.
- `--version` in a later position (`cli.sh foo --version`) is not handled, as the spec intends
  ("first argument"), and falls through to the catch-all. Extra arguments after `--version` are
  ignored.
- No migration and no operational change. `VERSION` bumping is unchanged (non-goal).
