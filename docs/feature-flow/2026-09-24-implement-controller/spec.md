# Spec: ff-implement as a per-task controller, with executable plans

**Created:** 2026-09-24
**Track:** feature
**Status:** signed-off

## Problem

`/feature-flow:ff-implement` is the only phase that still does all of its work inline, in the
orchestrator's own context: one agent reads the plan, spec and design, then writes every task's code
and tests in one continuous session. Measured consequences (July architectural review F11, and the
last two 10-task self-runs): 332–426 tool calls and ~5 context compactions per session; no task is
checked until `ff-review` runs over the whole change, so a defect introduced in task 2 is built on by
tasks 3–10; and a compaction mid-implement leaves nothing finer than `phases.implement:
in_progress` to resume from — the plan's checkboxes are the only per-task state.

Plans are the other half of the problem: task steps are prose (`<bite-sized action>`), so the
implementing agent re-derives names, signatures and test code the planner already decided, and a
task cannot be handed to a fresh agent that has not read everything.

## Expected outcome

On a full-tier run, `ff-implement` becomes a **controller**: for each plan task, in order, it writes a
brief containing only that task (plus the plan's global constraints and the task's interfaces),
dispatches a fresh implementer subagent with it, captures the task's before/after code state as a
diff file without committing, has one reviewer check that diff for conformance to the task's ACs and
for quality, runs a capped fix loop with model escalation, and records everything in a task ledger on
disk. A new session or a compaction resumes at the first incomplete task. Any Critical finding still
open after the cap stops the run; Important findings left open become recorded rulings listed at the
end and handed to `ff-review`. Plans written by `ff-plan` carry global constraints, per-task
interfaces and runnable steps with expected output, and contain no placeholders. Lite runs and plans
from earlier versions implement inline exactly as today.

## Solution approaches considered

- **Chosen — full controller + executable plans.** Fresh implementer per task, per-task review on a
  diff file, ledger, capped escalating fix loop, and plans detailed enough to hand one task to a fresh
  agent. The only option that addresses context, early defect detection and fine-grained resume
  together; the largest change. (User choice, 2026-09-24.)
- **Rejected — checkpoints only** (keep implementing inline, add a ledger and a reviewer after each
  task). Catches defects earlier and resumes better, but the main context still does all the work, so
  the compaction problem remains.
- **Rejected — plans first** (executable plans + ledger now, controller in a later run). Lowest risk,
  but ships the least benefit and leaves plans nobody consumes task-by-task yet.

Sub-decisions taken in clarify (user, 2026-09-24): fix loop = 2 rounds resuming the same implementer,
then 1 round with a fresh implementer on a stronger model, then stop; task code state = working-tree
fingerprints (no commits); applies to full-tier plans (features and escalated bugfixes), lite stays
inline; final `ff-review` unchanged apart from receiving its diff as a file; one reviewer per task
giving two verdicts; per-task RED→GREEN evidence recorded in the ledger; after the cap, open Critical
→ stop, Important-only → recorded ruling.

## Assumptions (WHAT-changing)

| Statement | Confidence | Basis / evidence | If-wrong impact | Validation-required |
|---|---|---|---|---|
| On Claude Code, a plugin command can dispatch a plugin-defined agent that has `Write`, `Edit` and `Bash` tools, and that agent's edits land in the user's working tree | high | explore: agent frontmatter `tools:` is honoured for the 5 existing agents; `ff-test-runner` already has `Bash` | No subagent can implement; the controller would have to run inline everywhere, removing the context benefit | n |
| A dispatched implementer can be **resumed** with its context intact for fix rounds 1–2 (Claude Code `SendMessage` to the agent id) | med | available in this harness; not yet exercised by any Feature Flow command | Rounds 1–2 would become fresh dispatches given the previous report + findings; the round structure (2 + 1 escalated) stays, only "resume" changes to "re-dispatch with history" | y |
| A plan with runnable steps and real test code per testable task stays small enough for `ff-plan` to author reliably and for a task brief to fit comfortably in a subagent's context | high | Validated 2026-09-24 (plan Task 4, `evidence/a3-plan-size.md`): with full code a task grew 23 → 242 lines (~10×); under the lighter rule the user chose (full test code + interfaces, implementation code only where short or subtle) ~6×, briefs ≈ 150–250 lines | Plans would need a lighter rule (code only for interfaces/tests, not implementations); the AC for step content would change — applied: AC1 amended | n |

## Constraints

- **Never-commit doctrine unchanged:** no `git add`, `git commit`, `git stash` or index writes by the
  controller or any agent; task diffs come from working-tree fingerprints in a throwaway index
  (`hooks/lib/revision.sh`).
