---
description: "[shared] Implement the planned work: feature from plan.md (sign-off gated), or a test-first bugfix from diagnosis.md (RED→fix→GREEN)."
argument-hint: "<feature: after /feature-flow:ff-plan + sign-off | bugfix: after /feature-flow:ff-diagnose>"
---

# /feature-flow:ff-implement — implementation phase

Implements the planned work for **either track**. Branch on `manifest.track`:
- **feature** → build the feature from `plan.md` (sign-off gated).
- **bugfix** → apply a **test-first** fix from `diagnosis.md` (RED before the fix, then GREEN).

> **Precedence — read first.** You are executing the feature-flow workflow. Its phases
> REPLACE any generic brainstorming / writing-plans / make-plan / docs-first planning: do
> **not** invoke those skills, and do **not** write to `~/.claude/plans/`, `docs/plans/`,
> or a separate brainstorm doc. All run state lives in the `.feature-flow/<slug>/` sandbox
> and its `manifest.json`. Follow this command's steps literally, run only this one phase,
> then STOP. In autopilot mode, ceremonial phase-end STOPs become continuations — see
> **Autopilot** in `${CLAUDE_PLUGIN_ROOT}/docs/manifest-schema.md`.

## Manifest contract

1. **Resolve the run** per **Run resolution** in
   `${CLAUDE_PLUGIN_ROOT}/docs/manifest-schema.md` (named slug → else the single /
   most-recently-updated run → ask if ambiguous), then read its `manifest.json`.
2. **Re-run guard:** if `phases.implement.status` is already `"complete"`, stop and ask for
   explicit confirmation before redoing the implementation — see **Re-run guard** in
   `${CLAUDE_PLUGIN_ROOT}/docs/manifest-schema.md`.
3. Set `phases.implement.status = "in_progress"` only **after** the gate passes.

## Gate — STOP if the contract is not satisfied

Read `manifest.track` and gate accordingly. Check the gate **before** any cold-start or
work, and write **no** code until it passes.

- **Feature track, or bugfix `tier: full` (AC4):** read `signOff` from the manifest and the
  `User signed off:` line in `spec.md` (feature) / `diagnosis.md` (escalated bugfix).
  **If sign-off is `no` / `signed: false`, STOP immediately.** Tell the user:

  > Implementation is gated on sign-off. Sign off on the contract
  > (`/feature-flow:ff-clarify` for a feature spec, `/feature-flow:ff-diagnose` for an escalated
  > bug's diagnosis), then re-run `/feature-flow:ff-implement`.

- **Bugfix `tier: lite` (AC13):** there is no separate sign-off; the gate is a **confirmed**
  diagnosis (reproduced + root cause + chosen fix approach), resolved via
  `manifest.artifacts.diagnosis` (manifest-first; sandbox fallback when the manifest is
  absent). **If the resolved diagnosis is missing, or the bug is "not reproduced", STOP** and
  route to `/feature-flow:ff-diagnose`. Never fix an unconfirmed bug.

**End your turn here when gated** — do not write code, and do not fall back to a generic
implement/plan workflow.

## Cold-start

**Resolve every contract artifact through the manifest pointer, in this exact order:**

1. **Read the manifest first** and take each artifact's path from `manifest.artifacts.<name>`
   (the sole locating authority) — the plan from `artifacts.plan`, the design from
   `artifacts.design`, the spec from `artifacts.spec`.
2. **Only when the manifest is absent**, use the sandbox fallback `<base>/<slug>/<name>.md`.

A promoted plan lives outside the sandbox (`<paths.durable>/<date>-<slug>/plan.md`), so
**never gate on a bare `plan.md` filename** — that bare-name check is exactly what would
false-fire "no `plan.md`" on a run whose plan was promoted out of the sandbox.

- **Feature:** with the resolved paths in hand, if `artifacts.plan`, `artifacts.design`, or
  `artifacts.spec` points at a file that does **not** exist on disk, route to the first
  missing artifact's phase (`/feature-flow:ff-plan` → `/feature-flow:ff-design` →
  `/feature-flow:ff-clarify`) rather than implementing against nothing — a missing design
  routes to `/feature-flow:ff-design` even when the plan exists.
