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
> Write tool, run only this one phase, then STOP. In autopilot mode, ceremonial phase-end
> STOPs become continuations — see **Autopilot** in
> `${CLAUDE_PLUGIN_ROOT}/docs/manifest-schema.md`.

## Manifest contract

1. **Resolve the run** per **Run resolution** in
   `${CLAUDE_PLUGIN_ROOT}/docs/manifest-schema.md` (named slug → else the single /
   most-recently-updated run → ask if ambiguous), then read its `manifest.json`. Read `track`.
2. **Cold-start, by track:**
   - **feature:** resolve the design and spec via `manifest.artifacts.design` /
     `manifest.artifacts.spec` (manifest-first; sandbox fallback only when the manifest is
     absent). If the resolved design does not exist, tell the user to run
     `/feature-flow:ff-design` first; if the resolved spec is also missing, route back to
     `/feature-flow:ff-clarify`. Do not plan against nothing.
     **Sign-off gate:** if the spec is not signed off (`signOff.signed != true` / `User signed
     off: no`), **STOP** and tell the user exactly:

     > The plan requires a **signed** spec (design/plan/implement all do). Run
     > `/feature-flow:ff-clarify` to sign off, then re-run `/feature-flow:ff-plan`.

   - **bugfix:** if this is a `tier: lite` run, **STOP** — lite bugs skip planning; route
     the user to `/feature-flow:ff-implement` (the confirmed diagnosis is the gate). Resolve
     the diagnosis via `manifest.artifacts.diagnosis` (manifest-first; sandbox fallback when
     the manifest is absent); if it does not exist, route to `/feature-flow:ff-diagnose`. Do
     not plan against nothing.
     **Sign-off gate (full tier):** if the diagnosis is not signed off (`signOff.signed !=
     true` / `User signed off: no`), **STOP** and tell the user exactly:

     > A full-tier fix requires a **signed** diagnosis (sign-off is collected there). Run
     > `/feature-flow:ff-diagnose` to record sign-off, then re-run `/feature-flow:ff-plan`.

3. **Re-run guard:** if `phases.plan.status` is already `"complete"`, stop and ask for
   explicit confirmation before overwriting `plan.md` — see **Re-run guard** in
   `${CLAUDE_PLUGIN_ROOT}/docs/manifest-schema.md`.
4. Read the contract at the paths resolved in step 2 via `manifest.artifacts.<name>`:
   **feature** → `artifacts.spec` + `artifacts.design`; **bugfix** → `artifacts.diagnosis`.
   Set `phases.plan.status = "in_progress"`, bump `currentPhase`.

## Do the work

Write `plan.md` from the track's template — **feature:**
`${CLAUDE_PLUGIN_ROOT}/templates/plan.md`; **bugfix (full):**
`${CLAUDE_PLUGIN_ROOT}/templates/plan-bugfix.md`. Decompose into bite-sized tasks, each with
files-to-touch and a verification step:
- **feature:** decompose the chosen design.
- **bugfix (full):** decompose the diagnosis's fix approach into tasks; the template already
  makes the **first task the test-first regression test** (write it, capture RED) before the
  fix tasks — preserve that RED→GREEN order.
- **Map every AC (feature track):** each task names the acceptance criteria it covers
  (`**Covers:** AC1, …`); every AC in the spec must be covered by ≥1 task. If an AC has no
  task (e.g. satisfied by an existing test), record it as an explicit gap in the Outcome gate
  with a one-line reason — never leave an AC silently uncovered. (A full-tier **bugfix** has
  no spec/ACs — its contract is the diagnosis — so this mapping does not apply there.)
- **Map every unvalidated assumption (full tier — both tracks):** read the signed
  spec's `## Assumptions (WHAT-changing)` table (feature, via `manifest.artifacts.spec`) or the
  diagnosis's `## Assumptions` table (full bugfix, via `manifest.artifacts.diagnosis`). For **each
  still-unvalidated `validation-required: y`** assumption carried forward, emit a **validation task**
  carrying a `**Validates:** Assumption N` line (or record it as an explicit named gap in the Outcome
  gate) — cloning the `**Covers:**` discipline, per **Assumption records → Actuation 2** in
  `${CLAUDE_PLUGIN_ROOT}/docs/manifest-schema.md`. A validation task logically precedes the tasks that
  depend on the assumption (lower-numbered invariant); on the full-tier **bugfix** fold it into the
  fixed RED→GREEN sequence rather than adding a `**Covers:**` line (bugfix has no ACs). A **waived** or
  already-validated assumption spawns no task; when none remain, state "no unvalidated
  `validation-required: y` assumptions → no validation task".

**Derive planning intelligence (both tracks — feature and bugfix-full):** after the tasks above
are decomposed (and, feature track, AC-mapped — nothing to hang a graph on before the tasks
exist), populate the plan's four planning-intelligence sections per the canonical **Planning
intelligence** contract in `${CLAUDE_PLUGIN_ROOT}/docs/manifest-schema.md` — do not restate its
steps here:
- **Dependency graph** — one row per task naming its prerequisite `Task N` IDs (or "— (root)"),
  **only lower-numbered** tasks.
- **Critical path** — **derive** it (§Planning intelligence → Critical-path derivation): the
  longest dependency chain through the graph you just wrote, deterministic tie-break.
  **Never hand-author it independently of the graph.** Every task on it is a hard actuator —
  `/feature-flow:ff-implement` STOPs if the approach skips or reorders one.
- **Risk register** — categorical (Low/Med/High) rows, cross-referenced later by
  `/feature-flow:ff-verify`'s regression-risk assessment; no numeric scores.
- **Rollback plan** — the named recovery action per risky task if its `Step N: Verify` fails.

**Populate the Outcome gate** from the contract: the resolved contract path (from
`artifacts.spec` or `artifacts.diagnosis`), acceptance-criteria / "bug no longer reproduces"
reference, and the current `signOff` state
(`User signed off: <no | yes (date)>` — copy from the manifest, do not assume yes).

Resolve the plan's path per the **Durable artifact resolution** rule in
`${CLAUDE_PLUGIN_ROOT}/docs/manifest-schema.md` (legacy `paths.plan` → `paths.durable` →
sandbox `<run dir>/plan.md`; **create the target directory if absent**). Record the resolved
path in **both** `artifacts.plan` and `phases.plan.artifact`.

## Update manifest

Set `phases.plan = { status: "complete", artifact: "<resolved plan path>" }`, bump
`updatedAt`.

**STOP (step-by-step) / continue (autopilot).** If `manifest.autopilot` is `true`, emit
the progress strip and proceed directly into the implement phase per
`${CLAUDE_PLUGIN_ROOT}/commands/ff-implement.md` — see **Autopilot** in
`${CLAUDE_PLUGIN_ROOT}/docs/manifest-schema.md`; implement's own sign-off gate still
applies. If `false` or absent: do not implement now. Tell the user to run
`/feature-flow:ff-implement` next, ending the message with the one-line progress strip —
see **Progress strip** in `${CLAUDE_PLUGIN_ROOT}/docs/manifest-schema.md` — then end your
turn.