- **Existing gates unchanged and still first:** sign-off gate, cold-start routing, Decision recall
  do-not-contradict STOP, Critical-path STOP and rollback-on-failed-Verify all run exactly as today,
  before the first dispatch.
- **Caps are artifact-resident:** the fix-round count and rulings live in the ledger; no new manifest
  counter, no config key for the cap (house doctrine, `repair-loop-guard.sh` AC6). The only new
  manifest datum is the `artifacts.ledger` pointer.
- **Sequential execution:** one task at a time, in plan order; no parallel implementers.
- **Codex parity:** Codex ships no `hooks/` or `scripts/`; the procedure is prose in the command and
  contract, the fingerprint uses the verbatim recipe, and without multi-agent tooling the same loop
  runs inline preserving role boundaries.
- **No Go kernel calls** (`integrity-boundary-guard.sh` stays green).
- Plan-template changes must not break pinned text: section order `## Tasks` < `## Dependency graph`
  < `## Critical path` < `## Risk register` < `## Rollback plan` < `## Status conventions`, the
  `| Task | Depends on |` header, and `**Validates:** Assumption N`.
- Enforcement hook (Gates A/B) and revision binding behave exactly as in 0.22.0.
- Release as **0.23.0**.

## Touchpoints

- `commands/ff-implement.md` — the controller procedure (full tier); lite and legacy paths unchanged.
- `agents/ff-implementer.md` (new) — the editing implementer role.
- `agents/ff-code-reviewer.md` — task-review use (brief + diff file, two verdicts), if its text needs it.
- `commands/ff-plan.md`, `templates/plan.md`, `templates/plan-bugfix.md` — Global Constraints,
  per-task Interfaces, runnable steps with `Expected:`, No Placeholders rule + self-check.
- `commands/ff-review.md` — diff handed to reviewers as a file; ledger rulings given to reviewers.
- `commands/ff-resume.md`, `hooks/session-start` — task-level resume / re-anchor via the ledger.
- `docs/manifest-schema.md` — `artifacts.ledger`, Known-keys line, topic index.
- `docs/schema/` — a new topic for the controller (ledger, status contract, fix loop, rulings);
  `autopilot.md` mandatory-pause rows; `planning-intelligence.md` (or the new topic) for plan fields.
- `config/defaults.json` — `models.implementer`, `models.escalation`.
- `skills/feature-flow/references/codex-tools.md`, `skills/feature-flow/SKILL.md` — the editing role,
  inline fallback.
- `scripts/checks/` — a new structural guard; `scripts/checks/lib/schema.sh` and
  `claude-dist-guard.sh` if a topic file is added; `evals/forward/` — a controller forward test.
- Version files, README, CHANGELOG, `dist/codex` — 0.23.0.

## Edge cases

- **Task with no code change** (a validation or docs-check task): an empty diff is accepted only when
  the implementer's report says why; the reviewer still checks conformance.
- **Implementer edits files outside the task's `**Files:**`**: the reviewer reports it as a
  conformance finding (scope), not silently accepted.
- **Tree changed between tasks** (the user edited during the run): the controller records the drift in
  the ledger and takes the current tree as the next task's base, so the next diff contains only that
  task's changes.
- **Resume mid-fix-round:** the ledger's last round line decides the next round; an escalated round
  already used is never repeated.
- **Ledger belongs to a different plan** (plan path in its first line differs from
  `manifest.artifacts.plan`): not reused; the controller starts a new ledger and says so.
- **`toggles.tdd: false`:** no RED→GREEN required per task; the ledger records `TDD: off (config)`.
- **Implementer returns `DONE` but its own report shows the task's `Verify` step failing:** treated
  as a Critical conformance finding, entering the fix loop.
- **Codex without multi-agent tooling:** same files, same order, performed inline.

## Non-goals

