---
description: "Close a completed run: record closedAt so it is excluded from automatic run resolution. Only done runs can close. Non-destructive."
argument-hint: "<slug — from /feature-flow:ff-list>"
allowed-tools: Read, Glob, Write
---

# /feature-flow:ff-close — close a completed run

> **Precedence — read first.** You are executing the feature-flow workflow. All run state
> lives in the `.feature-flow/<slug>/` sandbox and its `manifest.json`. Follow these steps
> literally, modify only the named run's manifest, then STOP.

Closing is **non-destructive**: it records `closedAt` in the manifest. Nothing is deleted,
moved, or archived; the run stays visible in `/feature-flow:ff-list` and reachable by
explicit slug.

## Do the work

> **Integrity boundary — before every terminal state write:** run the canonical Command-level
> preflight in `docs/manifest-schema.md`; follow its legacy/current mode rule and stop on an
> enforce-mode denial or invocation failure.

1. `$ARGUMENTS` must name a slug. If it doesn't: STOP with — "Specify which run to close.
   Run `/feature-flow:ff-list` to see all runs."
2. Resolve `paths.base` from config and locate `<base>/<slug>/`. If it does not exist: STOP
   with — "No run '<slug>' found. Run `/feature-flow:ff-list` to see all runs."
3. Read `manifest.json`. If `closedAt` is already set: report — "Run '<slug>' is already
   closed (closedAt: <date>)." — and exit without error, changing nothing.
4. **Gate: only done runs close.** If `currentPhase != "done"`: refuse, changing nothing —
   "Cannot close '<slug>': the run is not done (currentPhase: <phase>). Incomplete phases:
   <every phase whose status != "complete">. Finish the run (or `/feature-flow:ff-abandon
   <slug>` to drop it)."
5. Set `closedAt = <ISO8601 now>`, bump `updatedAt`, write the manifest.
6. Confirm: "Run '<slug>' closed. It is excluded from automatic run resolution. Status:
   <slug>[closed]."
