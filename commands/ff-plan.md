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
     **Sign-off gate:** if `spec.md` is not signed off (`signOff.signed != true` / `User signed
     off: no`), **STOP** and tell the user exactly:

     > The plan requires a **signed** spec (design/plan/implement all do). Run
     > `/feature-flow:ff-clarify` to sign off, then re-run `/feature-flow:ff-plan`.

   - **bugfix:** if this is a `tier: lite` run, **STOP** — lite bugs skip planning; route
     the user to `/feature-flow:ff-implement` (the confirmed diagnosis is the gate). If no
     `diagnosis.md` exists, route to `/feature-flow:ff-diagnose`. Do not plan against nothing.
     **Sign-off gate (full tier):** if `diagnosis.md` is not signed off (`signOff.signed !=
     true` / `User signed off: no`), **STOP** and tell the user exactly:

     > A full-tier fix requires a **signed** diagnosis (sign-off is collected there). Run
     > `/feature-flow:ff-diagnose` to record sign-off, then re-run `/feature-flow:ff-plan`.

3. **Re-run guard:** if `phases.plan.status` is already `"complete"`, stop and ask for
   explicit confirmation before overwriting `plan.md` — see **Re-run guard** in
   `${CLAUDE_PLUGIN_ROOT}/docs/manifest-schema.md`.
4. Read the contract: **feature** → `spec.md` + `design.md`; **bugfix** → `diagnosis.md`.
   Set `phases.plan.status = "in_progress"`, bump `currentPhase`.

## Do the work

Write `plan.md` from the track's template — **feature:**
`${CLAUDE_PLUGIN_ROOT}/templates/plan.md`; **bugfix (full):**
`${CLAUDE_PLUGIN_ROOT}/templates/plan-bugfix.md`. Decompose into bite-sized tasks, each with
files-to-touch and a verification step:
- **feature:** decompose the chosen design.
- **bugfix (full):** decompose the diagnosis's fix approach into tasks; the template already
  makes the **first task the test-first regression test** (write it, capture RED) before the
  fix tasks — preserve that AC11 order.

**Populate the Outcome gate** from the contract: contract path (`spec.md` or `diagnosis.md`),
acceptance-criteria / "bug no longer reproduces" reference, and the current `signOff` state
(`User signed off: <no | yes (date)>` — copy from the manifest, do not assume yes).

Resolve the plan path per the `artifacts` note in
`${CLAUDE_PLUGIN_ROOT}/docs/manifest-schema.md`: if `paths.plan` is set it is a **directory**
— write `<paths.plan>/<slug>.md` (create the dir if needed); else `<run dir>/plan.md`.
Record it in `artifacts.plan`.

## Update manifest

Set `phases.plan = { status: "complete", artifact: "<resolved plan path>" }`, bump
`updatedAt`.

**STOP.** Do not implement now. Tell the user to run `/feature-flow:ff-implement` next
(which will refuse to write code until the contract is signed off), ending the message with
the one-line progress strip — see **Progress strip** in
`${CLAUDE_PLUGIN_ROOT}/docs/manifest-schema.md` — then end your turn.