- Parallel implementers or using the dependency graph for concurrency.
- Per-task commits, automatic worktrees, or any change to `toggles.worktree`.
- Changing the lite tiers (feature lite, bugfix lite) — they implement inline as today.
- Slimming or restructuring `ff-review` beyond passing its diff as a file and showing it the rulings.
- Unifying the review fix cycle, verify repair cycle and stale re-run into one budget (recommendation
  #5 beyond the per-task loop).
- Choosing a model per task from the plan, or transcript/cost analysis in `ff-retro`.
- Hook enforcement of per-task review (the controller loop is prose-enforced; Gates A/B unchanged).
- Migrating plans written before 0.23.0.

## Acceptance criteria

**Executable plans**

- [ ] AC1: `templates/plan.md` and `templates/plan-bugfix.md` define a `## Global Constraints` section
  before `## Tasks`, a per-task `**Interfaces:**` block (`Consumes:` / `Produces:` with exact names and
  signatures, or `none`), steps that carry the complete test code in a fenced block wherever the
  step writes a test, implementation steps that name the exact change (files, functions, signatures,
  behaviour) with code included where it is short or subtle, plus `Run:` and `Expected:` lines for
  every step that runs something, and a **No Placeholders** rule
  listing the forbidden patterns (e.g. `TBD`, "add appropriate error handling", "similar to Task N"
  without the code, a step with no concrete action, a reference to an undefined name) — with all
  currently pinned template text unchanged.
- [ ] AC2: `ff-plan` authors those fields on full-tier plans and, before completing, checks its own
  plan against the No Placeholders rule and fixes every hit; the plan records that the check ran.

**Controller activation and pre-flight**

- [ ] AC3: `ff-implement` uses the controller when the run is full tier (feature, or escalated
  bugfix) **and** the resolved plan has a `## Global Constraints` section; otherwise (lite tier, or a
  plan without that section) it implements inline exactly as in 0.22.0 and says which path it took and
  why. The sign-off gate, cold-start routing, Decision recall STOP and Critical-path STOP run before
  the first dispatch, unchanged.
- [ ] AC4: Before the first dispatch, the controller checks every task for No Placeholders violations;
  any hit **stops** the phase (both modes) naming the task and the offending text, routing to
  `/feature-flow:ff-plan` — no task is dispatched from a plan with placeholders.

**Ledger**

- [ ] AC5: The controller keeps a ledger at `<run dir>/tasks/ledger.md`, located via
  `manifest.artifacts.ledger`; its first line names the plan path it belongs to; it has one entry per
  task recording status, base and head fingerprints, implementer status, review verdicts, each fix
  round, rulings and TDD evidence; it is updated after every state change and before the next
  dispatch.

**Per-task implementation**

- [ ] AC6: For each task, in plan order, the controller writes `<run dir>/tasks/task-<N>/brief.md`
  containing only that task's section, the plan's `## Global Constraints`, the task's
  `**Interfaces:**`, and the paths of the spec and design — not the whole plan — and dispatches one
  fresh `ff-implementer` agent (model `models.implementer`) given the brief's path.
- [ ] AC7: The implementer ends with exactly one status — `DONE`, `DONE_WITH_CONCERNS`,
  `NEEDS_CONTEXT` or `BLOCKED` — and a summary of at most 15 lines, with its full report in
  `task-<N>/report.md`. `NEEDS_CONTEXT` → the controller adds the missing context to the brief and
  re-dispatches, at most twice per task, then treats it as `BLOCKED`. `BLOCKED` → the phase stops
  (both modes) naming the task and the blocker. `DONE_WITH_CONCERNS` → the concerns are passed to the
  task reviewer as items to check.
- [ ] AC8: The controller records the working-tree fingerprint before dispatch (base) and after the
  implementer finishes (head), and writes `task-<N>/diff.patch` — the diff between the two, including
  new untracked files — without any `git add`, commit, stash or change to the real index.

**Per-task review and fix loop**

- [ ] AC9: One `ff-code-reviewer` (model `models.reviewer`) reviews each task from the brief and
  `diff.patch` **by path** (the diff is never pasted into a prompt), returning two verdicts —
  conformance (the task's `**Covers:**` ACs, its `Produces:` interfaces, Global Constraints, no change
  outside the task's files) and quality — with findings rated Critical or Important at or above
  `reviewThreshold`, written to `task-<N>/review.md`.
- [ ] AC10: If the review has findings, fix rounds 1 and 2 resume the same implementer with the
  findings; round 3 dispatches a fresh `ff-implementer` on `models.escalation` with the brief, the
  previous reports and the open findings. After each round the controller writes a new head
  fingerprint and fix diff, and one scoped re-review marks each finding `ADDRESSED` or
  `NOT ADDRESSED` and reports only new breakage in the fix diff. There are never more than 3 fix rounds
  per task; each round is a ledger line.
- [ ] AC11: After the last allowed round, any open Critical finding **stops** the phase (both modes)
  naming the task and findings. If only Important findings remain open, the controller records one
  ruling per finding in the ledger — `Ruling: <decision> — <why> — <cost if wrong>` — marks the task
  complete, and continues.
- [ ] AC12: With `toggles.tdd` on, each code task's report gives the RED run (test command, non-zero
  exit, failing assertion) captured before the implementation and the GREEN run (exit 0) after, and
  the ledger records both; a task with no testable contract records `TDD: exempt — <reason>`. A code
  task with neither is a Critical conformance finding.
- [ ] AC13: On an escalated full-tier bugfix, the RED regression-test task's RED run is recorded in
  `manifest.bugfix.red` before any fix task is dispatched, and the GREEN run after the final fix task
  in `manifest.bugfix.green` — the RED-before-fix order is preserved under the controller.

**Resume, hand-off and review**

- [ ] AC14: Re-entering `ff-implement` (new session, after compaction, or via `/feature-flow:ff-resume`)
  with a ledger for the same plan skips tasks the ledger marks complete and resumes at the first
  incomplete task, at the next fix round if one was in progress; the SessionStart compaction re-anchor
  and `ff-status` name the ledger and the current task.
- [ ] AC15: When the controller finishes, the phase summary lists every ruling, and `ff-review` gives
  its reviewers the ledger's rulings as context and hands them the change as a diff **file** rather
  than pasted `git diff` output; `ff-review` is otherwise unchanged.

**Roles, config, parity, contract**

- [ ] AC16: `agents/ff-implementer.md` defines the implementer: tools include `Write`, `Edit`, `Bash`;
  it implements only its brief, may not spawn subagents, may not run `git add`/`commit`/`stash`/`reset`
  or otherwise change the index or history, and writes under the run dir only its own `report.md`. The
  task-review brief forbids the reviewer from spawning subagents.
- [ ] AC17: `config/defaults.json` has `models.implementer` (default `sonnet`) and `models.escalation`
  (default `opus`); both are in the Known-keys list, and an invalid value warns and falls back per
  §Config resolution & validation.
- [ ] AC18: The procedure is stated in prose in `ff-implement` and the contract so Codex follows it:
  `codex-tools.md` maps the implementer role and says that without multi-agent tooling the same loop
  runs inline with the same files and role boundaries; the fingerprint uses the verbatim recipe.
- [ ] AC19: The contract documents the ledger format, status contract, fix loop, rulings and the
  three new stops (plan placeholder, task blocked, Critical after cap) — each a row in
  `docs/schema/autopilot.md`'s mandatory-pause table with its correct shape (the Critical-after-cap
  stop is capped-then-stop, never "unconditional") — and every `**Name**` reference resolves (L4).
