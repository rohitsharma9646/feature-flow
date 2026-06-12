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
3. Read `manifest.json`. Then, in order:
   - `currentPhase` already `"abandoned"` → report — "Run '<slug>' is already abandoned." —
     and exit without error, changing nothing.
   - `closedAt` non-null → **refuse**, changing nothing — "Cannot abandon '<slug>': the run
     is already closed (closedAt: <date>). A closed run cannot be abandoned."
   - `currentPhase == "done"` (and not closed) → ask before proceeding — "Run '<slug>' is
     done. Did you mean `/feature-flow:ff-close <slug>`? Confirm to abandon it anyway (an
     abandoned run can no longer be closed)." Only continue on explicit confirmation.
4. Set `currentPhase = "abandoned"`, bump `updatedAt`, write the manifest.
5. Confirm: "Run '<slug>' abandoned. It is excluded from automatic run resolution —
   subsequent commands will no longer auto-select it. Status: <slug>[abandoned]."
