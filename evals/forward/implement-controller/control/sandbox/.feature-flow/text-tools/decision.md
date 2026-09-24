---
tags: [text-tools, bash]
referencedFiles:
  - src/trim.sh
  - src/words.sh
  - src/cli.sh
---

# Decision: three standalone bash scripts

**Spec:** `.feature-flow/text-tools/spec.md`
**Created:** 2026-09-24

## Decision

Three standalone bash scripts under `src/`, each reading `$1`, plus a dispatching `src/cli.sh`.

## Chosen + rationale

Smallest structure that lets other scripts call each utility directly.

## Outcome

Pending implementation.
