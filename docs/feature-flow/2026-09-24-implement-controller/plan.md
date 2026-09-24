# Plan: ff-implement as a per-task controller, with executable plans

**Goal:** On full-tier runs with an executable plan, `ff-implement` implements each task in a fresh subagent, reviews each task's diff, runs a capped escalating fix loop, and records it all in a resumable ledger.

## Outcome gate

**Spec:** `docs/feature-flow/2026-09-24-implement-controller/spec.md`
**Design:** `docs/feature-flow/2026-09-24-implement-controller/design.md`
**Acceptance criteria:** see spec §Acceptance criteria (AC1–AC20), plus E2E, SM1 and design FS1–FS4. Each task below maps
to specific ACs; the final task verifies all of them.
**User signed off:** yes (2026-09-24)

> No task executes while sign-off is "no". At completion, `/feature-flow:ff-verify` checks the
> result against the spec's acceptance criteria — not just the task list.
>
> Every spec AC maps to ≥1 task's `**Covers:**` line — AC1 T3, AC2 T3, AC3 T7, AC4 T7, AC5 T5,
> AC6 T8, AC7 T8, AC8 T8, AC9 T9, AC10 T9, AC11 T9, AC12 T8, AC13 T8, AC14 T10, AC15 T11,
> AC16 T6, AC17 T5, AC18 T6, AC19 T5, AC20 T12/T14; E2E and SM1 T13. No AC is uncovered.
>
> **Assumption validation (full tier).** Assumption 2 → Task 1 (`**Validates:** Assumption 2`);
> Assumption 3 → Task 4 (`**Validates:** Assumption 3`). Both acknowledged-open at sign-off.
>
> **Requirement-graph coverage.** Folded into the dependency graph: AC6→AC5, AC14→AC5 (T8 and T10
> depend on T5); AC9→AC8 (T9 depends on T8); AC15→AC11 (T11 depends on T9). Named gaps —
> `AC2 depends-on AC1: covered by the same Task 3`; `AC4 depends-on AC3: covered by the same Task 7`;
> `AC8 depends-on AC6: covered by the same Task 8`; `AC12 depends-on AC6: covered by the same Task 8`;
> `AC13 depends-on AC12: covered by the same Task 8`; `AC10 depends-on AC9: covered by the same Task 9`;
> `AC11 depends-on AC10: covered by the same Task 9`.

## Tasks

### Task 1: Validate Assumption 2 — a dispatched agent can be resumed with its context

**Files:**
- Read only (evidence under the run dir: `.feature-flow/implement-controller/evidence/`)

**Covers:** — (validation task)
**Validates:** Assumption 2

- [x] **Step 1:** Dispatch a throwaway general-purpose agent told a random token and asked only to
  acknowledge; then resume that same agent (`SendMessage` to its id) asking it to repeat the token
  without it being restated.
- [x] **Step 2: Verify** — the resumed agent returns the token; record the exchange (ids redacted) in
  `evidence/a2-resume.md`. If it cannot, record the failure and switch the design's rounds 1–2 to the
  fresh-dispatch-with-report fallback (a Decisions entry).

### Task 2: `hooks/lib/task.sh` — fence-aware `task_section` and `task_diff` (test-first)

**Files:**
- Create: `hooks/lib/task.sh`
- Create: `evals/fixtures/task-controller/` (plans with fenced heading-like lines, expected sections)
- Modify: `scripts/eval.sh` (run the fixture)

**Covers:** — (FS1; the lib Task 8 consumes for AC6 and AC8)

- [x] **Step 1:** Write fixtures first: a plan whose Task 2 step contains ```` ``` ````, `~~~` and
  4-backtick fences holding `### Task 3: fake` and `## Global Constraints` lines; expected outputs for
  `section '^### Task 2:'`, `section '^### Task 3:'`, `section '^## Global Constraints'`, a
  no-match case (exit 1, no output), and the last task in the file (runs to EOF / next `##`).
