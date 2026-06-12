# Changelog

## [0.3.0] — 2026-06-12

Autopilot mode. No breaking changes; pre-v0.3.0 manifests (no `autopilot` field) behave as
step-by-step everywhere — no migration, no mid-run ask.

### Added
- **Autopilot mode**: per-run `manifest.autopilot` boolean — when `true`, ceremonial
  phase-end STOPs become continuations (the assistant chains into the next phase in the
  same turn), pausing only at human gates: spec/diagnosis sign-off, the design option
  choice, an unreproduced bug, and an unresolved Critical review block. Step-by-step
  behavior is unchanged.
- Config `toggles.autopilot` (`"ask"` | `true` | `false`, default `"ask"`): `"ask"` asks
  once at run start (every manifest-creating entry point); the answer is recorded per-run
  and never re-asked.
- Canonical sections in `docs/manifest-schema.md`: **Autopilot** (chaining rule,
  mandatory-pause table, fix-cycle bound, run-start procedure, resume semantics) and
  **Sign-off rendering** (verbatim rule + grouped-checklist format).
- Autopilot Critical-review handling: exactly one fix-and-re-review cycle, recorded in
  `review.md`'s `## Resolution` section (the durable cycle record); then stop if Criticals
  remain.
- Progress strip renders auto-completed phases as `<phase>[auto]`; the strip is emitted
  after each chained phase.

### Changed
- Sign-off asks (`ff-clarify`, full-tier `ff-diagnose`) now render the contract as a
  **grouped checklist** (theme headings, `**AC<n> — <label>**` items, text verbatim) —
  never a blockquote wall.
- A user sign-off on an autopilot run continues the chain in the same turn (the commands
  re-read `manifest.autopilot` from disk when the confirmation arrives).
- `ff-resume` on an autopilot run continues the chain from the resume point to the next
  mandatory pause; step-by-step resume is unchanged (one phase, then stop).
- All 8 phase commands + `ff`, `ff-resume`, and SKILL.md doctrine are mode-conditional;
  the unconditional gate lines (never auto-sign, never pass a sign-off/not-reproduced/
  exhausted-Critical gate) are explicit in both modes.

## [0.2.0] — 2026-06-12

Pre-promotion hardening round. No breaking changes; v0.1.0 run manifests need no migration.

### Added
- `/feature-flow:ff-list` — list all runs (slug, track, tier, phase, dates), including
  abandoned/closed ones.
- `/feature-flow:ff-abandon <slug>` — mark a run abandoned; abandoned runs are excluded from
  automatic run resolution.
- `/feature-flow:ff-close <slug>` — close a completed (`done`) run; closed runs are excluded
  from automatic run resolution.
- `templates/explore.md` — structure contract for the explore artifact.
- `templates/plan-bugfix.md` — bugfix-track plan template (diagnosis gate, test-first Task 1).
- Manifest fields: `closedAt`; `currentPhase` value `abandoned`.
- Canonical sections in `docs/manifest-schema.md`: Disk inference procedure, Re-run guard,
  Progress strip.
- Config: `diagnosticianAgents` (default 1).
- Sign-off asks now quote the contract inline: `ff-clarify` quotes the spec's acceptance
  criteria verbatim; `ff-diagnose` (full tier) quotes the fix approach + contract items.

### Changed
- `models.*` config is now honored: every agent-dispatching command passes `models.<role>` as
  the dispatched agent's model.
- Run resolution excludes abandoned/closed runs; ambiguity prompts list
  `slug | track | currentPhase | updatedAt` per candidate.
- `ff-resume` validates manifest claims against disk (artifact existence + minimal validity)
  instead of trusting `status: complete`.
- `ff-status` performs its own disk inference on a missing/corrupt manifest, labeled
  `[inferred from disk]`.
- Every phase command: re-run guard on already-complete phases; progress strip in every
  STOP/hand-off message.
- `ff-review` (feature track) now blocks on Critical findings instead of routing to verify;
  bugfix branch routes to `ff-verify` when verify hasn't run yet.
- `ff-implement` gates on `design.md` (feature cold-start) and states that `toggles.tdd`
  never applies to the bugfix track.
- `ff-design` / `ff-plan` / `ff-diagnose` gained prescribed quoted gate-failure messages.
- `ff-verify` cold-start routes to `ff-clarify`/`ff-diagnose` instead of asking an open question.
- `ff.md` delegates the explore procedure to `ff-explore.md` (duplication eliminated).
- `ff-clarify` fill-list now includes the spec's Constraints section.
- README rewritten: worked example, configuration reference, command table, teammate vs
  author install, troubleshooting.

### Fixed
- `plugin.json`: added `repository`; `marketplace.json`: real plugin description.

## [0.1.0] — 2026-06-11

Initial release: feature track (explore → clarify → design → plan → implement → review →
verify) and test-first bugfix track (diagnose → implement RED→GREEN → verify → review),
durable `.feature-flow/<slug>/` run state, soft gates, read-only analysis agents, executed
verification via `ff-test-runner`.
