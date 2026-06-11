---
description: "[feature] Turn the spec + chosen design into a phased plan.md with an Outcome gate."
argument-hint: "<run after /ff-design>"
---

# /ff-plan — feature plan phase

You are running the **plan** phase of the feature track. Output: `plan.md` with a
populated Outcome gate.

## Manifest contract

1. Resolve config + manifest (as in `/ff-explore`).
2. **Cold-start:** if no `design.md` exists, tell the user to run `/ff-design` first.
   If `spec.md` is also missing, route them back to `/ff-clarify`. Do not plan against
   nothing.
3. Read `spec.md` and `design.md`. Set `phases.plan.status = "in_progress"`, bump
   `currentPhase`.

## Do the work

Write `plan.md` from `${CLAUDE_PLUGIN_ROOT}/templates/plan.md`. Decompose the chosen
design into bite-sized tasks, each with files-to-touch and a verification step. **Populate
the Outcome gate** from the spec: spec path, acceptance criteria reference, and the
current `signOff` state (`User signed off: <no | yes (date)>` — copy from the manifest,
do not assume yes).

Resolve the plan path: if `paths.plan` is set in config, write there; else `<run dir>/plan.md`.
Record it in `artifacts.plan`.

## Update manifest

Set `phases.plan = { status: "complete", artifact: "<resolved plan path>" }`, bump
`updatedAt`. Next phase: `/ff-implement` (which will refuse to write code until the spec
is signed off).