- [x] **Step 2:** Add the `scripts/eval.sh` check; run it — **RED** (no lib yet).
- [x] **Step 3:** Implement `task_section` (awk, fence char + length tracking, same-or-higher level
  terminates) and `task_diff` (40/64-hex validation, `--stat` then `-U10`, run at the git top level),
  functions only, CLI branch keyed on `BASH_SOURCE`, header naming §Task packaging.
- [x] **Step 4:** Add `task_diff` cases to the fixture runner in a temp git repo: two fingerprints
  around an edit + a new untracked file → the diff shows both; a non-hex id → exit non-zero, no output;
  the real index is byte-identical before and after.
- [x] **Step 5: Verify** — `bash scripts/eval.sh` exits 0 with the new fixture cases passing; the Step 2
  RED output is recorded in the Decisions log.

### Task 3: Executable plans — templates and `ff-plan`

**Files:**
- Modify: `templates/plan.md`, `templates/plan-bugfix.md`, `commands/ff-plan.md`

**Covers:** AC1, AC2

- [x] **Step 1:** Both templates: `## Global Constraints` (bullets + blockquote) between
  `## Outcome gate` and `## Tasks`; under `## Tasks` the `> **No Placeholders.**` blockquote listing
  the forbidden patterns and a digit-free `**Self-check ran:**` line; `**Interfaces:**` with
  `- Consumes:` / `- Produces:` in each example task; example steps showing a fenced code block and
  `**Run:**` / `**Expected:**`; `Step N: Verify`, `Verify RED`/`Verify GREEN`, the six-heading order,
  `| Task | Depends on |` and `**Validates:** Assumption N` untouched.
- [x] **Step 2:** `ff-plan.md`: author Global Constraints before decomposing (verbatim from spec
  Constraints + design binding decisions); author Interfaces and the step shape while decomposing
  (full tier, both tracks); before "Populate the Outcome gate", the No Placeholders self-check that
  fixes every hit and fills `**Self-check ran:**` — each referencing §Executable plans by name.
- [x] **Step 3: Verify** — `bash scripts/checks/planning-intelligence-guard.sh`,
  `discovery-fields-guard.sh`, `assumption-guard.sh`, `delivery-guard.sh` and
  `durable-paths-guard.sh` all exit 0 (dist parity after repackaging).

### Task 4: Validate Assumption 3 — executable plans stay authorable and briefs stay small

**Files:**
- Read only (evidence: `evidence/a3-plan-size.md`)

**Covers:** — (validation task)
**Validates:** Assumption 3

- [x] **Step 1:** Rewrite Tasks 2 and 4 of `docs/feature-flow/2026-09-24-revision-binding/plan.md` in
  the new format (Global Constraints, Interfaces, fenced code for the test and code steps, Run/Expected)
  as a scratch file; measure lines per task old vs new.
- [x] **Step 2:** Extract each rewritten task with `task_section` and measure the brief size (lines,
  bytes) including Global Constraints.
- [x] **Step 3: Verify** — record the numbers; the assumption holds if a brief is ≤ 400 lines and the
  per-task growth is ≤ 5×; otherwise record the lighter rule (code only for tests and interfaces) as a
  Decisions entry and apply it to Task 3's template text.

### Task 5: Contract topic, schema wiring, stop rows and config

**Files:**
- Create: `docs/schema/task-controller.md`
- Modify: `docs/manifest-schema.md`, `docs/schema/autopilot.md`, `config/defaults.json`,
  `scripts/checks/lib/schema.sh`, `scripts/checks/claude-dist-guard.sh`

**Covers:** AC5, AC17, AC19

- [x] **Step 1:** Write `docs/schema/task-controller.md` — `## Task controller` with `### Executable
  plans`, `### Controller activation`, `### Task packaging` (the `hooks/lib/task.sh` text verbatim in a
  fenced `bash` block + the Claude Code / Codex invocation lines), `### Ledger` (location, identity
  line, entry fields, two-write discipline, resume rule incl. "keep the recorded Base" (FS2),
  different-plan rule), `### Status contract`, `### Task review`, `### Fix loop` (incl. escalation
  fallback, FS4), `### Rulings` (incl. the user-authored acceptance line), `### Bugfix under the
  controller`, `### Inline fallback (Codex)`.
