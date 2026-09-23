---
tags: [retrospective, forward-testing, self-run, post-terminal-phase, evals]
referencedFiles:
  - commands/ff-retro.md
  - templates/retro.md
  - docs/manifest-schema.md
  - schemas/manifest-v1.schema.json
  - scripts/forward-test.sh
  - evals/forward/README.md
  - scripts/checks/retro-guard.sh
  - scripts/checks/forward-test-guard.sh
---

# Decision: ff-retro clones ff-deliver; forward-testing is a bash, fresh-process sibling of the eval harness

**Spec:** `docs/feature-flow/2026-09-23-retro-forward-testing/spec.md`
**Created:** 2026-09-23

## Decision

`ff-retro` is an optional post-terminal phase built as a structural clone of `ff-deliver`
(`phases.retro`/`artifacts.retro`, `currentPhase` stays `done`, never autopilot-chained) with the KB
capture confirm-gate shape; forward-testing is a repo-internal bash runner (`scripts/forward-test.sh`)
that runs committed fired/control sandboxes under `evals/forward/<behavior>/` in fresh
`claude -p --plugin-dir` processes, with assertions keyed on each behavior's own STOP/fire marker.

## Context

feature-flow had no loop from its own safeguard failures to fixes, and its 7 behavioral catches
were only structurally guarded — firing was proven by ad hoc, uncommitted manual self-runs. The
spec (signed 2026-09-23) fixed the WHAT: optional confirm-gated `ff-retro`, scripted local runner,
all 7 behaviors, repo-internal audience. This decision fixes the HOW.

## Options considered

| Option | Why considered / rejected |
|--------|----------------------------|
| Pragmatic (bash runner, sandboxes seeded from existing self-runs, marker-keyed assertions) | chosen — see Chosen + rationale below |
| Minimal (bash runner, hand-authored static sandboxes) | re-authors sandboxes that already work; transcript-only assertion for assumption-gap; misses the hook false-PASS hazard |
| Clean (Go runner + JSON-schema'd cases + JSONL records) | extensible and typed, but a Go binary + schema + tests for a local-only tool with 14 fixed cases; off-convention for `scripts/` |

## Trade-offs

| Option | Effort | Risk | Reversibility |
|--------|--------|------|----------------|
| Pragmatic | med | med | easy to undo |
| Minimal | high | low | easy to undo |
| Clean | high | med | hard to undo |

## Chosen + rationale

Pragmatic: it mirrors three shipped precedents (`ff-deliver` → `ff-retro`, `delivery-guard.sh` →
`retro-guard.sh`, `scripts/eval.sh` + `evals/fixtures/` → `scripts/forward-test.sh` +
`evals/forward/`), reuses sandboxes that have already fired in past self-runs, and is the only
option that addresses the wrong-reason-STOP hazard named as the design's **FS1** (see design.md
§Devil's advocate; FS2 budget sizing and FS3 headless confirm-gate skip are also carried there).
Output goes to the already-gitignored `.feature-flow/forward-test-runs/` (from Minimal).

Re-litigation bar: move to the Clean (typed Go) runner only if the forward-test case count grows
well beyond the 7 known gaps or case-definition errors recur; move `ff-retro` into the
done-transition only if optional retros demonstrably go unused.

**Related ACs:** AC1–AC20
**Related files:** commands/ff-retro.md, templates/retro.md, docs/manifest-schema.md,
schemas/manifest-v1.schema.json, scripts/forward-test.sh, evals/forward/README.md,
scripts/checks/retro-guard.sh, scripts/checks/forward-test-guard.sh

> If a do-not-contradict STOP against this decision is overridden, append the user's own words
> here verbatim: `Decision override by user (<date>): <reason>` — never self-authored.

## Outcome

Pending implementation.

## Future considerations

- WS-7's requirement-graph half (ff-plan) is not forward-tested; add an 8th behavior if it regresses.
- Forward tests are not in CI (cost, secrets, non-determinism); revisit if a cheap, stable
  model-in-CI path appears.
- `ff-retro` never scaffolds forward-test cases; revisit if retro→case conversion becomes routine.
