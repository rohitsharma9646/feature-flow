# Design: ff-implement as a per-task controller, with executable plans

**Spec:** `docs/feature-flow/2026-09-24-implement-controller/spec.md`
**Created:** 2026-09-24

## Chosen approach

**Pragmatic + grafts** (user choice, 2026-09-24): one new contract topic owns the whole feature,
dispatch prompts are composed inline in the commands, `ff-code-reviewer` is reused unchanged, and
the two mechanics where drift or nondeterminism would be costly — pulling one section out of a plan
and packaging a diff between two tree ids — live in one small shared lib, reproduced byte-for-byte in
the contract for Codex (the house pattern from `hooks/lib/revision.sh`).

### 1. Contract home — `docs/schema/task-controller.md` (new topic)

`## Task controller` with these `###` subsections, referenced by name from `ff-plan`, `ff-implement`,
`ff-review`, `ff-status`, `ff-resume` and `autopilot.md` (never restated):

- `### Executable plans` — Global Constraints, per-task Interfaces, step shape (fenced code +
  `Run:` / `Expected:`), the No Placeholders list, and the self-check record.
- `### Controller activation` — full tier (feature, or escalated bugfix) **and** the plan has a
  `## Global Constraints` heading → controller; otherwise inline as in 0.22.0, with a one-line reason.
  Pre-flight No Placeholders check.
- `### Task packaging` — `hooks/lib/task.sh` reproduced verbatim in a fenced `bash` block.
- `### Ledger` — location, identity line, entry format, two-write discipline, resume rule.
- `### Status contract` — the four statuses, report file sections, `NEEDS_CONTEXT` cap.
- `### Task review` — two verdicts, the scoped re-review, what counts as a finding.
- `### Fix loop` — rounds 1–2 resume, round 3 escalated, cap, escalation fallback.
- `### Rulings` — Important-only rulings, the user-authored acceptance line after a Critical stop.
- `### Bugfix under the controller` — RED/GREEN into `manifest.bugfix.*`.
- `### Inline fallback (Codex)` — same files, same order, same role boundaries.

Wired into the three places a topic must be: the Topic index table in `docs/manifest-schema.md`,
`SCHEMA_LAYOUT` in `scripts/checks/lib/schema.sh`, and `want_schema` in `claude-dist-guard.sh`
(13 → 14 topic files).

### 2. `hooks/lib/task.sh` (new, Claude Code; verbatim block for Codex)

Functions only, no side effects, no `set -e`, CLI branch keyed on `BASH_SOURCE`:

- `task_section <file> <heading-regex>` — prints the section whose heading line matches the ERE,
  from that line up to (not including) the next heading of the **same or higher** level. Headings are
  recognized **only outside fenced code blocks**: a line opening with ≥3 backticks or tildes opens a
  fence that closes only on a line of the same character with at least the same length. Prints
  nothing and returns 1 when no heading matches.
- `task_diff <project-dir> <tree-a> <tree-b>` — validates both ids as 40/64 hex (same rule as
  `revision_changed_paths`), then prints `git diff --stat` followed by `git diff -U10` between the two
  trees, run at the git top level. Read-only plumbing: the tree objects already exist (written by
  `revision_fingerprint`); no index, ref or working-tree change. Non-zero on any failure.
- CLI: `bash task.sh section <file> <regex>` · `bash task.sh diff <dir> <a> <b>`.

Fingerprints are **not** duplicated: base/head come from the unchanged `hooks/lib/revision.sh`
(`revision_fingerprint`), and drift lists from `revision_changed_paths`. `revision.sh` and its
enforcement.md block stay byte-unchanged (revision-binding guard untouched).

### 3. Executable plans — template + ff-plan

`templates/plan.md` and `templates/plan-bugfix.md`, identical additions:

- `## Global Constraints` between `## Outcome gate` and `## Tasks`: bullets copied verbatim from the
  spec's `## Constraints` and the design's binding decisions; "no additional constraints" when empty;
  blockquote saying every brief carries it unedited.
- Under `## Tasks`, before `### Task 1`: a `> **No Placeholders.**` blockquote listing the forbidden
  patterns, and a `**Self-check ran:** <yes — 0 hits | yes — N hits fixed>` line.
