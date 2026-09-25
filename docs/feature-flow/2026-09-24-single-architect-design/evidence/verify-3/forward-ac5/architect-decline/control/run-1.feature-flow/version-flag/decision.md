---
tags: [cli, version, flag-dispatch]
referencedFiles:
  - src/cli.sh
  - tests/test.sh
  - VERSION
---

# Decision: --version as an inline case arm reading a script-relative VERSION

**Spec:** `.feature-flow/version-flag/spec.md`
**Created:** 2026-09-25

## Decision

`src/cli.sh --version` is a `case` arm in the existing dispatch that `cat`s `VERSION` resolved
relative to `${BASH_SOURCE[0]}` (not cwd); missing/unreadable → `usage:` on stderr, exit 2.

## Context

Support can't tell which build a user runs. A root `VERSION` file exists but nothing reads it; the
spec makes it the single source of truth and requires plain bash, no new dependency.

## Options considered

| Option | Why considered / rejected |
|--------|----------------------------|
| Inline `--version` arm, script-relative `VERSION` path | chosen — see Chosen + rationale below |

> One obvious option: the spec locks it, and the change is one branch in a tiny dispatch script;
> extracting a helper/module would add structure with no benefit.

## Trade-offs

| Option | Effort | Risk | Reversibility |
|--------|--------|------|----------------|
| Inline `--version` arm, script-relative `VERSION` path | low | low | easy to undo |

## Chosen + rationale

The inline arm follows the existing `case` dispatch and usage/exit-2 convention, and
`BASH_SOURCE`-relative resolution makes it cwd-independent. Its failure scenarios (unreadable
`VERSION` exiting 0; symlinked invocation) are in `design.md` §Devil's advocate. Reopen only if
the CLI grows enough flags to need a real argument parser, or gains a symlinked/installed
distribution.

**Related ACs:** AC1, AC2
**Related files:** src/cli.sh, tests/test.sh, VERSION

## Outcome

Pending implementation.

## Future considerations

Deferred: symlink-safe path resolution (`readlink -f`) and a general flag parser. Revisit when the
tool is installed via symlink/package, or when a second flag (e.g. `--help`, a current non-goal)
is added.
