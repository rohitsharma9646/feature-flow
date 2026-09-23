---
description: "[shared] Optional, terminal, non-gated delivery phase: assemble delivery.md (release notes / deploy / rollback / migration / known issues) from the run's upstream artifacts. Never blocks done."
argument-hint: "<run after the run is done (feature: after verify; bugfix: after verify+review)>"
---

# /feature-flow:ff-deliver — delivery phase (optional, post-`done`, non-gated)

Assembles `delivery.md` for a **finished** run by **consuming** its upstream artifacts — release
notes, deployment/rollback/migration checklists, known issues, release validation. This phase is a
**value-add**: it is invoked explicitly, it **never blocks `done`**, and it leaves `currentPhase`
untouched. The canonical contract is `${CLAUDE_PLUGIN_ROOT}/docs/manifest-schema.md` §Delivery —
follow it; do not restate it here.

> **Precedence — read first.** You are executing the feature-flow workflow. Its phases REPLACE any
> generic brainstorming / writing-plans / make-plan / docs-first planning: do **not** invoke those
> skills, and do **not** write to `~/.claude/plans/`, `docs/plans/`, or a separate brainstorm doc.
> All run state lives in the `.feature-flow/<slug>/` sandbox and its `manifest.json`. Follow this
> command's steps literally, create files with the Write tool, run only this one phase, then STOP.
> **Autopilot never chains into delivery** (§Autopilot, "Delivery is never chained") — it is always
> invoked by hand.

## Manifest contract

1. **Resolve the run** per **Run resolution** in `${CLAUDE_PLUGIN_ROOT}/docs/manifest-schema.md`
   (named slug → else the single / most-recently-updated run → ask if ambiguous), then read its
   `manifest.json`.
2. **Done gate — STOP if the run is not finished.** Delivery consumes a completed run's artifacts,
   so if `currentPhase != "done"`, **STOP** and tell the user delivery runs after the run is done
   (feature: after `/feature-flow:ff-verify`; bugfix: after verify + review). Do not deliver a
   half-finished run. **This is the only gate — and it never denies `done`; the run is already there.**
3. **Tier gate.** If `tier == "lite"`, delivery is **off by default** — **STOP** and say so, unless
   the user's invocation explicitly asked for delivery on this lite run. Full tier proceeds.
4. **Re-run guard:** if `phases.deliver.status` is already `"complete"` (or `artifacts.delivery`
   points at an existing file), stop and ask for explicit confirmation before overwriting the
   existing report — see **Re-run guard** in `${CLAUDE_PLUGIN_ROOT}/docs/manifest-schema.md`.
5. Set `phases.deliver.status = "in_progress"`. **Do NOT change `currentPhase`** — it stays `"done"`.

## Cold-start — resolve every source through the manifest pointer

Resolve each upstream artifact **only** via `manifest.artifacts.<name>` (the sole locating authority
— never a bare filename; a promoted artifact lives outside the sandbox):

- `artifacts.spec` — acceptance criteria for the release notes.
- `artifacts.decision` — the chosen approach/rationale for the release-note "why" (if present).
- `artifacts.plan` — `§Rollback plan` + `§Risk register` for the rollback checklist, migration notes,
  and the delivery-gap check.
- `artifacts.verify` — `§Limitations & remaining risks` (known issues) + `§Commands run` (release validation).

**A source that does not resolve is reported, not fatal.** A lite or older run whose `artifacts.plan`
resolves to nothing, or an empty `§Limitations`, yields "no plan — rollback not derivable" / "None
reported" in the corresponding section — never a crash, never invented content. Delivery degrades gracefully.

## Do the work

Assemble `delivery.md` from `${CLAUDE_PLUGIN_ROOT}/templates/delivery.md`, filling each section from
its consumption source per §Delivery (do not restate the source table here):

- **Release notes** ← spec ACs (`artifacts.spec`) + `artifacts.decision`.
- **Rollback checklist** ← `plan.md §Rollback plan` (`artifacts.plan`), row for row.
- **Migration notes** ← plan tasks flagged migration/schema/irreversible in `§Rollback plan` / `§Risk register`.
- **Known issues** ← `verify.md §Limitations & remaining risks` (`artifacts.verify`), mirrored.
- **Release validation steps** ← `verify.md §Commands run` (`artifacts.verify`), re-run post-deploy.
- **Deployment checklist** — a generic ordered scaffold seeded by detectable signals (migration tasks
  present? verify commands?); **not** an inferred infrastructure model.

### Delivery-gap cross-check (the actuation — do not skip)

Before writing, cross-check the plan against its own rollback coverage. For **every** plan task that
touches **migration / schema / irreversible I/O** (from `§Rollback plan` / `§Risk register` /
task file lists), verify it has a `§Rollback plan` recovery line. A qualifying task with **no**
recovery line is an upstream hole: write a `⚠ DELIVERY GAP: <task> touches <migration/schema> but
the plan's §Rollback plan has no recovery line` entry into the Rollback checklist section, and **report
every gap to the user** in the hand-off. This is **non-blocking** — delivery never blocks `done`; the
gap is back-pressure that makes the missing rollback visible. A task
carrying an `irreversible: mitigation is <X>` line is **not** a gap — surface its mitigation instead.

Resolve the report's path per **Durable artifact resolution** in
`${CLAUDE_PLUGIN_ROOT}/docs/manifest-schema.md` (`delivery` is durable-eligible: `paths.durable` →
`<paths.durable>/<D>-<slug>/delivery.md`, else sandbox `<run dir>/delivery.md`; **create the target
directory if absent**). **Use the Write tool** to write `delivery.md` at the resolved path.

## Update manifest + hand off

Record the resolved path in **both** `artifacts.delivery` and `phases.deliver.artifact`:
set `phases.deliver = { status: "complete", artifact: "<resolved delivery path>" }`, bump `updatedAt`.
**Leave `currentPhase = "done"` unchanged** — delivery is post-terminal; it never re-enters a phase,
never sets `done` (the run is already done), and never fires KB capture (that already happened at the
done-transition — see §Terminal convergence).

Report the delivery result — the written report path, a one-line summary of each section's source, and
**every `⚠ DELIVERY GAP` found** (non-blocking) — then **STOP** and end your turn. End the message
with the one-line progress strip — see **Progress strip** in
`${CLAUDE_PLUGIN_ROOT}/docs/manifest-schema.md` — marking the run `done` with delivery complete.
