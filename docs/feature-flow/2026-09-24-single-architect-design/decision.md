---
tags: [design, architect, subagents, cost, ff-design]
referencedFiles:
  - commands/ff-design.md
  - agents/ff-code-architect.md
  - templates/design.md
  - docs/schema/design-tradeoffs.md
  - config/defaults.json
---

# Decision: ff-design dispatches one architect whose report is saved as an ephemeral architect.md

**Spec:** `docs/feature-flow/2026-09-24-single-architect-design/spec.md`
**Created:** 2026-09-24

## Decision

`ff-design` dispatches exactly one `ff-code-architect`, which develops only the best approach in full
and lists 1–3 rejected approaches with scores (or `one obvious approach —`) using fixed report
markers; the report is saved to `<run dir>/architect.md` (`artifacts.architect`, ephemeral) before the
user chooses; a picked alternative is developed by one re-dispatch; `architectAgents` is removed.

## Context

The three-way fan-out produced three full designs to use one (pragmatic won 4/4 recent runs); the user
called it time waste and chose the cheapest variant — best approach only.

## Options considered

| Option | Why considered / rejected |
|--------|----------------------------|
| Single dispatch + `architect.md` side artifact | chosen — see Chosen + rationale below |
| New `architect` phase | widens the phase enum and everything keyed on `currentPhase` |
| Always re-dispatch on re-entry | fails AC4; loses work and doubles cost on a dropped session |
| Keep `architectAgents` = 1 | contradicts the user's removal; dead config |

## Trade-offs

| Option | Effort | Risk | Reversibility |
|--------|--------|------|----------------|
| Single dispatch + `architect.md` side artifact | med | low | easy to undo (prose + one config key) |
| New `architect` phase | high | high | hard to undo (phase enum) |
| Always re-dispatch on re-entry | low | high | easy to undo |
| Keep `architectAgents` = 1 | low | med | easy to undo |

## Chosen + rationale

The side-artifact shape mirrors `decision.md` (a second artifact of the design phase located only via
`artifacts.<name>`), so no phase, autopilot row or schema widens — the settled "derive/point, don't
widen" convention. Fixed markers make the report assertable (the settled forward-test marker
convention). Failure scenarios to survive: `design.md` §Devil's advocate (FS1–FS3).

Reopen if designs regress in review (a sign the fan-out's alternatives mattered), or if the forward
test shows the single architect padding its report.

**Related ACs:** AC1–AC8
**Related files:** commands/ff-design.md, agents/ff-code-architect.md, templates/design.md, docs/schema/design-tradeoffs.md, config/defaults.json

## Outcome

Pending implementation.

## Future considerations

- A "best + alternatives developed" mode if quality regresses.
- The same single-agent treatment for `explorerAgents` / `reviewerAgents` fan-outs, measured first.
