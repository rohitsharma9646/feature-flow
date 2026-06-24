# Plan: <feature title>

**Goal:** <one sentence>

## Outcome gate

**Spec:** `<path to spec.md>`
**Acceptance criteria:** see spec §Acceptance criteria (AC1–ACn). Each task below maps
to specific ACs; the final task verifies all of them.
**User signed off:** <no | yes (date)>

> No task executes while sign-off is "no". At completion, `/feature-flow:ff-verify` checks the
> result against the spec's acceptance criteria — not just the task list.
>
> Every spec AC maps to ≥1 task's `**Covers:**` line. An AC with no task (e.g. already
> satisfied by an existing test) is listed here as an explicit gap with a one-line reason —
> never silently uncovered.

## Tasks

### Task 1: <title>

**Files:**
- Create / Modify: `<path>`

**Covers:** AC1, AC2   <!-- acceptance criteria from spec.md this task satisfies -->

- [ ] **Step 1:** <bite-sized action>
- [ ] **Step 2: Verify** — <command + expected output>

### Task 2: <title>

- [ ] **Step 1:** ...

## Status conventions

Stateful document. After each task bump its status:
`[ ]` pending · `[~]` in progress · `[x]` done · `[!]` blocked · `[→]` deferred.
Keep a Status summary line current; append Blockers / Deviations / Decisions as needed.

## Blockers

(none yet)

## Decisions made during execution

(none yet)
