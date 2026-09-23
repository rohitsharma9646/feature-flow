---
description: "[shared] Optional, post-done retrospective: classify what the workflow's own safeguards did on a finished run, route each lesson to an owner, and write retro.md only after the user confirms."
argument-hint: "<slug> [notes on friction that left no trace on disk]"
---

# /feature-flow:ff-retro — retrospective phase (optional, post-`done`, confirm-gated)

Records **what feature-flow's own safeguards did** on a **finished** run — which gates, STOPs, cycles
and waivers fired, whether each worked, and which single owner should hold the fix for anything that
didn't. It is invoked explicitly, leaves `currentPhase` untouched, and writes **nothing** until the
user has accepted, edited, or rejected every candidate. The canonical contract is
`${CLAUDE_PLUGIN_ROOT}/docs/manifest-schema.md` §Retrospective — follow it; do not restate it here.

> **Precedence — read first.** You are executing the feature-flow workflow. Its phases REPLACE any
> generic brainstorming / writing-plans / make-plan / docs-first planning: do **not** invoke those
> skills, and do **not** write to `~/.claude/plans/`, `docs/plans/`, or a separate brainstorm doc.
> All run state lives in the `.feature-flow/<slug>/` sandbox and its `manifest.json`. Follow this
> command's steps literally, create files with the Write tool, run only this one phase, then STOP.
> **Autopilot never chains into the retrospective** (§Autopilot, "Retro is never chained") — it is
> always invoked by hand, and its confirm gate is only ever answered by the user.

## Manifest contract

1. **Resolve the run** per **Run resolution** in `${CLAUDE_PLUGIN_ROOT}/docs/manifest-schema.md`
   (named slug → else the single / most-recently-updated run → ask if ambiguous), then read its
   `manifest.json`. A **closed** run is allowed — leave `closedAt` untouched.
2. **Done gate — STOP if the run is not finished.** If `currentPhase != "done"` (still in progress,
   or `abandoned`), **STOP** and tell the user: "`ff-retro` runs on a finished run — '<slug>' is at
   `<currentPhase>`." Write **no** file and make **no** manifest change.
3. **No tier gate.** Unlike delivery, the retrospective runs on **lite and full, feature and bugfix**.
4. **Re-run guard:** if `phases.retro.status` is already `"complete"` (or `artifacts.retro` points at
   an existing file), stop and ask for explicit confirmation before overwriting — see **Re-run guard**
   in `${CLAUDE_PLUGIN_ROOT}/docs/manifest-schema.md`.

Do **not** change the manifest yet — the first manifest write happens only after the confirm gate
(below), so an unanswered gate leaves the run exactly as it was.

## Cold-start — resolve every source through the manifest pointer

Resolve each upstream artifact **only** via `manifest.artifacts.<name>` (the sole locating authority —
never a bare filename): `artifacts.spec` (or `artifacts.diagnosis` on bugfix), `artifacts.design`,
`artifacts.decision`, `artifacts.plan`, `artifacts.review`, `artifacts.verify`, `artifacts.delivery`.
**Each is optional** — a lite or bugfix run lacks some; report an unresolved one as "not available",
never invent its content.

## Do the work

1. **Scan for signals.** Read the resolved artifacts for the **closed signal list** in §Retrospective
   (user override/waiver lines, review `## Resolution`, verify `## Repair`, contract items below
   `Verified (single-source)`, Critical review findings, `⚠ DELIVERY GAP:` lines) and take the user's
   notes from `$ARGUMENTS` (text after the slug). Only these — no transcript, no guessing.
2. **Apply the materiality test** (§Retrospective) to each signal and note. Drop what it excludes.
3. **Distill candidates** — one per material event, each carrying all **nine fields** from
   §Retrospective's candidate schema, with the closed enums for *Safeguard result*, *Generalizability*
   and *Recommended owner*, and **no numeric score**. *Observed evidence* is an artifact path or a
   quoted line. A candidate whose owner is `regression/forward test` writes *Proposed validation* as
   **Fired input / Expected outcome / Control input** (the `evals/forward/README.md` case shape).

## Confirm gate (cross-turn, mandatory in both modes)

Present the candidates — numbered, all nine fields each — and ask the user to **accept, edit, or
reject each one**. With zero candidates, say **"no material events"** and ask the user to confirm
recording that. Then **STOP and end your turn.** **Nothing is written until the user confirms** —
neither the retrospective report nor the manifest. Never answer this gate yourself (autopilot, a headless session, or
a "sounds reasonable" default all count as answering it). This is the KB capture confirm-gate shape —
see §Retrospective → Confirm gate.

## Write the artifact + update manifest (after the user's answer)

On the user's reply (this or a later turn):

1. Resolve the report's path per **Durable artifact resolution** in
   `${CLAUDE_PLUGIN_ROOT}/docs/manifest-schema.md` (`retro` is durable-eligible: `paths.durable` →
   `<paths.durable>/<D>-<slug>/retro.md`, else sandbox `<run dir>/retro.md`; **create the target
   directory if absent**).
2. **Use the Write tool** to write `retro.md` from `${CLAUDE_PLUGIN_ROOT}/templates/retro.md`:
   only the **accepted** findings (with the user's edits), the **rejected count**, and any notes that
   did not become findings. **Zero candidates proposed** → the Findings section is exactly
   `_No material events._`; candidates proposed but **all rejected** → it is exactly
   `_No accepted findings — see Rejected._` (never "no material events" when events were found).
3. Record the path in **both** `artifacts.retro` and `phases.retro.artifact`; set
   `phases.retro = { status: "complete", artifact: "<resolved retro path>" }`, bump `updatedAt`.
   **Leave `currentPhase = "done"` unchanged** and `closedAt` untouched.

**Write nothing else.** No KB entry (capture already ran at the done-transition), no edit to code,
instructions, skills, guards or tests, no forward-test case, no `git add`/`commit`. Improvements the
retro recommends are separate, user-initiated work.

Report the written path and a one-line summary per accepted finding (safeguard result → owner), then
**STOP**. End with the one-line progress strip — see **Progress strip** in
`${CLAUDE_PLUGIN_ROOT}/docs/manifest-schema.md` — marking the run `done` with the retrospective complete.
