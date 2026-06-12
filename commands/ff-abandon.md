---
description: "Abandon a run: set currentPhase to \"abandoned\" so it is excluded from automatic run resolution. Non-destructive."
argument-hint: "<slug — from /feature-flow:ff-list>"
---

# /feature-flow:ff-abandon — abandon a run

> **Precedence — read first.** You are executing the feature-flow workflow. All run state
> lives in the `.feature-flow/<slug>/` sandbox and its `manifest.json`. Follow these steps
> literally, modify only the named run's manifest, then STOP.

Abandoning is **non-destructive**: it only sets manifest state. No directory, artifact, or
phase record is deleted or moved. The run stays visible in `/feature-flow:ff-list` and
reachable by explicit slug.

## Do the work

1. `$ARGUMENTS` must name a slug. If it doesn't: STOP with — "Specify which run to abandon.
   Run `/feature-flow:ff-list` to see all runs."
2. Resolve `paths.base` from config and locate `<base>/<slug>/`. If it does not exist: STOP
   with — "No run '<slug>' found. Run `/feature-flow:ff-list` to see all runs."
3. Read `manifest.json`. If `currentPhase` is already `"abandoned"`: report — "Run '<slug>'
   is already abandoned." — and exit without error, changing nothing.
4. Set `currentPhase = "abandoned"`, bump `updatedAt`, write the manifest.
5. Confirm: "Run '<slug>' abandoned. It is now excluded from automatic run resolution; a new
   `/feature-flow:ff` run will no longer be captured by it. Status: <slug>[abandoned]."