- In each task block, after `**Covers:**` / `**Validates:**`: `**Interfaces:**` with `- Consumes:` and
  `- Produces:` lines (exact names/signatures, or `none`).
- Step shape: a step that writes code or a test carries a fenced block with the real code; a step that
  runs something carries `**Run:**` and `**Expected:**`; `Step N: Verify` keeps its label (the Rollback
  plan and bugfix RED/GREEN anchors depend on it). The digit-free placeholder style is kept.

Pinned text untouched: the six-heading order, `| Task | Depends on |`, `**Validates:** Assumption N`,
`Verify RED` / `Verify GREEN` labels in `plan-bugfix.md`.

`commands/ff-plan.md`: author Global Constraints before decomposing; author Interfaces + step shape
while decomposing; before completing, run the No Placeholders self-check and record it.

### 4. The controller — `commands/ff-implement.md`

Two new sections between `## Critical-path check` and `## Do the work — feature track`:
`## Controller activation` (mode test + pre-flight) and `## Controller loop`. The two existing
`## Do the work` sections become the inline path, text unchanged apart from one sentence stating when
they apply. All existing gates still run first.

Per task, in plan order, from the resume point:

1. **Ledger entry, provisional.** `**Status:** in-progress`; `**Base:**` = fingerprint now — or, if
   the entry already has a Base (resume of an unfinished task), **keep the recorded Base** (FS2).
   If Base ≠ previous task's Head → one `**Drift:**` line (`revision_changed_paths`). Ledger written
   before the dispatch.
2. **Brief.** `tasks/task-<N>/brief.md` = `task_section <plan> '^## Global Constraints'` +
   `task_section <plan> '^### Task <N>:'` + the spec and design paths + (rounds, below) the findings.
   Never the whole plan.
3. **Dispatch** one `ff-implementer`, model `models.implementer`, given the brief path and
   `tasks/task-<N>/report.md`. Record the agent id in the ledger (needed for resume rounds).
4. **Status.** `DONE` → 5. `DONE_WITH_CONCERNS` → concerns become review items → 5. `NEEDS_CONTEXT`
   → controller answers from spec/design/plan into the brief's `## Added context`, re-dispatch (max 2),
   third → `BLOCKED`. `BLOCKED` → **Task blocked stop**.
5. **Head + diff.** `**Head:**` = fingerprint; `task_diff … > tasks/task-<N>/diff.patch`.
6. **Review.** One `ff-code-reviewer`, model `models.reviewer`, given paths only (brief, report,
   diff), `reviewThreshold`, the two-verdict instruction and "do not spawn subagents"; writes
   `tasks/task-<N>/review.md`. A `DONE` whose report shows its `Verify` step failing, or a code task
   with no RED/GREEN and no exemption (tdd on), is added as a Critical conformance finding.
7. **Fix loop** (findings ≥ threshold). Round R: ledger line `**Fix round R/3:** dispatched … —
   pending` first; rounds 1–2 resume the recorded implementer (`SendMessage` to its id) with the open
   findings — if resume is unavailable, a fresh dispatch given brief + previous report + findings
   (Assumption 2); round 3 a fresh `ff-implementer` on `models.escalation` — if that model cannot be
   dispatched, `models.implementer` with `escalation unavailable — used <m>` in the line (FS4). Then new
   Head, `tasks/task-<N>/fix-<R>.patch` (previous Head → new Head), one scoped re-review
   (`tasks/task-<N>/rereview-<R>.md`: each finding `ADDRESSED | NOT ADDRESSED`, new breakage in the
   fix diff only), and the round line is rewritten with its outcome. Never more than 3.
8. **Close.** Clean → `complete (clean)`. After round 3: open Critical → **Critical-after-cap stop**
   (`**Status:** stopped — Critical after cap`); Important-only → one `**Ruling:**` per finding,
   `complete (<n> rulings)`. The controller ticks the task's plan checkbox (the plan is a bookkeeping
   path, outside the fingerprint).
9. **Bugfix (escalated full).** The `Verify RED` task's RED run → `manifest.bugfix.red` before the next
   task is dispatched; after the final task, its GREEN run → `manifest.bugfix.green`.

After the last task: phase summary lists every ruling (and drift), then the unchanged `## Update
manifest` (implement complete, artifact null) and hand-off.

