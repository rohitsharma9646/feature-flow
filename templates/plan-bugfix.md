# Plan: <bug title>

**Goal:** <one sentence: what the fix restores>
**Track:** bugfix
**Tier:** full

## Outcome gate

**Diagnosis:** `<path to diagnosis.md>`
**Contract:** the bug no longer reproduces; the regression test shows RED (pre-fix) →
GREEN (post-fix), evidence recorded in `manifest.bugfix.red` / `manifest.bugfix.green`.
**User signed off:** <no | yes (date)>

> No task executes while sign-off is "no". At completion, `/feature-flow:ff-verify` cites the
> RED→GREEN evidence and confirms the bug no longer reproduces — not just the task list.

## Tasks

### Task 1: Failing regression test (MUST run first — RED before any fix)

**Files:**
- Create: `<test file path>`

- [ ] **Step 1:** Write the regression test per the diagnosis's regression-test plan.
- [ ] **Step 2: Verify RED** — run `<test command>`; it MUST fail against the current,
  pre-fix code. Record command, exit status, and failing output in `manifest.bugfix.red`.

### Task 2: Apply the fix

**Files:**
- Modify: `<path — only the fix surface named in diagnosis.md>`

- [ ] **Step 1:** Apply the chosen fix approach from `diagnosis.md` (root-cause unless a
  hotfix was explicitly chosen).
- [ ] **Step 2: Verify GREEN** — run `<test command>`; it must pass. Record the passing
  output in `manifest.bugfix.green`.

### Task 3: <any further task from the diagnosis's fix approach>

- [ ] **Step 1:** ...
- [ ] **Step 2: Verify** — <command + expected output>

## Dependency graph

| Task | Depends on |
|------|------------|
| Task 1 (regression test) | — (root) |
| Task 2 (apply fix) | Task 1 |
| Task 3 (further, if present) | Task 2 |

> One row per task in `## Tasks` above; `Depends on` names only **lower-numbered** `Task N` IDs
> (or "— (root)"). RED→GREEN is a hard dependency made explicit here: the fix (Task 2) depends on
> the failing regression test (Task 1) — never reorder Task 1 after Task 2. Same notation as
> `${CLAUDE_PLUGIN_ROOT}/templates/plan.md`.

## Critical path

**Path:** Task 1 → Task 2 (→ Task 3, if present)

> **Derived — never hand-authored.** The longest dependency chain through the graph above (per
> `${CLAUDE_PLUGIN_ROOT}/docs/schema/planning-intelligence.md` §Planning intelligence → Critical-path
> derivation). A typical bugfix has no independent side task, so the whole RED→GREEN sequence is
> the critical path — `/feature-flow:ff-implement` STOPs if the approach skips or reorders one of
> these tasks. Re-derive if a further task changes the chain.

## Risk register

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|-----------|
| <what could go wrong> | Low / Med / High | Low / Med / High | <mitigation, or "accepted, not mitigated: <reason>"> |

> Categorical only — **no numeric scores**. `/feature-flow:ff-verify` cross-references this
> register into its `## Regression risk` assessment instead of deriving risk cold.

## Rollback plan

| Task | Recovery action if `Step N: Verify` fails |
|------|--------------------------------------------|
| Task 1 (RED) | test doesn't fail pre-fix → fix the test, not the order; never proceed to Task 2 |
| Task 2 (GREEN) | test still fails post-fix → revert the fix edit (`git checkout -- <path>`), re-diagnose |

> `/feature-flow:ff-implement` runs the matching recovery when a Verify step fails, instead of
> leaving the tree half-applied. An irreversible fix states "irreversible: mitigation is `<X>`"
> rather than a fake undo.

## Status conventions

Stateful document. After each task bump its status:
`[ ]` pending · `[~]` in progress · `[x]` done · `[!]` blocked · `[→]` deferred.
Keep a Status summary line current; append Blockers / Deviations / Decisions as needed.

## Blockers

(none yet)

## Decisions made during execution

(none yet)
