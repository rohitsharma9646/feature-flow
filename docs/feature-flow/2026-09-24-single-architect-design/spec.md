# Spec: one architect in ff-design instead of a three-way fan-out

**Created:** 2026-09-24
**Track:** feature
**Status:** signed-off

## Problem

`ff-design` dispatches three `ff-code-architect` agents in parallel (minimal / clean / pragmatic),
each designing a full solution, then merges them. The user finds this "only time waste": three full
designs are produced to use one. Over the last four full-tier runs the pragmatic option won every
time. The fan-out multiplies the design phase's time and cost roughly threefold for a choice that is
usually predictable.

## Expected outcome

`ff-design` dispatches **one** architect. It develops the recommended design in full, lists the
genuinely different approaches it rejected (one line each on why they lost, with trade-off scores),
and its report is saved before the user chooses. The user still picks: the recommendation, or a
rejected approach, which the same architect then develops in full once. When only one approach is
sane, the ask is a confirmation. The trade-off matrix, the devil's-advocate pass, the failure
scenarios and the decision record work exactly as before. The `architectAgents` setting is gone.

## Solution approaches considered

- **Chosen — one architect, best approach only** (user choice, 2026-09-24): the recommended design in
  full plus a short rejected list; a rejected approach is developed only if the user picks it.
  Cheapest; grafting a loser's mechanism into the winner (seen in 3 of the last 4 runs) becomes the
  architect's own judgement rather than a by-product of three full designs.
- **Rejected — one architect, best + alternatives developed** (2–3 approaches weighed in depth with a
  graft step): keeps more of the fan-out's value, at more cost per run; the user preferred speed.
- **Rejected — keep the fan-out as an opt-in** (`architectAgents` default 1, 2–3 restores parallel
  architects): more to maintain and test; the user chose to remove the key.

## Assumptions (WHAT-changing)

| Statement | Confidence | Basis / evidence | If-wrong impact | Validation-required |
|---|---|---|---|---|
| A headless forward-test session running `ff-design` reaches and saves the architect's report before the choice pause, so the report can be asserted without a human answering | med | the pause is an AskUserQuestion that a headless `claude -p` session cannot answer; `architect.md` is written before it | The E2E asserts would need an answer-injection mechanism or would have to read the final message only | y |
| One architect producing the best design plus a short rejected list gives designs good enough that reviews and verify do not regress | med | pragmatic won 4/4 recent runs; the choice is still the user's | Design quality drops; the fan-out (or the "best + alternatives" variant) would need to come back — accepted by the user as the trade for speed | n |

## Constraints

- The trade-off matrix, devil's-advocate pass, `FS<n>` actuation and `decision.md` derivation keep
  their contracts; `design-tradeoff-guard.sh` and `decision-record-guard.sh` stay green unchanged.
- The design-choice pause stays an in-session pause in both modes (the `autopilot.md` row is
  unchanged); autopilot never picks for the user.
- `models.architect` stays the architect's model key.
- `docs/schema/knowledge-base.md`'s shared recall text (also used by explore and diagnose) stays
  generic.
- Codex parity: the procedure is prose; without multi-agent tooling the one architect's role runs inline.
- Release as **0.24.0**.

## Touchpoints

- `commands/ff-design.md` — single dispatch, `architect.md`, the choice pause, the re-dispatch.
- `agents/ff-code-architect.md` — the architect's contract (best design + rejected list).
- `templates/design.md`, `docs/schema/design-tradeoffs.md` — "every option the architect considered".
- `config/defaults.json`, `docs/manifest-schema.md` (Known keys; `architect` artifact as ephemeral),
  `README.md`, `skills/feature-flow/SKILL.md` — remove `architectAgents`; fan-out wording.
- `scripts/checks/` — a new structural guard; `evals/forward/` — a new forward test.
- Version files, CHANGELOG, `dist/codex`.

## Edge cases

- **One sane approach:** the architect says `one obvious approach — <why>`, invents no alternatives;
  the matrix has one row; the ask is confirm-only.
- **User picks a rejected approach:** the architect is re-dispatched once to develop it; its report is
  appended to `architect.md`; the matrix, devil's advocate and decision record use the picked design.
- **Session drops at the pause:** re-entering `ff-design` reads `architect.md` and asks again — no new
  dispatch.
