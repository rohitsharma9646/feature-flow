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

## Edge cases

- <Boundary condition and the intended behavior for it.>

## Non-goals

- <Explicitly out of scope, so scope doesn't creep.>

## Acceptance criteria

Binary, checkable statements. Each must be verifiable by an executed check or an
explicit "manual — unverified" line in `verify.md`.

- [ ] AC1: <observable, testable statement>
- [ ] AC2: <observable, testable statement>

## Sign-off

**User signed off:** no

> A spec without sign-off does not proceed to **design, planning, or implementation** —
> `/feature-flow:ff-design`, `/feature-flow:ff-plan`, and `/feature-flow:ff-implement` each stop and
> route back to `/feature-flow:ff-clarify` if this reads `no` (implement is the hard backstop). A
> waived review is recorded explicitly: "sign-off waived by user (date)" — never assumed.