- [x] **Step 2:** `docs/manifest-schema.md`: Topic-index row; `"ledger": "tasks/ledger.md"` in the
  Schema block `artifacts`; field note; `ledger` in the ephemeral list; Known-keys gains
  `models.implementer`, `models.escalation`.
- [x] **Step 3:** `docs/schema/autopilot.md`: rows *Plan placeholder stop*, *Task blocked stop*,
  *Critical-after-cap stop* — none saying "unconditional" — and a short **Per-task fix loop** paragraph
  pointing at §Fix loop.
- [x] **Step 4:** `config/defaults.json`: `models.implementer: "sonnet"`, `models.escalation: "opus"`.
  `SCHEMA_LAYOUT` gains `Task controller|task-controller`; `want_schema` gains `task-controller.md`.
- [x] **Step 5: Verify** — `schema-layout-guard.sh` (incl. L4 reference integrity) and
  `claude-dist-guard.sh` exit 0 after rebuilding `dist/`; `jq . config/defaults.json` parses.

### Task 6: The implementer role and platform docs

**Files:**
- Create: `agents/ff-implementer.md`
- Modify: `skills/feature-flow/SKILL.md`, `skills/feature-flow/references/codex-tools.md`

**Covers:** AC16, AC18

- [x] **Step 1:** `agents/ff-implementer.md` — frontmatter (`tools: Glob, Grep, LS, Read, Write, Edit,
  Bash, TodoWrite`, `model: sonnet`), body: implement exactly the brief; test-first with RED/GREEN
  capture when told tdd is on; run the task's Verify step; the forbidden git operations; write under
  the run dir only its own `report.md`, never plan/spec/design; no subagents; report sections and the
  four statuses with a ≤ 15-line returned summary.
- [x] **Step 2:** `codex-tools.md`: `ff-implementer` row; "without multi-agent tooling the same loop
  runs inline, same files, same order, same role boundaries"; context benefit vs audit trail note.
  `SKILL.md`: `ff-implementer` named as the one editing agent; the implement bullet mentions the
  controller.
- [x] **Step 3: Verify** — `claude-dist-guard.sh` and `dist-parity-guard.sh` exit 0 after repackaging.

### Task 7: `ff-implement` — controller activation and No Placeholders pre-flight

**Files:**
- Modify: `commands/ff-implement.md`

**Covers:** AC3, AC4

- [x] **Step 1:** New `## Controller activation` after `## Critical-path check`: the two-condition
  test via `manifest.artifacts.plan`; otherwise the inline path with a one-line reason; the note that
  every earlier gate has already run.
- [x] **Step 2:** The pre-flight: check every task against §Executable plans' No Placeholders list
  before any dispatch; a hit → Plan placeholder stop naming the task and text, routing to
  `/feature-flow:ff-plan`.
- [x] **Step 3:** One sentence at the top of each existing `## Do the work` section: it is the inline
  path (lite tier, or a plan without `## Global Constraints`).
- [x] **Step 4: Verify** — `durable-paths-guard.sh`, `decision-record-guard.sh`,
  `planning-intelligence-guard.sh` exit 0 (no bare-name reads; existing STOP text intact).

### Task 8: `ff-implement` — per-task brief, dispatch, status, fingerprints, TDD, bugfix

**Files:**
- Modify: `commands/ff-implement.md`

**Covers:** AC6, AC7, AC8, AC12, AC13

- [x] **Step 1:** `## Controller loop` part 1: ledger resolve/create (write `artifacts.ledger` before
  the first dispatch), resume point, provisional entry + Base (keep a recorded Base on resume), drift
  line; brief via `task_section` (Claude Code: shipped lib; Codex: §Task packaging block).
- [x] **Step 2:** Dispatch `ff-implementer` (`models.implementer`) with brief and report paths and the
  tdd setting; record the agent id; the four-status handling incl. the NEEDS_CONTEXT cap of two and the
  Task blocked stop.