- **`.feature-flow.json` still sets `architectAgents`:** the standard unknown-key warning; ignored.

## Non-goals

- Changing explore's or review's fan-outs (`explorerAgents`, `reviewerAgents`).
- Changing the trade-off matrix axes, the devil's-advocate rules, `FS<n>` handling or `decision.md`.
- Letting autopilot choose the design.
- Measuring design *quality* (only cost and structure are measured).

## Acceptance criteria

- [ ] AC1: `ff-design` dispatches exactly one `ff-code-architect` per design (model `models.architect`),
  given the spec and explore findings; there is no parallel fan-out and no agent-count setting is read.
- [ ] AC2: The architect returns the recommended design in full (as today: component map, data flow,
  build sequence, risks) plus a rejected list of 1–3 genuinely different approaches, each with one
  line on why it lost and `low | med | high` scores on complexity, risk and test effort — or
  `one obvious approach — <why>` with no invented alternatives.
- [ ] AC3: `agents/ff-code-architect.md` states that contract: weigh the smallest change, the
  cleanest structure and the codebase's own conventions as lenses, develop only the best in full,
  report the rest briefly; no sibling-architect wording remains.
- [ ] AC4: `ff-design` writes the architect's report to `<run dir>/architect.md` (ephemeral, located via
  `manifest.artifacts.architect`) **before** the choice pause, and a re-entered design phase with that
  file present asks again without re-dispatching.
- [ ] AC5: The choice pause asks with the recommended design first and each rejected approach as an
  option (confirm-only when there is one obvious approach); picking a rejected approach re-dispatches
  the architect once to develop it in full, appended to `architect.md`. The pause is in-session in both
  modes.
- [ ] AC6: `design.md`'s trade-off matrix scores every approach the architect considered (chosen +
  rejected) — wording updated in `templates/design.md` and `docs/schema/design-tradeoffs.md` — and the
  devil's-advocate pass, `FS<n>` items and `decision.md` derivation are unchanged.
- [ ] AC7: `architectAgents` is removed from `config/defaults.json`, the Known-keys line and the README
  config table; every "architects fan out" description (ff-design frontmatter and KB-recall wording,
  `templates/design.md`, `docs/schema/design-tradeoffs.md`, README, SKILL) is updated.
- [ ] AC8: A new structural guard pins AC1–AC7's wiring; every existing guard and `scripts/eval.sh`
  exit 0 (the Go-only guard excepted where Go is absent); version 0.24.0 across the synced files;
  `dist/codex` repackaged.

## End-to-end check

- [ ] E2E: `scripts/forward-test.sh single-architect` — fired arm (a signed full-tier spec with several
  viable approaches) → `architect.md` holds one recommended design and ≥ 1 rejected approach, each with
  a reason and the three scores; control arm (a spec with one obvious approach) → `architect.md` says
  `one obvious approach` and lists no rejected approaches.

## Success metrics

- [ ] SM1: The fired arm's mean session cost is ≤ 90% of the same arm run against v0.23.0 (measured by
  sm1-ratio.sh); wall time is recorded, not gated.

  *Amended 2026-09-25 by the user (re-signed below).* The original SM1 — "≤ 60% of the same arm run
  against the v0.23.0 plugin, by `total_cost_usd`" — rested on the fan-out tripling the phase's cost;
  three verify passes measured the main session at ~80% of it, so no architect change could reach
  0.60. Measured: cost 0.72×, wall time ~1.4× (the three architects ran in parallel).

## Requirement graph

| AC | Depends on |
|----|------------|
| AC3 | AC2 |
| AC4 | AC1 |
| AC5 | AC4 |
| AC8 | AC7 |

## Sign-off

**User signed off:** yes (2026-09-24)

Assumption 1 acknowledged by user as staying open (2026-09-24) — carried to the plan as a `**Validates:**` task.

SM1 amended and re-signed by user (2026-09-25): "Keep 1 architect, amend SM1" — the text above; the ~1.4× wall time recorded as a known limit.

> A spec without sign-off does not proceed to **design, planning, or implementation** —
> `/feature-flow:ff-design`, `/feature-flow:ff-plan`, and `/feature-flow:ff-implement` each stop and
> route back to `/feature-flow:ff-clarify` if this reads `no` (implement is the hard backstop). A
> waived review is recorded explicitly: "sign-off waived by user (date)" — never assumed.
