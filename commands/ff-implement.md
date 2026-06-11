---
description: "[shared] Implement the planned work: feature from plan.md (sign-off gated), or a test-first bugfix from diagnosis.md (RED→fix→GREEN)."
argument-hint: "<feature: after /ff-plan + sign-off | bugfix: after /ff-diagnose>"
---

# /ff-implement — implementation phase

Implements the planned work for **either track**. Branch on `manifest.track`:
- **feature** → build the feature from `plan.md` (sign-off gated).
- **bugfix** → apply a **test-first** fix from `diagnosis.md` (RED before the fix, then GREEN).

> **Precedence — read first.** You are executing the feature-flow workflow. Its phases
> REPLACE any generic brainstorming / writing-plans / make-plan / docs-first planning: do
> **not** invoke those skills, and do **not** write to `~/.claude/plans/`, `docs/plans/`,
> or a separate brainstorm doc. All run state lives in the `.feature-flow/<slug>/` sandbox
> and its `manifest.json`. Follow this command's steps literally, run only this one phase,
> then STOP.

## Manifest contract

1. Resolve config + manifest (read `.feature-flow.json` →
   `${CLAUDE_PLUGIN_ROOT}/config/defaults.json`; locate the run's `manifest.json`).
2. Set `phases.implement.status = "in_progress"` only **after** the gate passes.

## Gate — STOP if the contract is not satisfied

Read `manifest.track` and gate accordingly. Check the gate **before** any cold-start or
work, and write **no** code until it passes.

- **Feature track, or bugfix `tier: full` (AC4):** read `signOff` from the manifest and the
  `User signed off:` line in `spec.md` (feature) / `diagnosis.md` (escalated bugfix).
  **If sign-off is `no` / `signed: false`, STOP immediately.** Tell the user:

  > Implementation is gated on sign-off. Sign off on the contract
  > (`/feature-flow:ff-clarify` for a feature spec, `/feature-flow:ff-plan` for an escalated
  > bug), then re-run `/feature-flow:ff-implement`.

- **Bugfix `tier: lite` (AC13):** there is no separate sign-off; the gate is a **confirmed**
  `diagnosis.md` — reproduced + root cause + chosen fix approach. **If `diagnosis.md` is
  missing, or the bug is "not reproduced", STOP** and route to `/feature-flow:ff-diagnose`.
  Never fix an unconfirmed bug.

**End your turn here when gated** — do not write code, and do not fall back to a generic
implement/plan workflow.

## Cold-start

- **Feature:** if there is no `plan.md` (or no `spec.md`), route to the prior phase
  (`/ff-plan` → `/ff-design` → `/ff-clarify`) rather than implementing against nothing.
- **Bugfix:** if there is no `diagnosis.md`, route to `/ff-diagnose`.

## Do the work — feature track

Read `plan.md`, `spec.md`, and `design.md`. Implement the plan task by task. Honor config
toggles:
- `toggles.tdd` (default true): write the test before the implementation for each unit
  with a clear contract; watch it fail, then make it pass.
- `toggles.worktree` (default false): if true, do the work in an isolated git worktree.
- `toggles.greenfield`: relaxes existing-codebase / `git diff` assumptions.

## Do the work — bugfix track (TEST-FIRST, mandatory order — AC11)

Read `diagnosis.md` (root cause + chosen fix approach + regression-test plan) and `plan.md`
if the bug escalated to `tier: full`. Then, **in this exact order**:

1. **Write the regression test** targeting the reproduced bug (per the diagnosis's
   regression-test plan).
2. **Run it and capture RED** — it MUST fail against the current, pre-fix code. Record the
   real failing output (command, exit status, failing assertion) into the manifest under
   `bugfix.red` so `/ff-verify` can cite it.
3. **Apply the minimal fix** per `diagnosis.md`'s chosen approach (root-cause unless a
   hotfix was explicitly chosen) — touching only the fix surface named in the diagnosis.
4. **Run the test again and capture GREEN** — record the passing output under `bugfix.green`.
5. Hand both the RED and GREEN evidence forward to `/ff-verify`.

> **Never apply the fix before the test has been observed failing.** Once the fix is in
> place the pre-fix RED state is unrecoverable and AC11 (RED→GREEN evidence) cannot be met.
> If you cannot get the test to fail pre-fix, the test does not pin the bug — fix the test,
> not the order.

`toggles.worktree` / `toggles.greenfield` apply here too.

## Update manifest

Set `phases.implement = { status: "complete", artifact: null }` (code lives in the repo,
not the sandbox), bump `updatedAt`, `currentPhase = "implement"`. On the bugfix track,
ensure the captured `bugfix.red` / `bugfix.green` evidence is recorded.

**STOP.** Tell the user to run `/feature-flow:ff-review` next (then `/feature-flow:ff-verify`),
and end your turn.
