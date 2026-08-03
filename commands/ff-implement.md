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

> **Integrity boundary — before every manifest state write:** run the canonical Command-level
> preflight in `docs/manifest-schema.md`; follow its legacy/current mode rule and stop on an
> enforce-mode denial or invocation failure.

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

- **Feature, `tier: full` (or unset):** with the resolved paths in hand, if `artifacts.plan`,
  `artifacts.design`, or `artifacts.spec` points at a file that does **not** exist on disk,
  route to the first missing artifact's phase (`/feature-flow:ff-plan` →
  `/feature-flow:ff-design` → `/feature-flow:ff-clarify`) rather than implementing against
  nothing — a missing design routes to `/feature-flow:ff-design` even when the plan exists.
- **Feature, `tier: lite`:** lite has **no design or plan phase** — require **only** `artifacts.spec`
  (resolved via the manifest pointer). If the resolved spec is missing, route to
  `/feature-flow:ff-clarify`; **never** route to `/feature-flow:ff-design` or `/feature-flow:ff-plan`
  on a lite run (those phases do not exist for lite). The sign-off gate above is unchanged —
  lite still requires `signOff.signed`.
- **Bugfix:** resolve `artifacts.diagnosis`; if it does not exist, route to
  `/feature-flow:ff-diagnose`.

## Decision recall

**Feature track only** (the bugfix track's contract is the diagnosis — skip this section on
bugfix). Run this **after Cold-start, before any Write/Edit call** in `## Do the work` — it is
the implement-side of **Decision recall**: it makes this run's recorded decision **constrain**
the code about to be written.

Resolve **this run's own decision** via `manifest.artifacts.decision` — the sole locating
authority, per **Durable artifact resolution** — **never a bare filename**. This read is
**unconditional of the KB toggle**: full tier resolves the promoted decision record, lite tier
resolves `manifest.artifacts.spec` (its `## Solution approaches considered` section *is* lite's
decision record — the pointer was set by `ff-clarify`). **The same pointer read serves both
tiers — no tier branch in the locating logic.** Absent `artifacts.decision` (a pre-v0.10.0
manifest) → "no decision recorded"; proceed, no error.

Then, when the KB is active (`toggles.kb === true` AND `paths.kb` non-null), also follow the
**Decision recall** procedure in `${CLAUDE_PLUGIN_ROOT}/docs/manifest-schema.md` §Knowledge base
(source 2 — tag-match prior decisions, apply the staleness flag; **stale** entries decorated
`[STALE — <reason>]`, never dropped) — **do not restate its steps here.** KB inactive → skip
this cross-run half only; the unconditional `artifacts.decision` read above still fires.

> **Do-not-contradict STOP.** Before writing any code, compare the approach you are about to
> implement against the decision(s) recalled above. If it **diverges** from this run's own
> recorded decision (source 1) or a prior KB decision (source 2), **STOP-and-surface —
> unconditional in both modes, no autopilot auto-resolve retry** (unlike the Critical-review fix
> cycle). Tell the user the conflicting decision and how the approach diverges; resolve **only**
> by the user realigning the implementation or replying with an explicit override, recorded
> verbatim as `Decision override by user (<date>): <reason>` in the resolved `artifacts.decision`
> record — never self-authored. No divergence, or nothing recalled → proceed to the work below.

## Critical-path check

**Whenever a full-tier plan exists** (`manifest.artifacts.plan` — the sole locating authority,
never a bare filename — resolves to a real file; feature full tier, or an escalated full-tier
bugfix). Lite tiers have no plan and **skip this section entirely**, same absent-tolerance as
Decision recall. Run this **after Decision recall, before any Write/Edit call** in `## Do the
work` — it is the implement-side actuator of **Planning intelligence**: the plan's *derived*
critical path does not just get filed, it **constrains** the order tasks may execute in.

Read the plan's `## Critical path` (derived by `/feature-flow:ff-plan` from its `## Dependency
graph` — see **Planning intelligence** in `${CLAUDE_PLUGIN_ROOT}/docs/manifest-schema.md`; do not
restate its steps here). Before executing a task, check whether the approach you are about to take
skips a task the critical path names, or executes critical-path tasks out of the stated order.

> **Critical-path STOP.** Copies the do-not-contradict shape of **Decision recall** above — same
> unconditional-in-both-modes rule, same verbatim-override rule, reused rather than reinvented. If
> the approach **skips or reorders** a critical-path task, **STOP unconditionally in both modes** —
> never self-resolved, never autopilot-retried. Tell the user which critical-path task is being
> skipped/reordered and why the approach requires it. Resolve **only** by (a) realigning the work
> to respect the critical path, or (b) an explicit user override recorded verbatim as
> `Critical-path override by user (<date>): <reason>` in the plan's `## Critical path` section
> (via `manifest.artifacts.plan`) — never self-authored. No divergence, or no critical path
> recorded (a pre-WS-2 plan) → one-line note, proceed.

**Rollback on a failed Verify step.** When any task's `Step N: Verify` fails during `## Do the
work` below, the recovery is **not** ad hoc: read that task's row in the plan's `## Rollback plan`
section (resolved via `manifest.artifacts.plan`) and apply its named recovery action before
deciding whether to retry the step or stop — never leave the tree half-applied. An "irreversible"
row means apply the stated mitigation and surface the failure, not a fake undo. Full tier only
(no plan → recover ad hoc, note it under the manifest's Blockers).

## Do the work — feature track

**Lite tier (`tier == "lite"`):** there is no plan or design — read the **spec**
(`manifest.artifacts.spec`) and implement its acceptance criteria directly, task by task
(as the bugfix-lite path implements from the diagnosis). The `toggles.tdd` rule below still
applies. **Full tier (or unset):** read the plan, spec, and design — resolving each path via
`manifest.artifacts.<name>`
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
