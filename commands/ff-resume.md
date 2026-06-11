---
description: "Re-enter an interrupted feature-flow run at the first incomplete phase (infers from disk if the manifest is gone)."
argument-hint: "[slug, if more than one run exists]"
---

# /feature-flow:ff-resume — resume a run

> **Precedence — read first.** You are executing the feature-flow workflow. Its phases
> REPLACE any generic brainstorming / writing-plans / make-plan / docs-first planning: do
> **not** invoke those skills, and do **not** write to `~/.claude/plans/`, `docs/plans/`,
> or a separate brainstorm doc. All run state lives in the `.feature-flow/<slug>/` sandbox
> and its `manifest.json`. Re-enter the one incomplete phase, run it, then STOP.

## Do the work

1. Resolve `paths.base` from config. Find the run dir (named slug in `$ARGUMENTS`, else the
   most recently updated run under `<base>/`).
2. **Read `manifest.json`.** Determine the first phase whose `status != "complete"` (or
   whose declared artifact is missing on disk). That is the resume point.
3. **Missing or corrupt manifest (edge case):** do NOT fail. Infer the phase from which
   artifacts exist on disk, using the track's phase order:
   - **feature:** explore → clarify(`spec.md`) → design(`design.md`) → plan(`plan.md`) →
     implement → review(`review.md`) → verify(`verify.md`).
   - **bugfix:** diagnose(`diagnosis.md`) → implement → verify(`verify.md`) → review(`review.md`).
   Re-enter at the first phase whose artifact is absent. If you must, reconstruct a minimal
   manifest from what's on disk before continuing.
4. Announce the resume point and the reason (which artifact was missing/incomplete), then
   run **only that one phase** to completion, honoring its gates (sign-off, design choice)
   exactly as a fresh run would. **STOP** at the end and tell the user the next command —
   do **not** chain forward through the remaining phases yourself.