- **Bugfix:** resolve `artifacts.diagnosis`; if it does not exist, route to
  `/feature-flow:ff-diagnose`.

## Do the work — feature track

Read the plan, spec, and design — resolving each path via `manifest.artifacts.<name>`
(manifest-first; sandbox fallback only when the manifest is absent, exactly as in Cold-start).
Implement the plan task by task. Honor config toggles:
- `toggles.tdd` (default true): write the test before the implementation for each unit
  with a clear contract; watch it fail, then make it pass.
- `toggles.worktree` (default false): if true, do the work in an isolated git worktree.
- `toggles.greenfield`: relaxes existing-codebase / `git diff` assumptions.

## Do the work — bugfix track (TEST-FIRST, mandatory RED→GREEN order)

Read the diagnosis via `manifest.artifacts.diagnosis` (root cause + chosen fix approach +
regression-test plan) and, if the bug escalated to `tier: full`, the plan via
`manifest.artifacts.plan` — manifest-first, sandbox fallback when the manifest is absent, as
in Cold-start. Then, **in this exact order**:

1. **Write the regression test** targeting the reproduced bug (per the diagnosis's
   regression-test plan).
2. **Run it and capture RED** — it MUST fail against the current, pre-fix code. Record the
   real failing output (command, exit status, failing assertion) into the manifest under
   `bugfix.red` so `/feature-flow:ff-verify` can cite it.
3. **Apply the minimal fix** per the diagnosis's chosen approach (root-cause unless a
   hotfix was explicitly chosen) — touching only the fix surface named in the diagnosis.
4. **Run the test again and capture GREEN** — record the passing output under `bugfix.green`.
5. Hand both the RED and GREEN evidence forward to `/feature-flow:ff-verify`.

> **Never apply the fix before the test has been observed failing.** Once the fix is in
> place the pre-fix RED state is unrecoverable and the RED→GREEN evidence cannot be met.
> If you cannot get the test to fail pre-fix, the test does not pin the bug — fix the test,
> not the order.

`toggles.worktree` / `toggles.greenfield` apply here too. **`toggles.tdd` does NOT apply to
the bugfix track** — the RED→GREEN order above is mandatory regardless of config; `tdd:
false` only relaxes test-first on the feature track.

## Update manifest

Set `phases.implement = { status: "complete", artifact: null }` (code lives in the repo,
not the sandbox), bump `updatedAt`, `currentPhase = "implement"`. On the bugfix track,
ensure the captured `bugfix.red` / `bugfix.green` evidence is recorded.

**STOP (step-by-step) / continue (autopilot).** If `manifest.autopilot` is `true`, emit
the progress strip and proceed directly into the next phase by track — **feature:**
`${CLAUDE_PLUGIN_ROOT}/commands/ff-review.md`; **bugfix:**
`${CLAUDE_PLUGIN_ROOT}/commands/ff-verify.md` — see **Autopilot** in
`${CLAUDE_PLUGIN_ROOT}/docs/manifest-schema.md`. If `false` or absent, **STOP** and hand
off by track (the two tracks end in opposite order — match the manifest):
- **feature:** run `/feature-flow:ff-review` next, then `/feature-flow:ff-verify` (verify is terminal).
- **bugfix:** run `/feature-flow:ff-verify` next (to confirm RED→GREEN), then
  `/feature-flow:ff-review` (review is terminal).

End the message with the one-line progress strip — see **Progress strip** in
`${CLAUDE_PLUGIN_ROOT}/docs/manifest-schema.md`. In step-by-step mode, end your turn (the
autopilot branch above continues instead).
