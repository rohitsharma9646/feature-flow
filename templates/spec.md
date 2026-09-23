# Spec: <feature title>

**Created:** <date>
**Track:** feature
**Status:** draft | signed-off

## Problem

<What's wrong or missing today, and why it matters. One or two paragraphs.>

## Expected outcome

<What you will see / the observable end-state when this is done. Describe behavior,
not implementation.>

## Solution approaches considered

<The 2-3 problem-level approaches to the underlying need that were weighed (different *whats*,
not architectures). For each: a one-line trade-off. Mark the **chosen** one and why, and each
**rejected** one and why. If the feature genuinely had one sane approach, write "one obvious
approach: <X>" and say why no alternatives applied.>

## Assumptions (WHAT-changing)

Only assumptions that would change scope or acceptance criteria if wrong. Deep risk, pre-mortem, and
quality concerns (security/UX/a11y/cost/perf) belong in design/review, not here. One row per
assumption — see `docs/manifest-schema.md §Assumption records` for the contract.

| Statement | Confidence | Basis / evidence | If-wrong impact | Validation-required |
|---|---|---|---|---|
| <the WHAT-changing assumption> | low / med / high | <why it is believed, or empty> | <what breaks in scope/ACs if false> | y / n |

<!-- Confidence: low / med / high (categorical — no numeric scores). Validation-required: y / n —
     an author-set flag; a `y` row blocks a clean sign-off until resolved: validated (→ `n`), waived
     (→ `n`, waiver line is the record), or (full tier) acknowledged as staying open. Only an acknowledged-open row (still `y`, full tier)
     maps to a plan `**Validates:** Assumption N` task — a validated or waived row spawns none (see
     §Assumption records → Actuation 1/2). Row order is stable once written: position = N (first data
     row = Assumption 1). No assumptions → keep the header row and note "none". -->

## Constraints

- <Hard limits: compatibility, performance, security, scope, deadlines.>

## Touchpoints

The files, modules, and interfaces this change is expected to touch — from `explore.md`, named
concretely (`path/to/file`, `Class.method`, CLI flag, endpoint), not "the export code". Not a
design: *which* parts, not *how*. The spec-conformance reviewer reads this as the scope reference;
a change outside it is a scope question, not automatically a defect.

- `<path or interface>` — <why it is involved>

## Edge cases

- <Boundary condition and the intended behavior for it.>

## Non-goals

- <Explicitly out of scope, so scope doesn't creep.>

## Acceptance criteria

Binary, checkable statements. Each must be verifiable by an executed check or an
explicit "manual — unverified" line in `verify.md`.

- [ ] AC1: <observable, testable statement>
- [ ] AC2: <observable, testable statement>

## End-to-end check

One check that proves the **whole** feature works as a user would use it — a command, request, or
flow run end to end, with its observable result — not a restatement of one AC. Same binary
discipline as the acceptance criteria. `ff-verify` maps it into an `### E2E` contract item.

- [ ] E2E: <run `<command / flow>`> → <observable end result>

## Success metrics

> **Full tier only.** A lite spec omits this section entirely — no placeholder, no warning.

Optional. Each metric is a **binary threshold with a named measurement method** — the same binary,
checkable discipline as `## Acceptance criteria` above (that section owns the discipline; this is
**not a divergent grammar**): "metric M ≤/≥ T, measured by `<method>`". A metric that cannot be
phrased this way is not recorded (rejected during clarify, never a soft/directional statement). An
SM's number is its row order (first row = SM1), stable once written.

- [ ] SM1: <metric> ≤/≥ <threshold>, measured by `<method>`.

<!-- No metrics → keep the header and note "none". Each becomes a `### SM<n>` ff-verify contract
     item (docs/manifest-schema.md §Discovery fields → Actuation 1) — same Confidence ladder and
     Evidence-gap stop as an acceptance criterion. Presence-gated (absent/empty section → no SM
     blocks), never tier-gated: this template is shared by both tiers. -->

## Requirement graph

> **Full tier only.** A lite spec omits this section entirely — no placeholder, no warning.

Optional. AC-level dependencies, **reusing** `docs/manifest-schema.md` **§Planning intelligence**'s
dependency notation rather than defining a divergent grammar: one row per dependent AC, `Depends on`
naming only a strictly **lower-numbered** `AC<n>` (or "— (root)") already defined under
`## Acceptance criteria` above — never a phantom or higher-numbered AC (so a cycle is unexpressible).

| AC | Depends on |
|----|------------|
| AC1 | — (root) |
| AC2 | AC1 |

<!-- No edges → omit this section (not an all-root table). Feeds ff-plan's task `## Dependency
     graph` via the **Covers:** map (docs/manifest-schema.md §Discovery fields → Actuation 2); an
     edge that cannot be represented as a task dependency surfaces as an explicit Outcome-gate gap. -->

## Sign-off

**User signed off:** no

> A spec without sign-off does not proceed to **design, planning, or implementation** —
> `/feature-flow:ff-design`, `/feature-flow:ff-plan`, and `/feature-flow:ff-implement` each stop and
> route back to `/feature-flow:ff-clarify` if this reads `no` (implement is the hard backstop). A
> waived review is recorded explicitly: "sign-off waived by user (date)" — never assumed.
