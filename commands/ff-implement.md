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
> **Autopilot** in `${CLAUDE_PLUGIN_ROOT}/docs/schema/autopilot.md`.

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

- **Feature track, or bugfix `tier: full`:** read `signOff` from the manifest and the
  `User signed off:` line in `spec.md` (feature) / `diagnosis.md` (escalated bugfix).
  **If sign-off is `no` / `signed: false`, STOP immediately.** Tell the user:

  > Implementation is gated on sign-off. Sign off on the contract
  > (`/feature-flow:ff-clarify` for a feature spec, `/feature-flow:ff-diagnose` for an escalated
  > bug's diagnosis), then re-run `/feature-flow:ff-implement`.

- **Bugfix `tier: lite`:** there is no separate sign-off; the gate is a **confirmed**
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
tiers — no tier branch in the locating logic.** Absent `artifacts.decision` (an older
manifest) → "no decision recorded"; proceed, no error.

Then, when the KB is active (`toggles.kb === true` AND `paths.kb` non-null), also follow the
**Decision recall** procedure in `${CLAUDE_PLUGIN_ROOT}/docs/schema/knowledge-base.md` §Knowledge base
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
graph` — see **Planning intelligence** in `${CLAUDE_PLUGIN_ROOT}/docs/schema/planning-intelligence.md`; do not
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
> recorded in the plan → one-line note, proceed.

**Rollback on a failed Verify step.** When any task's `Step N: Verify` fails during `## Do the
work` below, the recovery is **not** ad hoc: read that task's row in the plan's `## Rollback plan`
section (resolved via `manifest.artifacts.plan`) and apply its named recovery action before
deciding whether to retry the step or stop — never leave the tree half-applied. An "irreversible"
row means apply the stated mitigation and surface the failure, not a fake undo. Full tier only
(no plan → recover ad hoc, note it under the manifest's Blockers). **Under the controller**
(`## Controller loop`) a failed Verify step is a Critical conformance finding and goes through the
task's fix loop instead; if the task ends at the Critical-after-cap stop, name that task's Rollback
plan row in the stop message so the user can apply it — the controller never reverts on its own.

## Controller activation

The controller implements a full-tier plan one task at a time — a fresh `ff-implementer` per task,
a review of each task's diff, a capped fix loop, and a ledger on disk. Its rules are
**Task controller** in `${CLAUDE_PLUGIN_ROOT}/docs/schema/task-controller.md` (read that topic
file); this section and the next apply them.

Every gate above — sign-off, cold-start routing, Decision recall, Critical-path check — has already
run. Use the controller when **both** hold: the run is **full tier** (feature, or an escalated
bugfix), **and** the plan resolved via `manifest.artifacts.plan` has a `## Global Constraints`
heading. Otherwise implement **inline** — the two `## Do the work` sections below, unchanged. Either
way, state the path in one line of exactly this form, and repeat that line in the phase's final
summary: `Implement path: controller — <reason>` or `Implement path: inline — <reason>` (e.g.
`Implement path: inline — lite tier`, `Implement path: inline — the plan predates executable plans
(no ## Global Constraints)`).

**Pre-flight (controller only), before the first dispatch.** Check every task in the plan against the
plan's **No Placeholders** list (§Task controller → Executable plans). Any hit → **Plan placeholder
stop**, in both modes: name the task and the offending text, route the user to
`/feature-flow:ff-plan`, and end the turn — no task is dispatched from a plan with placeholders.

## Controller loop

Read `models.implementer`, `models.escalation` and `models.reviewer`, `reviewThreshold` and
`toggles.tdd` from config (`.feature-flow.json` → `${CLAUDE_PLUGIN_ROOT}/config/defaults.json`).
Task packaging (`task_section`, `task_diff`) and fingerprints run as **Task packaging** in
`${CLAUDE_PLUGIN_ROOT}/docs/schema/task-controller.md` and **Revision fingerprint** in
`${CLAUDE_PLUGIN_ROOT}/docs/schema/enforcement.md` specify — on Claude Code
`bash "${CLAUDE_PLUGIN_ROOT}/hooks/lib/task.sh" …` and `bash "${CLAUDE_PLUGIN_ROOT}/hooks/lib/revision.sh" "<project dir>"`;
where `hooks/` is not shipped, pipe those sections' blocks unchanged. No step below runs `git add`,
`commit`, `stash` or anything else that changes the index or history.

**Ledger.** Resolve `manifest.artifacts.ledger`. None → create `<run dir>/tasks/ledger.md` whose first
line is `# Ledger — plan: <the manifest.artifacts.plan path>`, and write its repo-relative path
(`<base>/<slug>/tasks/ledger.md`) to `artifacts.ledger` in the manifest **now**, before the first
dispatch. A ledger for a different plan → start a new one per
§Task controller → **Ledger**. Rewrite the ledger after every step below, before the next dispatch.
Start at the first task the ledger does not mark `complete (…)` (none yet → Task 1); a `blocked` or
`stopped` task is re-entered because the user re-ran this command after acting on it.

**For each task, in plan order:**

1. **Base.** If the task's ledger entry already has a `**Base:**`, **keep the recorded Base** — never
   recompute it on resume. Otherwise compute the fingerprint and record it with
   `**Status:** in-progress`. If it differs from the previous task's `**Head:**`, add a `**Drift:**`
   line naming the changed paths (`revision_changed_paths`). Not a git repository, or no fingerprint
   → `not recorded — <reason>`.
2. **Brief.** Write `<run dir>/tasks/task-<N>/brief.md`: the output of `task_section` for
   `^## Global Constraints` and for `^### Task <N>:` (never the whole plan), then the paths of the
   spec and design (bugfix: the diagnosis).
3. **Dispatch** one fresh **`ff-implementer`** with `model` = `models.implementer`, giving it the brief
   path, the report path `<run dir>/tasks/task-<N>/report.md`, and whether tdd is on. Record its status,
   model and agent id on the ledger's `**Implementer:**` line.
4. **Status** (§Task controller → **Status contract**):
   - `DONE` → step 5. `DONE_WITH_CONCERNS` → step 5, carrying the concerns into the review.
   - `NEEDS_CONTEXT` → answer from the spec, design and plan under `## Added context` in the brief and
     re-dispatch; at most twice per task — a third `NEEDS_CONTEXT` counts as `BLOCKED`.
   - `BLOCKED` → **Task blocked stop**, in both modes: ledger `blocked — <reason>`, tell the user the
     task and the blocker, and end the turn.
5. **Head and diff.** Compute the fingerprint again (`**Head:**`) and write
   `task_diff <project dir> <Base> <Head>` to `<run dir>/tasks/task-<N>/diff.patch`. Without
   fingerprints, write the report's changed-file list to `files.txt` instead.
6. **TDD.** With `toggles.tdd` on, copy the report's RED run (command, non-zero exit, failing
   assertion) and GREEN run (exit 0) to the ledger's `**TDD:**` line, or `TDD: exempt — <reason>`;
   `toggles.tdd: false` → `TDD: off (config)`.
7. **Bugfix (escalated full tier).** When the task whose Verify step is `Verify RED` completes, write
   its RED run to `manifest.bugfix.red` before the next task is dispatched (a RED task whose test
   passes pre-fix is a Critical finding); after the final task, write its GREEN run to
   `manifest.bugfix.green`.
8. **Review.** Dispatch one **`ff-code-reviewer`** (`model` = `models.reviewer`) with **paths only** —
   the brief, the report and `diff.patch` (or `files.txt`); never paste the diff into the prompt. Tell
   it: *review this one task and return two verdicts — conformance (the task's `**Covers:**` ACs are
   met, its `Produces:` interfaces exist as stated, the Global Constraints hold, nothing outside the
   task's `**Files:**` changed) and quality (bugs, edge cases, simplicity, conventions in this diff);
   report only findings scoring ≥ `reviewThreshold`, each Critical or Important; check each concern
   listed; do not spawn subagents.* Write its findings to `<run dir>/tasks/task-<N>/review.md`. Add two
   Critical conformance findings yourself when they apply: a `DONE` whose report shows its Verify step
   failing, and (tdd on) a code task with neither RED/GREEN evidence nor an exemption.
9. **Fix loop** (§Task controller → **Fix loop**), while a finding is open, **never more than 3
   rounds**. For round R, first write the ledger line `**Fix round R/3:** … — pending`, then:
   - **Rounds 1 and 2** resume the same implementer — `SendMessage` to its recorded agent id with the
     open findings; if it cannot be resumed, dispatch a fresh `ff-implementer` with the brief, the
     report and the findings.
   - **Round 3** dispatches a fresh `ff-implementer` on `models.escalation`, telling it two attempts
     failed and giving it the brief, the report and the findings; if that model cannot be dispatched,
     use `models.implementer` and write `escalation unavailable — used <model>` on the round line.
   - Then a new `**Head:**`, `task_diff <previous Head> <new Head>` into `fix-<R>.patch`, and one
     scoped re-review — `ff-code-reviewer` given the open findings and `fix-<R>.patch` by path, marking
     each finding `ADDRESSED` or `NOT ADDRESSED` and reporting only new breakage in the fix diff, into
     `rereview-<R>.md`. Rewrite the round line with its outcome.
10. **Close the task** (§Task controller → **Rulings**). No open finding → `complete (clean)`. After
    round 3, any open **Critical** → **Critical-after-cap stop**, in both modes: ledger
    `stopped — Critical after cap`, tell the user the task and the findings, end the turn. Only
    **Important** findings open → one `**Ruling:** <decision> — <why> — <cost if wrong>` per finding
    and `complete (<n> rulings)`. A task re-entered after this stop gets one fresh review of Base →
    current tree and no further rounds; a ledger line `Task <N> finding accepted by user (<date>):
    <reason>`, written by the user, closes it as `complete (<n> rulings)`. Tick the task's checkbox in
    the plan.

After the last task, list every `**Ruling:**` and `**Drift:**` line from the ledger in your summary,
then continue with `## Update manifest` below.

## Do the work — feature track

**Inline path** — used when `## Controller activation` above does not select the controller.
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

**Inline path** for a lite bugfix, or an escalated bugfix whose plan predates executable plans — a
controller run keeps the same RED→GREEN order through step 7 of `## Controller loop` instead.
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
`${CLAUDE_PLUGIN_ROOT}/docs/schema/autopilot.md`. If `false` or absent, **STOP** and hand
off by track (the two tracks end in opposite order — match the manifest):
- **feature:** run `/feature-flow:ff-review` next, then `/feature-flow:ff-verify` (verify is terminal).
- **bugfix:** run `/feature-flow:ff-verify` next (to confirm RED→GREEN), then
  `/feature-flow:ff-review` (review is terminal).

End the message with the one-line progress strip — see **Progress strip** in
`${CLAUDE_PLUGIN_ROOT}/docs/manifest-schema.md`. In step-by-step mode, end your turn (the
autopilot branch above continues instead).
