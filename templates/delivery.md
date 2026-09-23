# Delivery: <feature title or bug>

**Track:** feature | bugfix
**Tier:** full
**Date:** <date>
**Run:** `<slug>` — assembled by `/feature-flow:ff-deliver` from this run's upstream artifacts.

> **Consumes, never restates.** Every section below is derived from an upstream artifact resolved
> via `manifest.artifacts.<name>`. A source that cannot be resolved is reported as such (e.g.
> "no plan.md — rollback not derivable"), never invented. Delivery is optional and **never blocks
> `done`** — see `${CLAUDE_PLUGIN_ROOT}/docs/manifest-schema.md` §Delivery.

## Release notes

<What shipped, in user-facing terms — one bullet per delivered capability.>

> Derived from the spec's acceptance criteria (`artifacts.spec`) + the decision record
> (`artifacts.decision`, if present). Each satisfied AC becomes a release-note bullet; the chosen
> approach/rationale from `decision.md` frames the "why".

## Deployment checklist

- [ ] <ordered step to ship this change>

> A generic ordered scaffold seeded by detectable signals (does the plan have migration tasks? what
> commands did verify run?). This is **not** an inferred infrastructure model — tune it to the
> project's real deploy process.

## Rollback checklist

- [ ] <how to undo each risky change, phase by phase>

> Built **row for row** from `plan.md §Rollback plan` (`artifacts.plan`). Any plan task touching
> migration / schema / irreversible I/O with **no** recovery line is flagged below as a
> `⚠ DELIVERY GAP` — a visible hole that back-pressures the plan to record the rollback. A task
> marked `irreversible: mitigation is <X>` carries its mitigation here, not a fake undo.

## Migration notes

<Schema/data migrations this release performs, their order, and how to reverse or mitigate each.>

> Derived from `plan.md` tasks flagged migration/schema/irreversible in `§Rollback plan` /
> `§Risk register`. "None" when the plan touches no migration/irreversible surface.

## Known issues

- <Anything a client should know before signing off — carried forward verbatim.>

> Mirrored from `verify.md §Limitations & remaining risks` (`artifacts.verify`). "None reported"
> when that section is empty — never invent issues.

## Release validation steps

- [ ] <command to re-run post-deploy to confirm the release is healthy>

> Derived from `verify.md §Commands run` (`artifacts.verify`) — the executed test/build/smoke
> commands, re-purposed as the post-deploy validation to confirm the change is live and healthy.
