---
description: "[shared] Implement the planned work, honoring the sign-off gate and tdd/worktree toggles."
argument-hint: "<run after /ff-plan, with spec signed off>"
---

# /ff-implement — implementation phase

Builds the feature (feature track). The bugfix branch is added later; for now this
command serves the **feature** track.

## Manifest contract

1. Resolve config + manifest (read `.feature-flow.json` →
   `${CLAUDE_PLUGIN_ROOT}/config/defaults.json`; locate the run's `manifest.json`).
2. Set `phases.implement.status = "in_progress"` only **after** the gate passes.

## Gate (AC4) — STOP if not signed off

On the **feature** track (and any escalated `tier: full` run), read `signOff` from the
manifest and the `User signed off:` line in `spec.md`. **If sign-off is `no` / `signed:
false`, STOP immediately.** Do not write any code. Tell the user:

> Implementation is gated on sign-off. Run `/ff-clarify` and sign off on the spec, then
> re-run `/ff-implement`.

Only proceed when sign-off is recorded.

## Cold-start

If there is no `plan.md` (or no `spec.md`), route the user to the prior phase
(`/ff-plan` → `/ff-design` → `/ff-clarify`) rather than implementing against nothing.

## Do the work

Read `plan.md`, `spec.md`, and `design.md`. Implement the plan task by task. Honor config
toggles:
- `toggles.tdd` (default true): write the test before the implementation for each unit
  with a clear contract; watch it fail, then make it pass.
- `toggles.worktree` (default false): if true, do the work in an isolated git worktree.
- `toggles.greenfield`: relaxes existing-codebase / `git diff` assumptions.

## Update manifest

Set `phases.implement = { status: "complete", artifact: null }` (code lives in the repo,
not the sandbox), bump `updatedAt`, `currentPhase = "implement"`. Next: `/ff-review`,
then `/ff-verify`.