- [x] **Step 3:** Head fingerprint + `task_diff` → `diff.patch`; the non-git fallback (`files.txt`);
  TDD evidence rules (RED/GREEN, `TDD: exempt — <reason>`, `TDD: off (config)`); bugfix `Verify RED`
  → `manifest.bugfix.red` before the next dispatch, final GREEN → `manifest.bugfix.green`.
- [x] **Step 4: Verify** — re-read the section against §Controller loop in the design; every step
  references the contract by name (no restated lib text); `durable-paths-guard.sh` exits 0.

### Task 9: `ff-implement` — task review, fix loop, rulings, close

**Files:**
- Modify: `commands/ff-implement.md`

**Covers:** AC9, AC10, AC11

- [x] **Step 1:** Review dispatch: one `ff-code-reviewer` (`models.reviewer`) given paths only, the two
  verdicts, `reviewThreshold`, "do not spawn subagents"; the added Critical findings (failed Verify on
  DONE; missing TDD evidence).
- [x] **Step 2:** Fix loop: pending round line first; rounds 1–2 resume (fallback per Task 1's
  result); round 3 fresh on `models.escalation` with the fallback line; new Head, `fix-<R>.patch`,
  scoped re-review `rereview-<R>.md`; never more than 3.
- [x] **Step 3:** Close: clean → complete; after the cap Critical → Critical-after-cap stop,
  Important-only → `**Ruling:**` lines and complete; tick the plan checkbox; after the last task the
  summary lists rulings and drift, then the unchanged manifest update.
- [x] **Step 4: Verify** — `repair-loop-guard.sh` and `schema-layout-guard.sh` exit 0; the three stop
  names match the autopilot rows verbatim.

### Task 10: Task-level resume, status and re-anchor

**Files:**
- Modify: `commands/ff-resume.md`, `commands/ff-status.md`, `hooks/session-start`

**Covers:** AC14

- [x] **Step 1:** `ff-status`: when implement is in progress and `artifacts.ledger` resolves, print the
  ledger path and `Task N (round R)`. `ff-resume`: re-entering implement resumes from the ledger per
  §Ledger.
- [x] **Step 2:** `hooks/session-start`: in the compact re-anchor block, for a run in implement with
  `artifacts.ledger`, append the ledger path and current task (read with `awk`, fail-open).
- [x] **Step 3: Verify** — `session-start-guard.sh` exits 0 plus a new fixture case (a manifest with a
  ledger → the re-anchor output names it); `bash -n hooks/session-start`.

### Task 11: `ff-review` — diff as a file, rulings as context

**Files:**
- Modify: `commands/ff-review.md`

**Covers:** AC15

- [x] **Step 1:** Replace the paste instruction: write `<run dir>/review.diff` = `task_diff` of the
  HEAD tree against the current fingerprint (fallback `git diff HEAD > review.diff`; non-git: file
  list), and hand each reviewer the path.
- [x] **Step 2:** When `manifest.artifacts.ledger` resolves, give every reviewer the ledger's
  `**Ruling:**` lines as context (decisions already taken, to be judged, not re-litigated blindly).
- [x] **Step 3: Verify** — `spec-conformance-guard.sh`, `revision-binding-guard.sh`,
  `durable-paths-guard.sh` exit 0.

### Task 12: Structural guard

**Files:**
- Create: `scripts/checks/implement-controller-guard.sh`

**Covers:** AC20 (and pins AC1–AC19, FS2, FS4 wiring)

- [x] **Step 1:** Guard in the `repair-loop-guard.sh` shape: templates (AC1), `ff-plan` (AC2),
  activation + pre-flight placement before the loop (AC3/AC4), ledger contract + `artifacts.ledger`
  (AC5), brief/dispatch/status tokens (AC6/AC7), fingerprint + `diff.patch` + no-git-mutation text
  (AC8), review by path + two verdicts (AC9), round structure (AC10), stop/ruling grammar (AC11), TDD
  lines (AC12), bugfix anchors (AC13), resume/status/re-anchor (AC14), ff-review old paste phrase gone
  + diff file + rulings (AC15), implementer agent (AC16), config + Known keys (AC17), codex-tools
  (AC18), three autopilot rows without "unconditional" (AC19), FS2 "keep the recorded Base" and FS4
  fallback text; §Task packaging block byte-identical to `hooks/lib/task.sh` + one-character-drift
  self-test; dist parity for every touched file.
