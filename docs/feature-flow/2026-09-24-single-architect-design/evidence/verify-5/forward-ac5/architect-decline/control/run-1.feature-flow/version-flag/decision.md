---
tags: [cli, versioning, bash]
referencedFiles:
  - src/cli.sh
  - tests/test.sh
  - VERSION
---

# Decision: --version is a case arm in src/cli.sh that prints VERSION resolved from the script dir

**Spec:** `.feature-flow/version-flag/spec.md`
**Created:** 2026-09-25

## Decision

`src/cli.sh` handles `--version` as an arm of its single `case "$cmd"` dispatch, `cat`-ing the
repo-root `VERSION` located relative to the script (`${BASH_SOURCE[0]}`), with `usage:` + exit 2
when it cannot be read.

## Context

Support can't tell which build a user runs; `VERSION` already exists at the repo root but no script
reads it. The spec locks `VERSION` as the single source of truth and forbids new dependencies.

## Options considered

| Option | Why considered / rejected |
|--------|----------------------------|
| `--version)` case arm, script-relative `VERSION` | chosen — see Chosen + rationale below |

One obvious approach: the spec states no alternatives worth weighing, `cli.sh` has exactly one
dispatch mechanism to extend, and plain bash with no dependency rules out other shapes.

## Trade-offs

| Option | Effort | Risk | Reversibility |
|--------|--------|------|----------------|
| `--version)` case arm (chosen) | low | low | easy to undo |

## Chosen + rationale

It is the smallest change and the idiomatic way `cli.sh` already grows; resolving from the script
dir makes it cwd-independent, and `cat` keeps AC1's exact bytes. The failure modes it must guard
against are **FS1** and **FS2** in the design's `## Devil's advocate` section
(`.feature-flow/version-flag/design.md`). Reopen only if `cli.sh` moves to a different dispatch
mechanism or the version stops living in `VERSION`.

**Related ACs:** AC1, AC2
**Related files:** src/cli.sh, tests/test.sh, VERSION

## Outcome

Pending implementation.

## Future considerations

Symlinked installs are not supported (lookup is next to the link); revisit if `cli.sh` is ever
installed via symlink onto `PATH`. A `--help` flag is out of scope (spec non-goal).
