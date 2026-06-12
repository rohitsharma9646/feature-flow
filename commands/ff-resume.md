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
2. **Abandoned-run guard:** if the manifest's `currentPhase` is `"abandoned"`, STOP and
   report — "Run '<slug>' is abandoned — nothing to resume. Use `/feature-flow:ff-list` to
   see active runs." Do not infer or re-enter phases.
3. **Read `manifest.json` and validate it against disk** — do not trust `status: "complete"`
   on its own. Apply the **Disk inference procedure** in
   `${CLAUDE_PLUGIN_ROOT}/docs/manifest-schema.md`: for each phase marked `complete`, its
   declared artifact must exist on disk AND pass minimal validity (`spec.md` contains a
   `User signed off:` line; `diagnosis.md` contains its `Tier:` line; others: existence).
   The first phase that is not complete, or whose artifact is missing/invalid, is the resume
   point — announce "manifest claims complete but artifact missing: `<path>`" or "artifact
   failed validity check: `<path>`" when that is why.
4. **Missing or corrupt manifest (edge case):** do NOT fail. Apply the same **Disk inference
   procedure** from scratch (walk the track's phase order; first absent-or-invalid artifact
   is the resume point) and reconstruct a minimal manifest from what's on disk before
   continuing.
5. Announce the resume point and the reason (which artifact was missing/incomplete), then
   run **only that one phase** to completion, honoring its gates (sign-off, design choice)
   exactly as a fresh run would. **STOP** at the end and tell the user the next command,
   ending the message with the one-line progress strip — see **Progress strip** in
   `${CLAUDE_PLUGIN_ROOT}/docs/manifest-schema.md`. Do **not** chain forward through the
   remaining phases yourself.
