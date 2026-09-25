---
tags: [cli, version, flag-parsing, bash]
referencedFiles:
  - src/cli.sh
  - tests/test.sh
  - VERSION
---

# Decision: handle `--version` in a guard clause before the command `case` in src/cli.sh

**Spec:** `.feature-flow/version-flag/spec.md`
**Created:** 2026-09-25

## Decision

`src/cli.sh` handles top-level flags such as `--version` in a guard clause placed before the
command-dispatch `case`. The `case` stays a pure command router. `VERSION` is resolved relative to
the script's location.

## Context

`src/cli.sh` had no way to report its version, and the repo-root `VERSION` file was unused. The
architect first proposed a `--version)` case arm. The user rejected it ("No, I don't want that
approach — find me a different one"), and the re-dispatched architect produced this design.

## Options considered

| Option | Why considered / rejected |
|--------|----------------------------|
| Guard-clause pre-check | chosen — see Chosen + rationale below |
| Case-arm dispatch | Declined by the user. It also mixes flag handling into command routing. |
| `getopts` loop | Too much machinery for one flag. Higher complexity and test effort, no extra behaviour. |

## Trade-offs

Derived from design.md `## Trade-off matrix`: Effort comes from Complexity + Test effort, Risk from
Risk / operational impact.

| Option | Effort | Risk | Reversibility |
|--------|--------|------|----------------|
| Guard-clause pre-check | low | low | easy to undo |
| Case-arm dispatch | low | low | easy to undo |
| `getopts` loop | med | low | easy to undo |

## Chosen + rationale

Guard-clause pre-check. It ties with the case arm on effort and risk. It keeps flags separate from
commands and follows the user's explicit rejection of the case arm. It is also cheaper than a
`getopts` loop that the spec's single flag doesn't need. The main known ways it can fail are
recorded as FS1–FS3 in design.md `## Devil's advocate` (unreadable `VERSION`, symlinked invocation,
`CDPATH`). Plan and implement must handle them or verify must waive them. Reopen this decision if
the CLI gains several flags; a real option parser might then be justified.

**Related ACs:** AC1, AC2, E2E
**Related files:** src/cli.sh, tests/test.sh, VERSION

## Outcome

Pending implementation.

## Future considerations

- `getopts` or a parsing loop is deliberately deferred. Revisit when a second flag is in scope
  (`--help` is currently a non-goal).
- Symlink-safe resolution (FS2) may be waived for this run. Revisit if the CLI is ever installed
  onto `PATH`.
