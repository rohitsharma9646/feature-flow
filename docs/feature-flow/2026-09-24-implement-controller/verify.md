# Verify: ff-implement as a per-task controller, with executable plans (v0.23.0)

**Track:** feature
**Tier:** full
**Date:** 2026-09-24
**Revision:** 06e0871b6e42469c6e11b32901ffdbca2ee8386b
**Verified by:** `ff-test-runner` (executed) — evidence below is real command output.

## Commands run

| Command | Kind | Status | Evidence |
|---------|------|--------|----------|
| `bash scripts/checks/<guard>.sh` × 27 | executed-test | 26 pass, 1 fail (environment) | exit 0 for 26; `integrity-conformance-guard.sh` exit 1 — `FAIL: Go toolchain is required for WP1 conformance`; `command -v go` exit 1 (`evidence/executed-test-01…29`) |
| `bash scripts/eval.sh` | executed-test | pass | exit 0 — `PASS: task-controller (task_section fences, task_diff) …` (`evidence/executed-test-29-eval-sh.txt`) |
| 7 CLI probes in scratch git repos (`hooks/lib/task.sh`, `hooks/lib/revision.sh`, `hooks/session-start`, `jq`) | cli-output | pass | all exit as expected (`evidence/cli-output-01…07`) |
| `scripts/forward-test.sh --max-budget-usd 8 --timeout 2400 … implement-controller` (sample 1) | e2e (headless session) | fired pass, control fail | `PASS implement-controller/fired ($1.3725)`, `FAIL implement-controller/control ($0.381) — assertion failed` (`evidence/e2e-07-runner-console.txt`) |
| `sm1-ratio.sh` (sample 1) | cli-output | fail | exit 1 — `SM1 fired=480489 control=329253 ratio=1.459 FAIL (<= 0.60)` (`evidence/e2e-01-sm1-ratio.txt`) |
| repair re-verify: `implement-controller`, `forward-test`, `schema-layout` guards | executed-test | pass | exit 0 × 3 (`evidence/repair-executed-test-01…03`) |
| repair re-verify: `scripts/forward-test.sh … implement-controller` (sample 2) | e2e (headless session) | pass | exit 0 — fired PASS ($1.3956), control PASS ($0.3464), total $1.742 (`evidence/repair-e2e-01-runner-console.txt`) |
| repair re-verify: `sm1-ratio.sh` (sample 2) | cli-output | fail | exit 1 — `SM1 fired=488162 control=257102 ratio=1.899 FAIL (<= 0.60)` (`evidence/repair-e2e-07-sm1-ratio.txt`) |

## Evidence coverage matrix

| Detected surface | Expected kind | Ran? | Result | Notes (gap / N/A reason) |
|------------------|---------------|------|--------|--------------------------|
| `scripts/checks/*.sh` (27 guards) | executed-test | yes | pass (26) / env-fail (1) | Go absent locally → `integrity-conformance-guard.sh` cannot run (pre-existing; CI has Go) |
| `scripts/eval.sh` fixtures | executed-test | yes | pass | includes the new `task-controller` fixture |
| shell libs + hook (`task.sh`, `revision.sh`, `session-start`) | cli-output | yes | pass | scratch git repos, real index checksums |
| forward test (headless `claude -p` sessions) | e2e | yes (2 samples) | pass (sample 2) | sample 1 control arm failed → repair below |
| HTTP / DB / browser / logs | — | — | N/A | not detected: a markdown + bash plugin, no server, DB or UI |

## Contract mapping

### AC1: `templates/plan.md` and `templates/plan-bugfix.md` define a `## Global Constraints` section before `## Tasks`, a per-task `**Interfaces:**` block, complete test code in test steps, implementation steps that name the exact change, `Run:`/`Expected:` lines, and a No Placeholders rule — with all pinned template text unchanged (as amended 2026-09-24)
- **Method:** executed-test
- **Evidence:** `bash scripts/checks/implement-controller-guard.sh` — exit 0 — `AC1: … ## Global Constraints (…) before ## Tasks`, every No Placeholders pattern, Interfaces, Run/Expected; `planning-intelligence-guard.sh`, `discovery-fields-guard.sh`, `assumption-guard.sh` exit 0 (pinned text intact) — `evidence/executed-test-13…`, `-19…`, `-06…`, `-01…`
- **Confidence:** Verified (single-source)