- [x] **Step 2:** Prove it RED: run it against a stash-free scratch copy with one pinned phrase removed
  from each of three files → three FAIL lines; restore → GREEN.
- [x] **Step 3: Verify** — `bash scripts/checks/implement-controller-guard.sh` exits 0.

### Task 13: Forward test — controller E2E and SM1 measurement

**Files:**
- Create: `evals/forward/implement-controller/{fired,control}/{prompt.txt,expected.md,assert.sh,sandbox/…}`,
  `evals/forward/implement-controller/sm1-ratio.sh`
- Modify: `evals/forward/README.md`, `scripts/checks/forward-test-guard.sh`

**Covers:** E2E, SM1

- [x] **Step 1:** Sandbox: a tiny project (bash or node, whichever the forward lib's other cases use),
  a manifest at implement (signed, full, `revisionBound`), spec, design, and a 3-task executable plan
  whose Task 2's Global Constraints make a naive implementation draw a review finding. Control arm:
  identical but the plan has no `## Global Constraints`.
- [x] **Step 2:** `assert.sh` (fired): ledger with 3 complete tasks, 40-hex Base/Head, per-task
  `diff.patch` + `review.md`, RED→GREEN lines, ≥ 1 fix round on Task 2, planned files present and their
  tests passing, commit count unchanged. (control): no `tasks/` dir, no `artifacts.ledger`, implement
  complete, commit count unchanged.
- [x] **Step 3:** `sm1-ratio.sh <fired run.json> <control run.json>` prints the main-session input-token
  ratio and PASS/FAIL at ≤ 0.60; README row + SM1 note; `BEHAVIORS` gains `implement-controller`.
- [x] **Step 4: Verify** — `forward-test-guard.sh` exits 0; `bash -n` on every new script. (The paid
  `scripts/forward-test.sh implement-controller` run happens in verify.)

### Task 14: Release 0.23.0 and full suite

**Files:**
- Modify: `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`, `.codex-plugin/plugin.json`,
  `README.md`, `CHANGELOG.md`; rebuild `dist/codex`

**Covers:** AC20

- [x] **Step 1:** Bump to 0.23.0; README badge + implement description; CHANGELOG `[0.23.0]` entry
  (what changed, measured numbers from Tasks 1/4, known limits: prose-enforced implementer boundaries,
  Claude-Code-only context benefit, higher total token cost).
- [x] **Step 2:** `bash scripts/package-codex-plugin.sh`.
- [x] **Step 3: Verify** — every `scripts/checks/*.sh` exits 0 except `integrity-conformance-guard.sh`
  (Go absent locally, pre-existing), and `bash scripts/eval.sh` exits 0.

## Dependency graph

| Task | Depends on |
|------|------------|
| Task 1 | — (root) |
| Task 2 | — (root) |
| Task 3 | — (root) |
| Task 4 | Task 2, Task 3 |
| Task 5 | Task 1, Task 2, Task 3 |
| Task 6 | Task 5 |
| Task 7 | Task 5 |
| Task 8 | Task 2, Task 5, Task 6, Task 7 |
| Task 9 | Task 8 |
| Task 10 | Task 5, Task 8 |
| Task 11 | Task 9 |
| Task 12 | Task 3, Task 5, Task 6, Task 7, Task 8, Task 9, Task 10, Task 11 |
| Task 13 | Task 4, Task 9, Task 10 |
| Task 14 | Task 12, Task 13 |

> One row per task in `## Tasks` above. `Depends on` names only **lower-numbered** `Task N`
> IDs already defined above (or "— (root)" for no prerequisite) — never a phantom or a
> higher-numbered task. Multiple roots are normal; this is dependency data, not an instruction
> to run tasks concurrently.

## Critical path

**Path:** Task 2 → Task 5 → Task 7 → Task 8 → Task 9 → Task 11 → Task 12 → Task 14

> **Derived — never hand-authored.** The longest dependency chain through the graph above (per
> `${CLAUDE_PLUGIN_ROOT}/docs/schema/planning-intelligence.md` §Planning intelligence → Critical-path
> derivation). Every task named here is non-skippable, in this order: `/feature-flow:ff-implement`
> STOPs if the approach skips or reorders one. No dependencies at all → "no gating chain — all
> tasks independent"; fully linear plan → the whole task sequence. Re-derive if the graph changes.

Derivation: chainLength T1–T3 = 1, T4 = T5 = 2, T6 = T7 = 3, T8 = 4, T9 = T10 = 5, T11 = T13 = 6,
T12 = 7, T14 = 8 (sink). Walk back: T14 → T12 (7 > 6) → T11 → T9 → T8 → {T6, T7} tie at 3 → T7
(4 steps > 3) → T5 → {T1, T2, T3} tie at 1 → T2 (5 steps, the most).

## Risk register

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|-----------|
| Template edits break a pinned string another guard checks | Med | Med | Task 3 runs every plan-pinning guard before moving on |
| The 14th topic misses one of the three wiring points | Med | Low | Task 5 Verify runs schema-layout + claude-dist guards |
| `task_section` mis-bounds on an unusual fence (FS1) | Low | High | Task 2 fixtures cover backtick, tilde and 4-backtick fences with heading-like content |
| Agent resume unavailable (Assumption 2) | Low | Low | Fresh-dispatch-with-report fallback written into the contract either way |
| Forward test is flaky or costly | Med | Med | Blind prompt + structural asserts only; SM1 measured by a separate helper, not asserted in the run |
| `ff-implement.md` grows past readability | Med | Low | The contract topic holds the rules; the command references them by name |

> Categorical only — **no numeric scores** (upholds the no-numeric-confidence doctrine).
> `/feature-flow:ff-verify` cross-references this register into its `## Regression risk`
> assessment instead of deriving risk cold. A risk accepted without mitigation says so.

## Rollback plan

| Task | Recovery action if `Step N: Verify` fails |
|------|--------------------------------------------|
| Task 2 | `git checkout -- scripts/eval.sh` and delete `hooks/lib/task.sh` + the fixture dir |
| Task 3 | `git checkout -- templates/plan.md templates/plan-bugfix.md commands/ff-plan.md` |
| Task 5 | `git checkout -- docs/manifest-schema.md docs/schema/autopilot.md config/defaults.json scripts/checks/lib/schema.sh scripts/checks/claude-dist-guard.sh`; delete `docs/schema/task-controller.md` |
| Task 10 | `git checkout -- hooks/session-start commands/ff-status.md commands/ff-resume.md` |
| Task 14 | `git checkout --` the version files; rebuild `dist/` |

> One row per task that risks a half-applied state. `/feature-flow:ff-implement` runs this
> recovery instead of leaving the tree half-applied when a Verify step fails. An irreversible
> step states "irreversible: mitigation is `<X>`" rather than a fake undo.

## Status conventions

Stateful document. After each task bump its status:
`[ ]` pending · `[~]` in progress · `[x]` done · `[!]` blocked · `[→]` deferred.
Keep a Status summary line current; append Blockers / Deviations / Decisions as needed.

**Status summary:** 14/14 tasks done; the paid forward-test run (E2E, SM1) is verify's.

## Blockers

(none yet)

## Decisions made during execution

- **Task 1 — Assumption 2 validated.** A completed subagent resumed via `SendMessage` returned a token
  it was given only in its first prompt (`evidence/a2-resume.md`). Rounds 1–2 resume the recorded
  implementer; the fresh-dispatch-with-report fallback stays for harnesses without resume.
- **Task 2 — test-first.** The `task-controller` eval fixture ran RED first (`evidence/t2-red.log`: lib
  missing, 7 FAIL lines), then GREEN on `hooks/lib/task.sh`. Mutation check: disabling fence tracking
  turns three section cases RED, so the fixture has teeth. The lib also runs piped through
  `bash -s --` (the Codex path).
- **Task 3 — no pinned text moved.** The plan-pinning guards (planning-intelligence, discovery-fields,
  assumption, delivery, durable-paths, evidence) all stayed green. Added one pattern the spec did not
  list: an unfilled `<…>` template placeholder.
- **Task 4 — Assumption 3: the growth bar failed for full code, user chose the lighter rule.** Full
  code made a task ~10.5× longer (23 → 242 lines); full test code + Interfaces with implementation
  steps naming the exact change is ~5.7× (130 lines), briefs ~140 lines (`evidence/a3-plan-size.md`).
  Measured on Task 2 only (the code-heaviest; Task 4 is a 33-line hook change and cannot move the
  conclusion). User decision (2026-09-24): "Tests + interfaces in full"; AC1 amended in the spec, templates and
  `ff-plan` updated to match.
- **Task 5 — deviation: `artifacts.ledger` holds the repo-relative path** (`<base>/<slug>/tasks/ledger.md`),
  not `tasks/ledger.md`. Found while wiring Task 10: sandbox artifacts are stored as bare names and
  durable ones as repo-relative paths, and the SessionStart re-anchor prints any value containing a
  `/` as repo-relative — `tasks/ledger.md` would have been shown at the wrong path. Schema example,
  field note, contract and `ff-implement` updated together.
- **Task 6 — codex-tools L4 fix.** A `§Revision fingerprint the same way` phrasing tripped the L4
  reference check; rephrased to `**Revision fingerprint** block in …enforcement.md`.
- **Task 10 — RED first.** The new session-start S11 case fails on the 0.22.0 hook
  (`evidence/t10-red.log`) and passes on the new one.
- **Task 12 — guard proven RED** in a scratch copy: removing "keep the recorded Base", marking the Task
  blocked row "unconditional", a one-character lib drift, and removing the agent's no-subagents line
  each produce FAIL lines (`evidence/t12-red.log`). 129 checks green on the real tree.
- **Task 13 — the fixture's seeded finding:** Task 2's plan code splits on spaces only; its plan tests
  pass, but spec AC2 requires tabs (checked: `a<TAB>b` → 1). The fired assert was proven to FAIL on an
  untouched sandbox and to PASS on a synthetic correct end state, so a paid run can't be wasted on an
  assert bug. Sessions dispatch subagents → README says run with `--max-budget-usd 8`.
- **Review-time fix (found by dogfooding Task 11): the whole-change diff needs a bookkeeping-free base.**
  Writing this run's own `review.diff` from the raw `HEAD^{tree}` to the fingerprint showed ~12,000
  lines of deletions — the committed `docs/feature-flow/` run records, which the fingerprint excludes.
  Added `revision_head_tree` to `hooks/lib/revision.sh` (HEAD's tree minus the same paths; CLI
  `revision.sh <dir> head`), regenerated the verbatim block in `enforcement.md`, pointed `ff-review`
  at it, and added two eval cases (head == fingerprint on a clean tree with committed bookkeeping; the
  diff shows code only). Deviation from the design's "revision.sh unchanged": the change is additive —
  `revision_fingerprint`, Gate B and their guards are untouched and green.
- **Verify — repair cycle (AC3).** Forward-test sample 1: the control arm implemented inline and gave the
  reason but wrote "directly", so the assert's marker check failed. Repair: a fixed
  `Implement path: controller|inline — <reason>` line, repeated in the final summary; both asserts
  check it. Sample 2: both arms PASS.
- **Verify — SM1 failed twice (1.46, 1.90) and was waived by the user** with the small-plan overhead
  recorded as a known limit in the CHANGELOG; a large-plan measurement and a possible size threshold
  are follow-ups.
- **Task 14 — suite:** every `scripts/checks/*.sh` exits 0 except `integrity-conformance-guard.sh`
  (Go absent locally, pre-existing); `scripts/eval.sh` exits 0. The 0.23.0 CHANGELOG entry restates
  the WP4 constraint, which `revision-binding-guard.sh` requires of the newest entry.
