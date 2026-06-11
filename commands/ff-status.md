---
description: "Print the current feature-flow run: track, tier, phase, per-phase status, artifacts, sign-off."
argument-hint: "[slug, if more than one run exists]"
---

# /feature-flow:ff-status — run status

## Do the work

1. Resolve `paths.base` from config (`.feature-flow.json` →
   `${CLAUDE_PLUGIN_ROOT}/config/defaults.json`, default `.feature-flow`).
2. Find the run: if `$ARGUMENTS` names a slug, use `<base>/<slug>/`; otherwise list the
   runs under `<base>/` and use the most recently updated (or ask if ambiguous).
3. Read `manifest.json`. Print a concise status:
   - **slug**, **track**, **tier**
   - **currentPhase**
   - **per-phase status** (pending / in_progress / complete) with each phase's artifact path
   - **sign-off** state (`required`, `signed`, `date`)
   - which artifacts exist on disk under the run dir

Do not modify anything — status is read-only. If the manifest is missing or corrupt, say
so and suggest `/feature-flow:ff-resume`, which can infer state from the artifacts present.
