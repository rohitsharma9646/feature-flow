# Spec: version-flag — a --version flag for src/cli.sh

**Created:** 2026-09-24
**Track:** feature
**Status:** signed-off

## Problem

`src/cli.sh` has no way to report which version of the tool is installed. Support requests can't
tell which build a user is running.

## Expected outcome

`bash src/cli.sh --version` prints the contents of the repo's `VERSION` file and exits 0.

## Solution approaches considered

One obvious approach: read `VERSION` and print it when `--version` is the first argument — no
alternatives worth weighing.

## Assumptions (WHAT-changing)

| Statement | Confidence | Basis / evidence | If-wrong impact | Validation-required |
|---|---|---|---|---|
| none | | | | n |

## Constraints

- Plain bash; no new dependency.
- `VERSION` stays the single source of truth for the version string.

## Touchpoints

- `src/cli.sh` — add a `--version` branch.
- `tests/test.sh` — a check for the new flag.

## Edge cases

- `VERSION` file missing: print nothing on stdout, a `usage:`-style message on stderr, exit 2.

## Non-goals

- A `--help` flag or any other new flag.
- Changing how `VERSION` is bumped at release time.

## Acceptance criteria

- [ ] AC1: `bash src/cli.sh --version` prints the exact contents of `VERSION` and exits 0.
- [ ] AC2: `VERSION` missing → stderr message starting `usage:`, exit 2.

## End-to-end check

- [ ] E2E: `bash tests/test.sh` exits 0.

## Sign-off

**User signed off:** yes (2026-09-24)
