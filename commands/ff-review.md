---
description: "[shared] Fan out read-only reviewers at the configured threshold and consolidate into review.md."
argument-hint: "<run after /feature-flow:ff-implement>"
---

# /feature-flow:ff-review — review phase

Static review of the implemented change. Output: `review.md`.

> **Precedence — read first.** You are executing the feature-flow workflow. Its phases
> REPLACE any generic brainstorming / writing-plans / make-plan / docs-first planning: do
> **not** invoke those skills, and do **not** write to `~/.claude/plans/`, `docs/plans/`,
> or a separate brainstorm doc. All run state lives in the `.feature-flow/<slug>/` sandbox
> and its `manifest.json`. Follow this command's steps literally, create files with the
> Write tool, run only this one phase, then STOP.

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

## Update manifest + hand off (order differs by track)

Set `phases.review = { status: "complete", artifact: "review.md" }`, bump `updatedAt`.

- **Feature track:** review runs **before** verify. Leave `currentPhase = "review"` and
  **STOP**, telling the user to run `/feature-flow:ff-verify` next.
- **Bugfix track:** review is the **terminal** phase (it runs after verify). If verify has
  already passed (`phases.verify.status == "complete"`) and this review surfaced no blocking
  issue, set `currentPhase = "done"`. **STOP** and report the run complete. If review found
  a blocking issue, leave `currentPhase = "review"` and tell the user what to fix.

End your turn.
