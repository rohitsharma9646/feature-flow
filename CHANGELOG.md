# Changelog

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
