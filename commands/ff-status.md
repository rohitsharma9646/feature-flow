---
description: "Print the current feature-flow run: track, tier, phase, per-phase status, artifacts, sign-off."
argument-hint: "[slug, if more than one run exists]"
---

# /feature-flow:ff-status — run status

## Do the work

1. Resolve `paths.base` from config (`.feature-flow.json` →
   `${CLAUDE_PLUGIN_ROOT}/config/defaults.json`, default `.feature-flow`).
2. Find the run per **Run resolution** in `${CLAUDE_PLUGIN_ROOT}/docs/manifest-schema.md`:
   if `$ARGUMENTS` names a slug, use `<base>/<slug>/`; otherwise use the most recently
   updated **eligible** run (abandoned/closed runs are excluded — ask if ambiguous, listing
   `slug | track | currentPhase | updatedAt` per candidate).
3. **Abandoned run:** if `currentPhase` is `"abandoned"`, report — "Run '<slug>' is
   abandoned." — plus its per-phase status, and point at `/feature-flow:ff-list`.
4. Read `manifest.json`. Print a concise status:
   - **slug**, **track**, **tier**
   - **mode**: `autopilot` (`true` → autopilot, `false`/absent → step-by-step)
   - **currentPhase** (and `closedAt` if set)
   - **per-phase status** (pending / in_progress / complete) with each phase's artifact path
   - **sign-off** state (`required`, `signed`, `date`)
   - which artifacts exist on disk under the run dir
   - the one-line progress strip — see **Progress strip** in
     `${CLAUDE_PLUGIN_ROOT}/docs/manifest-schema.md`.
5. **Missing or corrupt manifest:** do NOT just defer to resume. Apply the **Disk inference
   procedure** in `${CLAUDE_PLUGIN_ROOT}/docs/manifest-schema.md` yourself (walk the track's
   phase order; artifact existence + minimal validity) and print the inferred status with
   every inferred line labeled **`[inferred from disk]`**. Then suggest
   `/feature-flow:ff-resume` to re-enter the first incomplete phase.

Do not modify anything — status is read-only.
