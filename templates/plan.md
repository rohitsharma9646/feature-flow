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
>
> **Assumption validation (full tier).** Every **unvalidated `validation-required: y`** assumption
> carried from the signed spec/diagnosis maps to ≥1 task's `**Validates:** Assumption N` line, or is
> listed here as an explicit named gap — cloning the `**Covers:**` rule (see `${CLAUDE_PLUGIN_ROOT}/docs/schema/assumption-records.md`
> §Assumption records → Actuation 2). A validated or **waived** assumption spawns no task; state
> "no unvalidated `validation-required: y` assumptions → no validation task" when there are none.
>
> **Requirement-graph coverage (full tier, when the spec has a `## Requirement graph`).** Every spec
> `AC_i depends-on AC_j` edge that can be represented is folded into `## Dependency graph` below as a
> task-dependency edge (ordering tasks to satisfy it — see `${CLAUDE_PLUGIN_ROOT}/docs/schema/discovery-fields.md`
> §Discovery fields → Actuation 2). An edge whose two ACs are **covered by the same Task** (or that no
> numbering satisfies) cannot be a task dependency and is listed here as an explicit named gap
> naming the reason (e.g. `AC_i depends-on AC_j: covered by the same Task <n>`) — never silently
> dropped. No requirement
> graph, or one with no edges → this rule does not apply.

## Tasks

### Task 1: <title>

**Files:**
- Create / Modify: `<path>`

**Covers:** AC1, AC2   <!-- acceptance criteria from spec.md this task satisfies -->
**Validates:** Assumption 1   <!-- full tier: unvalidated validation-required:y assumption(s) this task validates; omit if none -->

- [ ] **Step 1:** <bite-sized action>
- [ ] **Step 2: Verify** — <command + expected output>

### Task 2: <title>

- [ ] **Step 1:** ...

## Dependency graph

| Task | Depends on |
|------|------------|
| Task 1 | — (root) |
| Task 2 | Task 1 |

> One row per task in `## Tasks` above. `Depends on` names only **lower-numbered** `Task N`
> IDs already defined above (or "— (root)" for no prerequisite) — never a phantom or a
> higher-numbered task. Multiple roots are normal; this is dependency data, not an instruction
> to run tasks concurrently.

## Critical path

**Path:** Task 1 → Task 2

> **Derived — never hand-authored.** The longest dependency chain through the graph above (per
> `${CLAUDE_PLUGIN_ROOT}/docs/schema/planning-intelligence.md` §Planning intelligence → Critical-path
> derivation). Every task named here is non-skippable, in this order: `/feature-flow:ff-implement`
> STOPs if the approach skips or reorders one. No dependencies at all → "no gating chain — all
> tasks independent"; fully linear plan → the whole task sequence. Re-derive if the graph changes.

## Risk register

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|-----------|
| <what could go wrong> | Low / Med / High | Low / Med / High | <mitigation, or "accepted, not mitigated: <reason>"> |

> Categorical only — **no numeric scores** (upholds the no-numeric-confidence doctrine).
> `/feature-flow:ff-verify` cross-references this register into its `## Regression risk`
> assessment instead of deriving risk cold. A risk accepted without mitigation says so.

## Rollback plan

| Task | Recovery action if `Step N: Verify` fails |
|------|--------------------------------------------|
| Task 1 | <e.g. `git checkout -- <path>` — or "irreversible: mitigation is <X>"> |

> One row per task that risks a half-applied state. `/feature-flow:ff-implement` runs this
> recovery instead of leaving the tree half-applied when a Verify step fails. An irreversible
> step states "irreversible: mitigation is `<X>`" rather than a fake undo.

## Status conventions

Stateful document. After each task bump its status:
`[ ]` pending · `[~]` in progress · `[x]` done · `[!]` blocked · `[→]` deferred.
Keep a Status summary line current; append Blockers / Deviations / Decisions as needed.

## Blockers

(none yet)

## Decisions made during execution

(none yet)