- [ ] AC20: A new structural guard pins AC1–AC19's wiring; every existing guard and `scripts/eval.sh`
  exit 0 (apart from the Go-only conformance guard where Go is absent); version is 0.23.0 across the
  synced manifests, README badge and CHANGELOG head; `dist/codex` is repackaged.

## End-to-end check

- [ ] E2E: run the controller forward test (`scripts/forward-test.sh implement-controller`) on a
  scratch repo with a signed full-tier spec and a 3-task executable plan whose task 2 is seeded to
  draw a review finding → the run ends with implement complete, the planned code and tests present and
  passing, `tasks/ledger.md` showing 3 complete tasks each with base/head fingerprints, a
  `diff.patch`, a `review.md`, RED→GREEN lines, and at least one fix round on task 2; no commits made.

## Success metrics

- [ ] SM1: On the forward-test plan, the controller session's own context (main-session input tokens,
  excluding subagents) is ≤ 60% of the inline implement session's on the same plan, measured by
  `run.json` usage of the fired (controller) vs control (inline) arm.

## Requirement graph

| AC | Depends on |
|----|------------|
| AC2 | AC1 |
| AC4 | AC3 |
| AC6 | AC5 |
| AC8 | AC6 |
| AC9 | AC8 |
| AC10 | AC9 |
| AC11 | AC10 |
| AC12 | AC6 |
| AC13 | AC12 |
| AC14 | AC5 |
| AC15 | AC11 |

## Sign-off

**User signed off:** yes (2026-09-24)

Assumptions 2 and 3 acknowledged by user as staying open (2026-09-24) — carried to the plan as `**Validates:**` tasks.

AC1 amended by user (2026-09-24) after Assumption 3's validation: full test code and interfaces in every plan; implementation code only where short or subtle (full code everywhere made a task ~10× longer).

> A spec without sign-off does not proceed to **design, planning, or implementation** —
> `/feature-flow:ff-design`, `/feature-flow:ff-plan`, and `/feature-flow:ff-implement` each stop and
> route back to `/feature-flow:ff-clarify` if this reads `no` (implement is the hard backstop). A
> waived review is recorded explicitly: "sign-off waived by user (date)" — never assumed.
