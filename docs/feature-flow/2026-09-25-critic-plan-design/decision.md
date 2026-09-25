---
tags: [critic, design-phase, plan-phase, agents, review-cycle]
referencedFiles:
  - agents/ff-critic.md
  - docs/schema/critic.md
  - commands/ff-design.md
  - commands/ff-plan.md
  - docs/schema/autopilot.md
---

# Decision: an independent ff-critic reviews the written design and plan, screened, revised once

**Spec:** `docs/feature-flow/2026-09-25-critic-plan-design/spec.md`
**Created:** 2026-09-25

## Decision

Inside `ff-design` and `ff-plan`, one `ff-critic` leaf (`models.critic`) critiques the phase's
**written** artifact against the signed contract. The orchestrator screens its findings.

- A surviving Critical gets one revise-and-re-check cycle, recorded as `## Resolution` +
  `## Re-check` in the Critic's report.
- A Critical still open after that is the Critic stop.
- The phase completes only once the Critic clears.
- The procedure lives once, in `docs/schema/critic.md` §Critic.

## Context

The user wants no weak architecture or plan to reach implement. Today's only design and plan
critiques are the orchestrator's self-checks. The plan has none at all. The user's
`critical-plan-review` skill has the right process but the wrong output shape for a gate, and it
does not ship with the plugin.

## Options considered

| Option | Why considered / rejected |
|--------|----------------------------|
| Post-write critic, per-phase report | chosen — see Chosen + rationale below |
| In-session draft critic | no stable `file:line` to cite; the revise cycle works on a copy inlined in the prompt |
| One shared `critic.md` | the plan phase overwrites the design phase's critique |

## Trade-offs

| Option | Effort | Risk | Reversibility |
|--------|--------|------|----------------|
| Post-write critic, per-phase report | med | med | easy to undo |
| In-session draft critic | med | med | easy to undo |
| One shared `critic.md` | med | high | easy to undo |

## Chosen + rationale

The post-write critic mirrors how `ff-review` critiques a real diff:
- Findings cite real lines.
- The revise edits the file in place.
- `decision.md` is derived once, after the design can no longer change.

The one-cycle cap and its on-disk record reuse `ff-review`'s `## Resolution` shape. The Resolution is
written **before** the re-check, which is dispatched with no report path and appended, so a session
drop cannot reset the cap. The screen reuses `ff-design`'s `Dropped (contradicts the spec):` line.
The failure scenarios this choice must survive are named in `design.md §Devil's advocate`
(FS1–FS3).

**Related ACs:** AC1–AC10
**Related files:** agents/ff-critic.md, docs/schema/critic.md, commands/ff-design.md, commands/ff-plan.md, docs/schema/autopilot.md

## Outcome

Pending implementation.

## Future considerations

- A Critic for lite runs, or for clarify's spec, is deferred (spec non-goals).
- Revisit the Opus default if SM1/SM2 show the budget cannot hold.
- Revisit the one-cycle cap if Critic stops prove frequent in real runs.
