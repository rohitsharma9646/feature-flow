# Spec: assumption-gap fixture

**Created:** 2026-07-05
**Track:** feature (full tier)
**Status:** draft

## Problem

A minimal spec whose §Assumptions table carries one **unvalidated `validation-required: y`**
assumption — the exact hole `/feature-flow:ff-clarify`'s sign-off echo must surface as a
`### Unvalidated assumptions` block that blocks a clean sign-off (never folded into the AC
checkboxes). The second row is a `validation-required: n` control that must NOT echo.

## Expected outcome

The sign-off ask echoes the `y` row and cannot reach `signOff.signed = true` until it is
resolved (validated, waived, or — full tier — acknowledged as staying open → a plan `**Validates:**`
task); the `n` row is silent.

## Assumptions (WHAT-changing)

| Statement | Confidence | Basis / evidence | If-wrong impact | Validation-required |
|---|---|---|---|---|
| The upstream API returns ISO-8601 timestamps. | med | vendor docs, unverified against prod | date parsing + every downstream AC breaks | y |
| The feature flag defaults off in every environment. | high | confirmed in config review | none — already validated | n |

## Acceptance criteria

- [ ] **AC1** — timestamps render in the user's locale.

## Sign-off

**User signed off:** no
