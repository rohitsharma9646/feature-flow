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

1. Resolve `paths.base` from config. Find the run dir per **Run resolution** in
   `${CLAUDE_PLUGIN_ROOT}/docs/manifest-schema.md` (named slug in `$ARGUMENTS`, else the most
   recently updated *eligible* run — abandoned/closed runs are excluded).
2. **Abandoned/closed-run guard:** if the manifest's `currentPhase` is `"abandoned"`, STOP
   and report — "Run '<slug>' is abandoned — nothing to resume. Use `/feature-flow:ff-list`
   to see active runs." If `closedAt` is non-null, STOP and report — "Run '<slug>' is closed
   (closedAt: <date>) — nothing to resume. Use `/feature-flow:ff-list` to see active runs."
   In both cases do not infer or re-enter phases (these guards apply even when the slug was
   named explicitly).
3. **Read `manifest.json` and validate it against disk** — do not trust `status: "complete"`
   on its own: each complete phase's artifact must exist and pass minimal validity, per the
   **Disk inference procedure** in `${CLAUDE_PLUGIN_ROOT}/docs/manifest-schema.md`. The first
   phase that is not complete, or whose artifact is missing/invalid, is the resume point —
   announce the procedure's prescribed reason ("manifest claims complete but artifact
   missing: `<path>`" / "artifact failed validity check: `<path>`") when that is why.
4. **Missing or corrupt manifest (edge case):** do NOT fail. Apply the same **Disk inference
   procedure** from scratch (walk the track's phase order; first absent-or-invalid artifact
   is the resume point) and reconstruct a minimal manifest from what's on disk before
   continuing.
5. Announce the resume point and the reason (which artifact was missing/incomplete), then
   run the resume-point phase to completion, honoring its gates (sign-off, design choice)
   exactly as a fresh run would. Then branch on mode: if `manifest.autopilot` is `true`,
   **continue the chain** from the resume point to the next mandatory pause — honoring
   every gate exactly as a live autopilot run would — see **Autopilot** in
   `${CLAUDE_PLUGIN_ROOT}/docs/manifest-schema.md`. If `false` or absent, run **only that
   one phase**: **STOP** at the end and tell the user the next command,
   ending the message with the one-line progress strip — see **Progress strip** in
   `${CLAUDE_PLUGIN_ROOT}/docs/manifest-schema.md`. Do **not** chain forward through the
   remaining phases yourself in step-by-step mode.
