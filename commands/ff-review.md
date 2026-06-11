---
description: "[shared] Fan out read-only reviewers at the configured threshold and consolidate into review.md."
argument-hint: "<run after /ff-implement>"
---

# /ff-review — review phase

Static review of the implemented change. Output: `review.md`.

## Manifest contract

1. Resolve config + manifest. Read `reviewThreshold` (default 80) and `reviewerAgents`
   (default 3).
2. Set `phases.review.status = "in_progress"`, bump `currentPhase`.

## Cold-start

If nothing has been implemented yet, review whatever is in the working tree and note
explicitly that this is a pre-implementation / partial review.

## Do the work

Dispatch `reviewerAgents` **`ff-code-reviewer`** agents in parallel with differentiated
focuses:
- **simplicity** — unneeded complexity, duplication, simpler equivalents.
- **bugs** — logic errors, null/edge handling, races, security.
- **conventions** — CLAUDE.md / project-guideline adherence.

Pass each the `reviewThreshold` from config; they report only issues scoring ≥ threshold.
On a greenfield / non-git project, point them at the working-tree files instead of a diff.

Consolidate findings (de-duplicate across agents) into `review.md` from
`${CLAUDE_PLUGIN_ROOT}/templates/review.md`: Critical vs Important, each with file:line,
issue, and a concrete fix. If nothing meets the threshold, record the "no high-confidence
issues" summary — do not invent findings to look thorough.

## Update manifest

Set `phases.review = { status: "complete", artifact: "review.md" }`, bump `updatedAt`.
Next: `/ff-verify`.