**Stops** (rows in `autopilot.md`'s mandatory-pause table; none says "unconditional"):
- *Plan placeholder stop* — passive shape: resolved by fixing the plan (`/feature-flow:ff-plan`).
- *Task blocked stop* — capped-then-stop (after ≤ 2 context re-dispatches): resolved by the user
  supplying the missing context/decision, then re-running `ff-implement` (resumes the task).
- *Critical-after-cap stop* — capped-then-stop (after 3 rounds): resolved by the user fixing the code
  and re-running (the task gets one fresh review of Base → current, no further rounds), or by a
  user-authored `Task <N> finding accepted by user (<date>): <reason>` line in the ledger — never
  assistant-authored.

**Non-git project** (`toggles.greenfield`, or fingerprint unavailable): Base/Head `not recorded —
<reason>`; `diff.patch` is replaced by `files.txt` (the implementer's reported changed files) and the
reviewer reads those files — mirrors `ff-review`'s existing greenfield fallback.

### 5. Ledger — `<run dir>/tasks/ledger.md` (ephemeral, sandbox only)

```markdown
# Ledger — plan: docs/feature-flow/2026-09-24-example/plan.md

## Task 2: Wire the limiter into the auth route
**Status:** complete (1 ruling)
**Base:** 8b1d4e7c2a9f0b6d3e1c8a5b9f2d0c7e4a1b6d9f
**Head:** d1f0b8e3a6c9d2f7b0e4a1c8d5f2b9e6a3c0d7f1
**Implementer:** DONE_WITH_CONCERNS — sonnet — agent a1b2c3 — tasks/task-2/report.md
**Review:** tasks/task-2/review.md — conformance: 1 Critical; quality: 1 Important
**Fix round 1/3:** resumed a1b2c3 (sonnet) — 8b1d4e7..d1f0b8e — tasks/task-2/rereview-1.md — 1 ADDRESSED, 1 NOT ADDRESSED, 0 new
**Fix round 2/3:** resumed a1b2c3 (sonnet) — d1f0b8e..d1f0b8e — tasks/task-2/rereview-2.md — 0 ADDRESSED, 1 NOT ADDRESSED, 0 new
**Fix round 3/3:** fresh (opus) — …
**TDD:** RED `npm test -- auth.spec.js` exit 1 (expected 429, got 200) → GREEN `npm test -- auth.spec.js` exit 0
**Ruling:** keep the limit constant inline — the design fixes it at 100 and no other task reads it — cost if wrong: one extraction later
```

Resume rule: first `## Task N` whose Status is not `complete (…)`; `blocked` / `stopped` entries are
re-entered at the user's direction. A round line ending `— pending` is an unfinished round → redo that
round from its recorded base; a finished round → next round number. A ledger whose identity line
names a different plan than `manifest.artifacts.plan` is left untouched and a new ledger is started
(`tasks/ledger-<n>.md`), noted in the summary. `manifest.artifacts.ledger` is written when the ledger
is created — before the first dispatch — so a mid-run resume can find it.

### 6. Roles

- `agents/ff-implementer.md` (new): `tools: Glob, Grep, LS, Read, Write, Edit, Bash, TodoWrite` (no
  agent-dispatch tool). Contract: implement exactly the brief; test-first when `toggles.tdd` is on
  (capture RED before implementing, GREEN after); run the task's Verify step; never `git add`,
  `commit`, `stash`, `reset`, `checkout --`, or anything that changes the index or history; never edit
  files under the run dir except its own `report.md`, and never the plan/spec/design; report sections
  `Status` / `Summary` (≤ 15 lines, also returned) / `Files changed` / `TDD` / `Verify` / `Concerns` /
  `Needed context`.
- `agents/ff-code-reviewer.md`: unchanged — the two-verdict task review is a dispatch-prompt shape, as
  `ff-review`'s spec-conformance dispatch already is.

### 7. Other touchpoints

- `commands/ff-review.md`: the diff hand-off becomes a **file**: `<run dir>/review.diff` =
  `task_diff <proj> <HEAD tree> <current fingerprint>` (includes new untracked files, which today's
  `git diff HEAD` misses; excludes bookkeeping); fallback `git diff HEAD > review.diff`; non-git → file
  list as today. Reviewers get the path, plus the ledger's `**Ruling:**` lines (via
  `manifest.artifacts.ledger`) as context. Otherwise unchanged.
- `commands/ff-status.md`, `commands/ff-resume.md`, `hooks/session-start`: name the ledger and the
  current task (`Task N (round R)`) when `artifacts.ledger` resolves and implement is in progress.
- `docs/manifest-schema.md`: `artifacts.ledger` in the Schema block + Field notes; ledger added to the
  ephemeral list; Known-keys `models.implementer`, `models.escalation`; Topic-index row.
- `docs/schema/autopilot.md`: three mandatory-pause rows + one paragraph pointing at §Fix loop.
- `config/defaults.json`: `models.implementer: "sonnet"`, `models.escalation: "opus"`.
- `skills/feature-flow/references/codex-tools.md`: `ff-implementer` row; inline fallback sentence;
  "the context benefit needs multi-agent tooling; the ledger/diff/review audit trail does not".
- `skills/feature-flow/SKILL.md`: `ff-implementer` named as the one editing agent.
- `scripts/checks/implement-controller-guard.sh` (new); `evals/forward/implement-controller/`
  (fired/control) + `sm1-ratio.sh`; `forward-test-guard.sh` `BEHAVIORS`; `scripts/eval.sh` fixture
  for FS1.
- 0.23.0 version sync, README, CHANGELOG, `dist/codex`.

## Rejected alternatives

| Alternative | Why rejected |
|-------------|--------------|
| Minimal (no topic, no lib; contract in planning-intelligence + autopilot; controller copies briefs by hand) | Contract scattered across two unrelated topics; LLM-copied briefs are nondeterministic and mis-bound on plans that now routinely contain fenced code (FS1's trigger); it also mislabelled the placeholder stop "unconditional" |
| Pragmatic as proposed (one-line `task-diff.sh`, hand-copied briefs) | A byte-pinned lib that wraps a single `git diff` is ceremony, while the step that actually needs determinism — section extraction — was left to the model |
| Clean (topic + `task.sh` + 4 pinned prompt/ledger templates) | Four extra templates double the guard and dist-parity surface for wording nobody else consumes; the house composes dispatch prompts inline (`ff-review`, `ff-design`) |

## Trade-off matrix

| Option | Complexity | Risk / operational impact | Test effort | Brief determinism |
|--------|------------|----------------------------|--------------|-------------------|
| Pragmatic + grafts (chosen) | med | low | med | high |
| Pragmatic as proposed | med | med | med | low |
| Minimal | low | med | low | low |
| Clean | high | low | high | high |

> Brief determinism differentiates the options (whether the implementer provably sees exactly its own
> task); the core three columns alone would not separate Pragmatic+grafts from Clean.

## Component map

| File / module | Responsibility | New or modified |
|---------------|----------------|-----------------|
| `docs/schema/task-controller.md` | Canonical contract (plans, activation, packaging, ledger, statuses, review, fix loop, rulings, bugfix, Codex) | new |
| `hooks/lib/task.sh` | `task_section`, `task_diff` | new |
| `agents/ff-implementer.md` | Editing implementer role | new |
| `commands/ff-implement.md` | Controller activation + loop; inline path kept | modified |
| `commands/ff-plan.md` | Author new plan fields; No Placeholders self-check | modified |
| `templates/plan.md`, `templates/plan-bugfix.md` | Global Constraints, No Placeholders, Interfaces, step shape | modified |
| `commands/ff-review.md` | Diff as a file; rulings as reviewer context | modified |
| `commands/ff-status.md`, `commands/ff-resume.md`, `hooks/session-start` | Task-level status / resume / re-anchor | modified |
| `docs/manifest-schema.md` | `artifacts.ledger`, ephemeral list, Known keys, Topic index | modified |
| `docs/schema/autopilot.md` | Three stop rows + fix-loop pointer | modified |
| `config/defaults.json` | `models.implementer`, `models.escalation` | modified |
| `skills/feature-flow/SKILL.md`, `references/codex-tools.md` | Editing role; inline fallback | modified |
| `scripts/checks/lib/schema.sh`, `scripts/checks/claude-dist-guard.sh` | Wire the 14th topic | modified |
| `scripts/checks/implement-controller-guard.sh` | Structural guard incl. byte identity + drift self-test | new |
| `scripts/eval.sh` + `evals/fixtures/` | FS1 fence-aware extraction fixture | modified / new |
| `evals/forward/implement-controller/` + `forward-test-guard.sh` | E2E fired/control + SM1 ratio helper | new / modified |
| version files, README, CHANGELOG, `dist/codex` | 0.23.0 | modified |

## Data flow

`plan.md` (via `artifacts.plan`) → activation test → pre-flight → per task: `task_section` → `brief.md`
→ `revision_fingerprint` (Base) → `ff-implementer` → `report.md` + code in the working tree →
`revision_fingerprint` (Head) → `task_diff` → `diff.patch` → `ff-code-reviewer` → `review.md` → [fix
rounds → `fix-R.patch`, `rereview-R.md`] → `ledger.md` (after every step) → next task → phase summary
(rulings) → `ff-review` (reads `review.diff` + ledger rulings) → `ff-verify`.

## Risks

- **Prose-enforced implementer boundaries.** Nothing mechanically stops `ff-implementer` from running
  `git commit` via `Bash`; the contract forbids it and the per-task reviewer's scope check catches
  out-of-scope edits one step later. Accepted — same trust level as `ff-test-runner`'s evidence-only
  writes. (A PreToolUse deny for git mutations from subagents is a possible follow-up.)
- **Total cost rises while main-context cost falls.** A reviewer per task plus fix rounds costs more
  tokens overall than one inline session on small plans; SM1 bounds only the controller's own context.
  Accepted by the chosen approach; stated in the CHANGELOG.
- **Context benefit is Claude-Code-only.** Codex without multi-agent tooling gets the audit trail
  (ledger, diffs, reviews, RED→GREEN) but not the fresh contexts. Stated in `codex-tools.md`.
- **Longer plans.** Real code per step makes plans several times longer (Assumption 3, carried to a
  `**Validates:**` task); the self-check catches missing detail, not wrong detail — the per-task
  reviewer is the backstop.
- **Three-way topic plumbing.** Missing one of Topic index / `SCHEMA_LAYOUT` / `want_schema` fails CI
  loudly (existing guards).

## Devil's advocate

> Stress-test the **chosen** option only (not the rejected ones — this is not a re-litigation of
> the pick). **At least one failure scenario is required**, even for a design with a single obvious
> option. See `docs/schema/design-tradeoffs.md` §Design trade-offs & devil's advocate.

### Failure scenarios

- **FS1:** A plan step's fenced code block contains a heading-shaped line (a task that edits a
  markdown template containing `### Task 3: …` or `## Global Constraints`, inside a ```` ``` ```` or
  `~~~` or 4-backtick fence) → `task_section` ends Task 2's brief early or starts Task 3's brief in the
  wrong place → the implementer builds a truncated or merged task and the reviewer checks it against
  the wrong brief.
- **FS2:** The session compacts or drops after the implementer has edited files but before the ledger
  records Head → on re-entry the controller recomputes Base from the now-modified tree → the task's
  diff omits the first attempt's edits and the reviewer approves a partial diff.
- **FS3:** The implementer's test or build run leaves untracked, non-ignored files (caches, coverage,
  build output) → they land in the fingerprint and in `diff.patch` → the reviewer reports out-of-scope
  changes and fix rounds are spent on files nobody wrote (or they leak into `ff-review` as "the change").
- **FS4:** `models.escalation` (default `opus`) cannot be dispatched in the user's harness or account →
  round 3 fails → the controller stalls, or silently skips the escalated round and applies the cap as
  if it had run.

### Edge cases & operational risk

- A task whose plan checkbox is already `[x]` but has no ledger entry (a plan partly implemented inline
  before an upgrade): the ledger decides; the controller notes the mismatch and implements the task.
- The user edits code between tasks: recorded as `**Drift:**`, next Base = current tree.
- Non-git or greenfield projects: no fingerprints; review from the implementer's file list.
- `toggles.worktree: true`: the controller runs inside the worktree exactly as the inline path does;
  fingerprints are computed in that worktree.
- Migration: plans written before 0.23.0 have no `## Global Constraints` and run inline — no migration.
