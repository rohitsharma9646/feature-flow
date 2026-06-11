---
description: "[shared] Turn the contract (feature spec+design, or an escalated bug's diagnosis) into a phased plan.md with an Outcome gate."
argument-hint: "<feature: after /feature-flow:ff-design | full-tier bug: after /feature-flow:ff-diagnose>"
---

# /feature-flow:ff-plan — plan phase

You are running the **plan** phase. Output: `plan.md` with a populated Outcome gate. This
phase serves the **feature** track and **escalated (`tier: full`) bugfixes** — a trivial
(`tier: lite`) bug skips planning and goes straight from `/feature-flow:ff-diagnose` to `/feature-flow:ff-implement`.

> **Precedence — read first.** You are executing the feature-flow workflow. Its phases
> REPLACE any generic brainstorming / writing-plans / make-plan / docs-first planning: do
> **not** invoke those skills, and do **not** write to `~/.claude/plans/`, `docs/plans/`,
> or a separate brainstorm doc. All run state lives in the `.feature-flow/<slug>/` sandbox
> and its `manifest.json`. Follow this command's steps literally, create files with the
> Write tool, run only this one phase, then STOP.

## Manifest contract

1. **Resolve the run** per **Run resolution** in
   `${CLAUDE_PLUGIN_ROOT}/docs/manifest-schema.md` (named slug → else the single /
   most-recently-updated run → ask if ambiguous), then read its `manifest.json`. Read `track`.
2. **Cold-start, by track:**
   - **feature:** if no `design.md` exists, tell the user to run `/feature-flow:ff-design` first; if
     `spec.md` is also missing, route back to `/feature-flow:ff-clarify`. Do not plan against nothing.
   - **bugfix:** if this is a `tier: lite` run, **STOP** — lite bugs skip planning; route
     the user to `/feature-flow:ff-implement` (the confirmed diagnosis is the gate). If no
     `diagnosis.md` exists, route to `/feature-flow:ff-diagnose`. Do not plan against nothing.
3. Read the contract: **feature** → `spec.md` + `design.md`; **bugfix** → `diagnosis.md`.
   Set `phases.plan.status = "in_progress"`, bump `currentPhase`.

## Do the work

Write `plan.md` from `${CLAUDE_PLUGIN_ROOT}/templates/plan.md`. Decompose into bite-sized
tasks, each with files-to-touch and a verification step:
- **feature:** decompose the chosen design.
- **bugfix (full):** decompose the diagnosis's fix approach into tasks, and make the **first
  task the test-first regression test** (write it, capture RED) before the fix tasks — so the
  plan preserves the AC11 order.

**Populate the Outcome gate** from the contract: contract path (`spec.md` or `diagnosis.md`),
acceptance-criteria / "bug no longer reproduces" reference, and the current `signOff` state
(`User signed off: <no | yes (date)>` — copy from the manifest, do not assume yes).

Resolve the plan path: if `paths.plan` is set in config, write there; else `<run dir>/plan.md`.
Record it in `artifacts.plan`.

## Update manifest

Set `phases.plan = { status: "complete", artifact: "<resolved plan path>" }`, bump
`updatedAt`.

**STOP.** Do not implement now. Tell the user to run `/feature-flow:ff-implement` next
(which will refuse to write code until the contract is signed off), then end your turn.
