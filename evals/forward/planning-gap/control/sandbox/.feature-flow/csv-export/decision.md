---
tags: [csv, export]
referencedFiles:
  - src/export.sh
---

# Decision: CSV export is a three-stage pipeline

**Spec:** `spec.md`
**Created:** 2026-09-20

## Decision

`rows.sh` → `csv.sh` → `export.sh`, each independently runnable.

## Context

Separate data access from encoding.

## Options considered

| Option | Why considered / rejected |
|--------|----------------------------|
| three scripts | chosen |
| one script | harder to test |

## Trade-offs

| Option | Effort | Risk | Reversibility |
|--------|--------|------|----------------|
| three scripts | low | low | easy to undo |

## Chosen + rationale

Each stage testable alone.

**Related ACs:** AC1, AC2, AC3
**Related files:** src/rows.sh, src/csv.sh, src/export.sh

## Outcome

Pending implementation.

## Future considerations

None.
