# Delivery — feature-flow manifest contract
> Part of the manifest contract. Core rules and the topic index: `docs/manifest-schema.md`.

## Delivery

The **delivery** phase is **optional, post-terminal, and non-gated** (added v0.12.0). It runs
*after* a run reaches `currentPhase = "done"` and produces `delivery.md` by **consuming** the run's
upstream artifacts — it never denies, never blocks `done`, and is off for `tier: lite` unless the
user explicitly requests it. `ff-deliver` is the only command that touches it and it is **never
chained by autopilot** (see §Autopilot). This is the canonical contract; `ff-deliver` references it
by name and never restates it inline — same house style as **Planning intelligence** and **Knowledge
base** above.

### Manifest shape (absent-defaulted)

- `phases.deliver` (`{ status, artifact }`, following the generic phase shape
  `pending|in_progress|complete` defined once in §Schema) — the delivery phase's status.
  **Absent = the run predates delivery or never ran it** (every pre-v0.12.0 manifest, and any `done`
  run without delivery): `ff-status`/`ff-resume` treat it as an optional, not-yet-run phase, never
  missing-and-invalid. No migration.
- `artifacts.delivery` — the resolved path of `delivery.md`. **Absent = no delivery artifact
  recorded.** Promotion-eligible (durable set in §Field notes); with `paths.durable` null it stays
  in the sandbox.
- **`currentPhase` stays `"done"` and the `currentPhase` enum is NOT extended with `deliver`.** `done`
  is the immutable terminal state Gate B guards and run-resolution excludes; delivery is tracked
  **only** in `phases.deliver`. A command reading `currentPhase` never sees `deliver`, so Gate B, the
  sign-off gate, resume, and close are all untouched.

### Consumption sources (delivery restates nothing)

`ff-deliver` resolves each source **only** via `manifest.artifacts.<name>` (never a bare filename):

- **Release notes** ← the spec's acceptance criteria (`artifacts.spec`) + `artifacts.decision` (if present).
- **Rollback checklist** ← `plan.md §Rollback plan` (`artifacts.plan`), row for row.
- **Migration notes** ← `plan.md` tasks flagged migration/schema/irreversible in `§Rollback plan` / `§Risk register`.
- **Known issues** ← `verify.md §Limitations & remaining risks` (`artifacts.verify`), mirrored.
- **Release validation steps** ← `verify.md §Commands run` — the executed commands, to re-run post-deploy.
- **Deployment checklist** — a generic ordered scaffold seeded by detectable signals (migration tasks
  present? verify commands?); it is **not** an inferred infrastructure model.

A source that cannot be resolved (a lite/pre-WS-2 run with no `plan.md`, an empty `§Limitations`) is
**reported as what it is** — "no plan.md — rollback not derivable", "None reported" — never invented.

### Delivery gap (the actuation)

For every plan task touching **migration / schema / irreversible I/O** that has **no** `§Rollback
plan` recovery line, `ff-deliver` records a `⚠ DELIVERY GAP:` line in `delivery.md` and reports it to
the user — **non-blocking** (delivery never blocks `done`). This is the back-pressure that makes an
upstream missing rollback visible at ship time, closing WS-2's rollback loop. A task carrying an
`irreversible: mitigation is <X>` line is **not** a gap — it has a mitigation, which delivery surfaces
instead.