### AC2: `ff-plan` authors those fields on full-tier plans and self-checks against No Placeholders before completing; the plan records that the check ran
- **Method:** executed-test
- **Evidence:** implement-controller guard — exit 0 — `AC2: the self-check (…) runs before the Outcome gate` (`evidence/executed-test-13…`)
- **Confidence:** Verified (single-source)

### AC3: `ff-implement` uses the controller when full tier and the plan has `## Global Constraints`; otherwise implements inline and says which path and why; existing gates run first
- **Method:** executed-test + e2e
- **Evidence:**
  - implement-controller guard — exit 0 — section order and the two `Implement path:` forms (`evidence/repair-executed-test-01…`)
  - forward test sample 2 — control PASS: `no artifacts.ledger`, `no tasks/ directory`, `final message states 'Implement path: inline'`; fired PASS: `final message states 'Implement path: controller'` (`evidence/repair-e2e-03…`, `repair-e2e-04…`, `repair-e2e-06…`)
- **Confidence:** Verified (multi-source) — after the repair below

### AC4: before the first dispatch, any No Placeholders hit stops the phase naming task and text, routing to `ff-plan`
- **Method:** executed-test (wiring only)
- **Evidence:** implement-controller guard — exit 0 — `AC3/AC4: activation has '**Plan placeholder stop**'`, `'no task is dispatched'` (`evidence/executed-test-13…`)
- **Confidence:** Partially verified
- **Gap:** the stop firing on a real plan with a placeholder was not exercised (the forward-test plan has none). Needs a forward-test arm with a seeded placeholder.

### AC5: ledger at `<run dir>/tasks/ledger.md` via `manifest.artifacts.ledger`, identity line, per-task entries, rewritten before each dispatch
- **Method:** executed-test + e2e
- **Evidence:** guard AC5 checks (`evidence/executed-test-13…`); fired arm — `ok: ledger via artifacts.ledger`, `ok: ledger identity line`, three `Task N complete` entries with fingerprints (`evidence/e2e-03…`, `repair-e2e-03…`)
- **Confidence:** Verified (multi-source)

### AC6: per task, a brief holding only that task + Global Constraints + Interfaces + spec/design paths; one fresh `ff-implementer` on `models.implementer`
- **Method:** executed-test + e2e
- **Evidence:** guard AC6 checks; fired arm — `ok: task-N/brief.md holds only its own task` × 3 in both samples
- **Confidence:** Verified (multi-source)

### AC7: exactly one status + ≤ 15-line summary + report file; NEEDS_CONTEXT ≤ 2 re-dispatches then BLOCKED; BLOCKED stops; DONE_WITH_CONCERNS → review items
- **Method:** executed-test + e2e (DONE path only)
- **Evidence:** guard — all four statuses, `at most twice per task`, `**Task blocked stop**`; fired arm — every task reached DONE with a report and was reviewed (`evidence/e2e-08-fired-result-text.txt`)
- **Confidence:** Partially verified
- **Gap:** `NEEDS_CONTEXT`, `BLOCKED` and `DONE_WITH_CONCERNS` handling were not exercised live.

### AC8: base/head fingerprints and `task-<N>/diff.patch` including untracked files, with no `git add`/commit/stash or index change
- **Method:** executed-test + cli-output + e2e
- **Evidence:** `evidence/cli-output-02-ac8-fingerprint-diff.txt` (tracked edit + untracked file in the diff; `rev-list --count` 1 → 1; `.git/index` md5 identical); eval fixture (index byte-identical); fired arm — 40-hex Base/Head and `diff.patch` for all 3 tasks, `ok: no commit made`
- **Confidence:** Verified (multi-source)

### AC9: one `ff-code-reviewer` per task, paths only, two verdicts, findings ≥ threshold, `task-<N>/review.md`
- **Method:** executed-test + e2e
- **Evidence:** guard AC9 checks; fired arm — `task-N/review.md` × 3; the Task 2 review flagged the seeded tab defect as Critical (conformance to AC2) (`evidence/e2e-08…`)
- **Confidence:** Verified (multi-source)

