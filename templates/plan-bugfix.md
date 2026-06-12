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

## Status conventions

Stateful document. After each task bump its status:
`[ ]` pending · `[~]` in progress · `[x]` done · `[!]` blocked · `[→]` deferred.
Keep a Status summary line current; append Blockers / Deviations / Decisions as needed.

## Blockers

(none yet)

## Decisions made during execution

(none yet)
