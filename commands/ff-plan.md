---
description: "[feature] Turn the spec + chosen design into a phased plan.md with an Outcome gate."
argument-hint: "<run after /ff-design>"
---

# /ff-plan — feature plan phase

You are running the **plan** phase of the feature track. Output: `plan.md` with a
populated Outcome gate.

> **Precedence — read first.** You are executing the feature-flow workflow. Its phases
> REPLACE any generic brainstorming / writing-plans / make-plan / docs-first planning: do
> **not** invoke those skills, and do **not** write to `~/.claude/plans/`, `docs/plans/`,
> or a separate brainstorm doc. All run state lives in the `.feature-flow/<slug>/` sandbox
> and its `manifest.json`. Follow this command's steps literally, create files with the
> Write tool, run only this one phase, then STOP.

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
`updatedAt`.

**STOP.** Do not implement now. Tell the user to run `/feature-flow:ff-implement` next
(which will refuse to write code until the spec is signed off), then end your turn.