### AC10: fix rounds 1–2 resume the implementer, round 3 fresh on `models.escalation`; new head, fix diff, scoped re-review; ≤ 3 rounds
- **Method:** executed-test + e2e (round 1 only)
- **Evidence:** guard AC10 checks; fired arm — `ok: Task 2 had a fix round`, re-review confirmed the fix, `words.sh counts a<TAB>b as 2` (both samples)
- **Confidence:** Partially verified
- **Gap:** rounds 2–3, the escalation to `models.escalation`, and the 3-round cap were not reached live (the seeded finding was fixed in round 1).

### AC11: after round 3, open Critical → stop; Important-only → one ruling per finding, task complete
- **Method:** executed-test (wiring only)
- **Evidence:** guard — `**Critical-after-cap stop**`, the `**Ruling:**` grammar (`evidence/executed-test-13…`)
- **Confidence:** Partially verified
- **Gap:** no task reached the cap, so neither the stop nor a ruling was exercised.

### AC12: with tdd on, each code task's RED before and GREEN after, recorded in the ledger; exemption / off lines
- **Method:** executed-test + e2e
- **Evidence:** guard AC12; fired arm — `ok: Task N RED→GREEN` × 3 in both samples
- **Confidence:** Verified (multi-source)

### AC13: escalated full bugfix — RED into `manifest.bugfix.red` before any fix task; GREEN after the final task
- **Method:** executed-test (wiring only)
- **Evidence:** guard — `manifest.bugfix.red`, `manifest.bugfix.green`, `Verify RED`/`Verify GREEN` anchors kept (`evidence/executed-test-13…`)
- **Confidence:** Partially verified
- **Gap:** no escalated-bugfix run under the controller was exercised.

### AC14: re-entry resumes at the first incomplete task / next fix round; SessionStart re-anchor and `ff-status` name the ledger and current task
- **Method:** executed-test + cli-output
- **Evidence:** `evidence/cli-output-06-ac14-session-start.txt` (`task: Task 2 (round 2)`); `session-start-guard.sh` S11 exit 0, proven RED on the 0.22.0 hook (`evidence/t10-red.log`); guard AC14 checks for `ff-resume`/`ff-status`
- **Confidence:** Verified (multi-source)

### AC15: phase summary lists rulings; `ff-review` passes rulings and hands reviewers the change as a diff file
- **Method:** executed-test + cli-output
- **Evidence:** guard AC15 checks (paste instruction gone, `review.diff`, rulings, `revision.sh … head`); `evidence/cli-output-05-ac15-durable-paths.txt` (head base == fingerprint on a clean tree; diff shows code only); this run's own review used the recipe (`review.diff`, 3,100 lines, code only)
- **Confidence:** Verified (multi-source)

### AC16: `agents/ff-implementer.md` — Write/Edit/Bash, no subagents, no git index/history changes, only its report under the run dir
- **Method:** executed-test
- **Evidence:** guard AC16 checks (tools, no dispatch tool, forbidden git list, report-only rule) (`evidence/executed-test-13…`)
- **Confidence:** Verified (single-source)

### AC17: `models.implementer` (sonnet) and `models.escalation` (opus) in defaults and Known keys; invalid value warns and falls back
- **Method:** executed-test + cli-output
- **Evidence:** `evidence/cli-output-07-ac17-config-models.txt`; guard AC17
- **Confidence:** Partially verified
- **Gap:** the warn-and-fall-back behaviour on an invalid value was not exercised.

### AC18: prose parity for Codex; `codex-tools.md` maps the implementer and states the inline fallback; verbatim recipes
- **Method:** executed-test + cli-output
- **Evidence:** guard AC18 + pkg byte identity with drift self-test; `evidence/cli-output-01…` (the lib piped through `bash -s --` gives identical output)
- **Confidence:** Verified (multi-source)

### AC19: contract documents ledger, statuses, fix loop, rulings and the three stops — each an autopilot row of the right shape; references resolve
- **Method:** executed-test
- **Evidence:** guard AC19 (topic headings; three rows, none "unconditional", two capped); `schema-layout-guard.sh` L4 exit 0
- **Confidence:** Verified (single-source)

