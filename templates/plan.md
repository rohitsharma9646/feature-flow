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

## Global Constraints

- <binding requirement every task inherits: an exact value, format, name or signature>
- <constraint copied verbatim from spec.md §Constraints or a binding decision in design.md>

> Copied verbatim from the spec's `## Constraints` and the design's binding decisions — never
> paraphrased. The controller copies this section unedited into every task brief, so it is the
> implementer's and the task reviewer's shared rule set; a step that contradicts it is a plan
> defect. Nothing beyond the spec's ACs → write "no additional constraints", never omit the
> section. See `${CLAUDE_PLUGIN_ROOT}/docs/schema/task-controller.md` §Task controller → Executable plans.

## Tasks

> **No Placeholders.** Every task must be executable by a fresh agent that has read only this
> task, `## Global Constraints` and the spec/design paths. Forbidden anywhere below: `TBD` /
> `TODO`; "add appropriate error handling" (or any hand-wave in place of a named behaviour);
> "similar to Task N" without the code repeated; a step with no concrete action; an unfilled `<…>`
> template placeholder; a test step without the complete test code in a fenced block; an
> implementation step that does not name the exact change; a `Consumes:` / `Produces:` name
> defined nowhere in this plan, the spec, the design or the codebase. `/feature-flow:ff-plan`
> checks every task against this list and fixes every hit before completing;
> `/feature-flow:ff-implement` re-checks before its first dispatch and stops on a hit.

**Self-check ran:** <yes — no hits | yes — hits found and fixed>

### Task 1: <title>

**Files:**
- Create / Modify: `<path>`

**Covers:** AC1, AC2   <!-- acceptance criteria from spec.md this task satisfies -->
**Validates:** Assumption 1   <!-- full tier: unvalidated validation-required:y assumption(s) this task validates; omit if none -->
**Interfaces:**
- Consumes: `<exact name and signature this task uses from an earlier task or the codebase>` | none
- Produces: `<exact name and signature a later task relies on>` | none

- [ ] **Step 1:** Write the failing test in `<test path>`:
  ```<language>
  <the complete test code>
  ```
  **Run:** `<test command>` **Expected:** fails — `<the failing assertion>`
- [ ] **Step 2:** Implement in `<path>`: <the exact change — function, signature, behaviour>
  (include the code in a fenced block when it is short or subtle).
- [ ] **Step 3: Verify** — **Run:** `<command>` **Expected:** `<exit status and output>`

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