### AC20: new guard, every guard + eval green (Go-only excepted), 0.23.0 synced, dist repackaged
- **Method:** executed-test
- **Evidence:** 26/27 guards exit 0 (the 27th needs Go), `version-sync-guard.sh` `PASS (0.23.0)`, `dist-parity-guard.sh` `62 files in sync`, eval exit 0
- **Confidence:** Verified (single-source)

### E2E: run the controller forward test on a scratch repo with a signed full-tier spec and a 3-task executable plan whose task 2 is seeded to draw a review finding → implement complete, code and tests passing, ledger with 3 complete tasks each with base/head, diff.patch, review.md, RED→GREEN, ≥ 1 fix round on task 2; no commits
- **Method:** e2e (two independent samples)
- **Evidence:** `PASS implement-controller/fired` in both samples — 25/25 then 27/27 assertions (`evidence/e2e-03…`, `repair-e2e-03…`)
- **Confidence:** Verified (single-source)

### SM1: the controller session's own context is ≤ 60% of the inline session's on the same plan
- **Method:** cli-output (`sm1-ratio.sh` over the two arms' `run.json`)
- **Evidence:** sample 1 — exit 1, `ratio=1.459 FAIL`; sample 2 — exit 1, `ratio=1.899 FAIL` (`evidence/e2e-01…`, `repair-e2e-07…`)
- **Confidence:** Unverified — the check ran and **failed** in both samples
- **Gap:** on this 3-task plan of one-line scripts the controller's main context was 1.5–1.9× the inline session's, not ≤ 0.6×. Both sessions took 8–10 turns; the controller's per-turn context was about twice as large (it carries `ff-implement`, the task-controller topic and the dispatch results), and the inline session had almost no implementation work to accumulate. The metric as specified is not met; whether the controller wins on larger plans is unmeasured.

### FS1: a heading-shaped line inside a fenced code block mis-bounds a brief
- **Method:** executed-test + cli-output
- **Evidence:** eval `task-controller` fixture (backtick, tilde, 4-backtick fences; mutation-proven, `evidence/t2-red.log`); `evidence/cli-output-01-fs1-task-section.txt`
- **Confidence:** Verified (multi-source)

### FS2: a compaction between the implementer's edits and the Head record makes a recomputed Base drop those edits from the diff
- **Method:** executed-test + cli-output
- **Evidence:** `evidence/cli-output-03-fs2-base-timing.txt` (Base kept → both edits in the diff; recomputed → only the second); guard pins "keep the recorded Base" (mutation-proven, `evidence/t12-red.log`)
- **Confidence:** Verified (multi-source)

### FS3: untracked, non-ignored build output lands in the task diff
- **Method:** cli-output
- **Evidence:** `evidence/cli-output-04-fs3-gitignore-limit.txt` — gitignored output absent from `task_diff`; non-ignored present (the documented known limit, stated in the CHANGELOG)
- **Confidence:** Verified (single-source)

### FS4: `models.escalation` cannot be dispatched and round 3 stalls or is skipped silently
- **Method:** executed-test (wiring only)
- **Evidence:** guard FS4 check — `escalation unavailable — used <model>` in the loop (`evidence/executed-test-13…`)
- **Confidence:** Partially verified
- **Gap:** the fallback was not exercised with an unavailable model.

## Evidence artifacts index

| File | Kind | Backs |
|------|------|-------|
| `evidence/executed-test-01…27-*.txt` | executed-test | AC1–AC5, AC11–AC20, FS2, FS4 (per guard) |
| `evidence/executed-test-28-go-absence.txt` | executed-test | the Go-only guard's environment failure |
| `evidence/executed-test-29-eval-sh.txt` | executed-test | AC8, AC15, FS1 |
| `evidence/cli-output-01…07-*.txt`, `cli-probe-ac14-session-start.sh` | cli-output | FS1, AC8, FS2, FS3, AC15, AC14, AC17 |
| `evidence/e2e-01…09-*` | e2e / cli-output | E2E, SM1, AC3 (sample 1 — control FAIL), AC5–AC12 |
| `evidence/repair-executed-test-01…03-*.txt` | executed-test | AC3 (repair) |
| `evidence/repair-e2e-01…09-*` | e2e / cli-output | AC3 (repair), E2E sample 2, SM1 sample 2 |
| `evidence/a2-resume.md`, `a3-plan-size.md`, `a3-task2-executable.md` | cli-output | Assumptions 2 and 3 (plan Tasks 1, 4) |
| `evidence/t2-red.log`, `t10-red.log`, `t12-red.log` | executed-test | RED-first proofs for FS1, AC14, the guard |

## Regression risk

**Level:** Medium
**Reason:** the plan's register named template edits breaking pinned strings (did not materialize —
every plan-pinning guard is green), topic wiring (green), fence mis-bounds (covered), resume
unavailability (validated), forward-test flakiness (sample 1's control failure was a marker problem,
repaired). Not anticipated by the register: `hooks/lib/revision.sh` gained a function — additive,
Gate B and its 79 cases unchanged and green; `hooks/session-start` gained `current_task` — fail-open,
guarded. Medium because `ff-implement`, `ff-plan`, `ff-review` and the SessionStart hook are central
to every run, and the controller's cost profile (SM1) is worse than expected on small plans.

## Limitations & remaining risks

- The Go-only conformance guard cannot run locally (pre-existing; CI has Go).
- Behaviours not exercised live: the placeholder stop, `NEEDS_CONTEXT`/`BLOCKED`/`DONE_WITH_CONCERNS`,
  fix rounds 2–3 and escalation, the Critical-after-cap stop and rulings, an escalated bugfix under
  the controller, the escalation-model fallback, and invalid-config fallback.
- **SM1 failed twice.** On small plans the controller costs more main-session context (and ~4× the
  money: $1.37–1.40 vs $0.35–0.38) than inline, while producing the audit trail and catching the seeded
  defect — which the inline session also caught on its own by reading the spec.
- The repair changed `commands/ff-implement.md` after review stamped its revision; at the
  done-transition review's revision will be stale → the Stale-phase re-run cycle (one re-review).

## Verdict

**Overall confidence:** Unverified (SM1) — waived by the user, see below

> Not "done" unless every contract item is `Verified (single-source)` or better. A
> `Partially verified` or `Unverified` item blocks the done transition — the run ends with
> a gap report instead — unless the user records the explicit waiver line below. On the
> bugfix track, a fix without RED→GREEN regression evidence is **incomplete**, not done.

**Waiver (only if user-recorded):** `Evidence gap accepted by user (2026-09-24): go with recommendation — waive SM1 (the forward-test fixture is too small to show the controller's benefit; the measured small-plan overhead is recorded as a known limit and a large-plan measurement is a follow-up) and the behaviour-only partial items AC4, AC7, AC10, AC11, AC13, AC17 and FS4 (their wiring is covered by guards; forward-test arms for them are owed)`

**Verdict:** Ready for done (waived gaps: SM1, AC4, AC7, AC10, AC11, AC13, AC17, FS4)

## Repair

**Triggering item:** AC3 — "otherwise … implements inline exactly as in 0.22.0 and says which path it took and why"
**Captured failure:** `scripts/forward-test.sh … implement-controller` — control arm `assert.sh` exit 1 — `FAIL: final message does not say it implemented inline` (`evidence/e2e-04-control-assert-1.log`); the session wrote "I implemented directly … because this plan was written before that format existed" — right path and reason, no checkable marker
**Diagnosis:** the command asked for the path "in one line" with loose example wording, so the statement was free text and could not be checked; it was also not required in the final summary
**Fix applied:** `commands/ff-implement.md` §Controller activation and `docs/schema/task-controller.md` §Controller activation now require one fixed line, `Implement path: controller — <reason>` / `Implement path: inline — <reason>`, repeated in the phase's final summary; the guard pins both forms; both forward-test asserts check for them (control: `inline`; fired: `controller`)
**Re-touched items:** AC3 (the fired arm's new marker check rides on the same re-run; E2E and SM1 re-ran as a side effect and are recorded as sample 2)
**Re-verify outcome:** AC3 — Verified (multi-source): guards exit 0; control PASS 6/6 incl. `final message states 'Implement path: inline'`; fired PASS 27/27 incl. the controller marker (`evidence/repair-*`)

> Every un-touched contract item's captured evidence is preserved unchanged — an explicit
> exception to the start-of-verify evidence-clear rule; only the items named above were re-run.
