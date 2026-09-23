# Plan: Structured retrospective (ff-retro) + forward-testing of semantic behaviors

**Goal:** Ship an optional, confirm-gated `ff-retro` phase and a local fresh-process forward-test runner that proves all 7 known-gap behaviors fire (fired arm) and don't false-fire (control arm).

## Outcome gate

**Spec:** `docs/feature-flow/2026-09-23-retro-forward-testing/spec.md`
**Acceptance criteria:** see spec §Acceptance criteria (AC1–AC20). Each task below maps
to specific ACs; the final task verifies all of them.
**User signed off:** yes (2026-09-23)

> No task executes while sign-off is "no". At completion, `/feature-flow:ff-verify` checks the
> result against the spec's acceptance criteria — not just the task list.
>
> Every spec AC maps to ≥1 task's `**Covers:**` line. An AC with no task (e.g. already
> satisfied by an existing test) is listed here as an explicit gap with a one-line reason —
> never silently uncovered.
>
> **Assumption validation (full tier).** Assumption 2 (acknowledged open at sign-off) →
> Task 2 `**Validates:** Assumption 2`. Assumptions 1 and 3 are `n` → no task.
>
> **Requirement-graph coverage.** Represented edges: AC18→AC12 (Task 4 after Task 3), AC19→AC13
> (Task 9 after Task 1, transitively), AC20→AC19 (Task 10 after Task 9). Named gaps (not
> representable as task dependencies):
> - `AC5 depends-on AC3`: covered by the same Task 6.
> - `AC6 depends-on AC5`: covered by the same Task 6.
> - `AC7 depends-on AC5`: covered by the same Task 6.
> - `AC10 depends-on AC3`: covered by the same Task 6.
> - `AC14`/`AC16`/`AC17 depends-on AC13`: covered by the same Task 1.
> - `AC13 depends-on AC12`: the runner (Task 1) is deliberately built **before** the fixtures so
>   it can validate them (Task 2 needs it); AC13's end-to-end proof lands in Task 9, which depends
>   on the fixtures (Task 3) transitively.
>
> **Design failure scenarios** FS1 (wrong-reason STOP), FS2 (budget sizing), FS3 (headless retro
> skipping its gate) are proven in Task 8 (FS1, FS3) and Task 2 + Task 9 (FS2).

## Tasks

### Task 1: Forward-test runner + case-shape README [x]

**Files:**
- Create: `scripts/forward-test.sh`, `evals/forward/README.md`

**Covers:** AC13, AC14, AC15, AC16, AC17

- [ ] **Step 1:** Write `evals/forward/README.md`: arm layout (`sandbox/`, `prompt.txt`, `expected.md`, `assert.sh <tmpdir> <run.json>` exit 0/1), blind-prompt rule, fired/control convention, "flaky is not green", marker-keyed assertions (FS1), how to add a behavior, the retro→case mapping (fired input = fired `prompt.txt`, expected outcome = `expected.md`, control input = control `prompt.txt`), cost note, and "not CI / not shipped".
- [ ] **Step 2:** Write `scripts/forward-test.sh` per design (preflight exit 2; `mktemp` + `git init` + empty commit + `cp -R`; `timeout` + `claude -p --plugin-dir "$REPO_ROOT" --max-budget-usd --output-format json`; ERROR/FAIL/PASS classification; `--repeat` rollup; per-arm + total cost via `python3`; transcripts + `summary.md` to `.feature-flow/forward-test-runs/<UTC>/`; exit 0 iff all PASS). `chmod +x`.
- [ ] **Step 3: Verify** — `bash -n scripts/forward-test.sh` exits 0; `PATH=/usr/bin:/bin scripts/forward-test.sh` (no `claude`) → exit 2 + message; `scripts/forward-test.sh nosuch` → exit 2 listing valid names; a throwaway local case with a stub `claude` on PATH (scratchpad) returning `is_error:true` → `ERROR`, one returning valid JSON with a passing/failing `assert.sh` → `PASS`/`FAIL`, and `--repeat 2` with an alternating stub → `FAIL`.

### Task 2: Validate Assumption 2 on the lowest- and highest-risk behaviors; size the budget [x]

**Files:**
- Create: `evals/forward/delivery-gap/{fired,control}/…`, `evals/forward/assumption-gap/{fired,control}/…`

**Covers:** AC12
**Validates:** Assumption 2

- [ ] **Step 1:** Build `delivery-gap` arms (done run; fired `plan.md` migration task with no `§Rollback plan` row, seeded from `evals/fixtures/delivery-gap/plan.md`; control with the row). Prompt: run `/feature-flow:ff-deliver <slug>`. Assert: `⚠ DELIVERY GAP` present / absent in the written `delivery.md` (and `delivery.md` exists in both).
- [ ] **Step 2:** Build `assumption-gap` arms (clarify in progress, spec written, `signOff.signed:false`; fired spec has one `validation-required: y` row seeded from `evals/fixtures/assumption-gap/spec.md`; control all `n`). Prompt: resume clarify with the user's sign-off reply embedded. Assert: fired `signOff.signed == false` **and** `Unvalidated assumptions` in `.result`; control `signOff.signed == true`.
- [ ] **Step 3: Verify** — `scripts/forward-test.sh delivery-gap assumption-gap` → 4 PASS lines. Record per-arm cost; set the runner's default `--max-budget-usd` with ≥2× headroom over the costliest observed arm. If `assumption-gap` cannot be made disk-deterministic, record that in its `expected.md` + mark Assumption 2 "partially holds" in the Decisions section.

### Task 3: Remaining five behaviors [x]

**Files:**
- Create: `evals/forward/{design-gap,repair-gap,discovery-gap,decision-conflict,planning-gap}/{fired,control}/…`

**Covers:** AC12

- [ ] **Step 1:** `design-gap` ← `.feature-flow/ws5-selfrun-{fired,control}-v2` (made self-contained, `autopilot` explicit). Prompt: run `/feature-flow:ff-verify <slug>`. Assert: fired `currentPhase != done` **and** `### FS1` below `Verified (single-source)`; control `currentPhase == done`.
- [ ] **Step 2:** `repair-gap` ← `.feature-flow/ws6-selfrun-{fired,control}` with `autopilot: true`. Assert: fired `## Repair` present in `verify.md`; control absent **and** `currentPhase == done`.
- [ ] **Step 3:** `discovery-gap` (SM<n> half; requirement-graph half named uncovered in `expected.md`). Assert: fired `currentPhase != done` **and** `### SM1` below `Verified (single-source)`; control `done`.
- [ ] **Step 4:** `decision-conflict` and `planning-gap` (implement-entry, signed, valid artifacts so no other gate trips). Assert fired: behavior-specific STOP text in `.result` **and** no tracked change outside `.feature-flow/`; control: no STOP text **and** ≥1 source file written.
- [ ] **Step 5: Verify** — `scripts/forward-test.sh design-gap repair-gap discovery-gap decision-conflict planning-gap` → 10 PASS lines (iterate sandboxes until they do).

### Task 4: Forward-test structure guard [x]

**Files:**
- Create: `scripts/checks/forward-test-guard.sh`

**Covers:** AC18

- [ ] **Step 1:** Guard: for each of the 7 slugs, both arms exist with non-empty `sandbox/`, `prompt.txt`, `expected.md`, executable `assert.sh`; `evals/forward/README.md` exists; `scripts/forward-test.sh` exists and no `forward-test*` file under `scripts/checks/` except this guard; `dist/codex/feature-flow/evals` absent. Header disclaims firing (covered by the runner, not CI).
- [ ] **Step 2: Verify** — `bash scripts/checks/forward-test-guard.sh` exits 0; temporarily `chmod -x` one `assert.sh` in a scratch copy → guard exits non-zero.

### Task 5: Retrospective contract [x]

**Files:**
- Modify: `docs/manifest-schema.md`, `schemas/manifest-v1.schema.json`

**Covers:** AC4, AC11

- [ ] **Step 1:** `docs/manifest-schema.md`: new `## Retrospective` after §Delivery (purpose vs KB, activation, done gate, signal list, materiality test, 9-field schema + closed enums, confirm gate = KB capture shape, write mechanics, zero/reject-all paths, AC10 link to `evals/forward/README.md`, non-goals); `phases.retro`/`artifacts.retro` Field-notes bullet; `retro` in the durable-eligible list; §Autopilot mandatory-pauses row "Retro confirm-gate (`ff-retro`)" (not "unconditional"); "Retro is never chained" line next to "Delivery is never chained".
- [ ] **Step 2:** `schemas/manifest-v1.schema.json`: `"retro": {"$ref": "#/$defs/phase"}` in `phases` + `"retro"` in the four track `propertyNames` enums; `currentPhase` enum untouched.
- [ ] **Step 3: Verify** — `python3 -c "import json;json.load(open('schemas/manifest-v1.schema.json'))"` exits 0; `go test ./...` exits 0; grep shows `retro` absent from the `currentPhase` enum.

### Task 6: ff-retro command + template [x]

**Files:**
- Create: `commands/ff-retro.md`, `templates/retro.md`

**Covers:** AC1, AC2, AC3, AC5, AC6, AC7, AC9, AC10

- [ ] **Step 1:** `templates/retro.md` (header, source blockquote, 9-column findings table with the AC10 `Fired input / Expected outcome / Control input` shape for forward-test-owned rows, `_No material events._` sentinel, `## Rejected` count, `## Notes`).
- [ ] **Step 2:** `commands/ff-retro.md` cloned from `ff-deliver.md` per design (done gate, no tier gate, re-run guard, pointer-only cold-start, closed signal scan, materiality test by name, confirm gate by name, durable write, manifest update, hand-off; never chained; no KB; no git).
- [ ] **Step 3: Verify** — grep: command references `§Retrospective` by name, uses only `artifacts.<name>` pointers (no bare durable filenames), contains the confirm-gate phrase; template carries all 9 field labels + sentinel.

### Task 7: Wiring, guards, packaging [x]

**Files:**
- Modify: `commands/ff-verify.md`, `commands/ff-review.md`, `skills/feature-flow/SKILL.md`, `README.md`, `scripts/checks/durable-paths-guard.sh`
- Create: `scripts/checks/retro-guard.sh`

**Covers:** AC8, AC11

- [ ] **Step 1:** Terminal hand-offs in `ff-verify.md` (feature) and `ff-review.md` (bugfix) name `/feature-flow:ff-retro` alongside `/feature-flow:ff-deliver` as optional next steps; SKILL.md + README command tables list `ff-retro`; README dev note on `scripts/forward-test.sh`.
- [ ] **Step 2:** `durable-paths-guard.sh`: `check_writer commands/ff-retro.md retro`; `retro` in `DURABLE` regex; `retro-guard.sh` cloned from `delivery-guard.sh` (schema section + materiality + enums, command pointers/gates/confirm phrase/never-chained, template labels, JSON-schema 5 places + not in `currentPhase`, pause row present and not "unconditional", hand-off mentions, SKILL/README, dist parity).
- [ ] **Step 3: Verify** — `bash scripts/package-codex-plugin.sh` then `for g in scripts/checks/*.sh; do bash "$g" || echo FAIL $g; done` → no FAIL; `bash scripts/eval.sh` exits 0.

### Task 8: Devil's-advocate proofs (FS1 mutation, FS3 headless retro) [x]

**Files:**
- Create: evidence under `docs/feature-flow/2026-09-23-retro-forward-testing/evidence/`

**Covers:** AC5, AC6

- [ ] **Step 1 (FS1):** Copy the plugin to a scratch dir, delete the do-not-contradict STOP instruction from the copy's `commands/ff-implement.md`, run the `decision-conflict/fired` arm against the copy (`--plugin-dir <scratch>`) → must be FAIL. Log it.
- [ ] **Step 2 (FS3/AC5):** Plant a `done` run with a `## Repair` section and an `Evidence gap accepted by user` line in a scratch dir; run `claude -p --plugin-dir <repo> "/feature-flow:ff-retro <slug>"` headless → assert no `retro.md`, `phases.retro` not `complete`, no file changed except (optionally) manifest `in_progress`; `.result` contains a candidate table. Then run a second headless turn (`--resume`) with an accept reply → assert `retro.md` written with the accepted finding, `phases.retro.status == complete`, `currentPhase == done`, and `git status` shows only the manifest + `retro.md` (AC6).
- [ ] **Step 3: Verify** — both logs saved under `evidence/`; outcomes match the expected ones above.

### Task 9: Full-suite run [x]

**Files:**
- Create: `docs/feature-flow/2026-09-23-retro-forward-testing/evidence/forward-test-full/`

**Covers:** AC19

- [ ] **Step 1:** `scripts/forward-test.sh` (all 7) with the final plugin.
- [ ] **Step 2: Verify** — 14 PASS lines, exit 0, every arm `is_error:false` with cost under its cap (FS2); copy `summary.md` + transcripts into the evidence dir.

### Task 10: Honest wording, version, final sweep [x]

**Files:**
- Modify: `CHANGELOG.md`, `.github/workflows/ci.yml`, `scripts/eval.sh`, `.claude-plugin/plugin.json`, `.codex-plugin/plugin.json`, `.claude-plugin/marketplace.json`, `README.md`

**Covers:** AC20, AC11

- [ ] **Step 1:** CHANGELOG `[0.18.0]` entry (ff-retro, forward-testing, WS-7 requirement-graph half still uncovered, forward tests are local-only, not CI); annotate the 8 "Known coverage gap" callouts that firing is now covered by `scripts/forward-test.sh` (local, not CI); `ci.yml` eval comment updated; `scripts/eval.sh` header says blocking; version 0.17.1 → 0.18.0 everywhere version-sync-guard checks.
- [ ] **Step 2: Verify** — `bash scripts/package-codex-plugin.sh`; all `scripts/checks/*.sh` exit 0; `bash scripts/eval.sh` exits 0; `grep -n "NON-BLOCKING" scripts/eval.sh` → no match.

## Dependency graph

| Task | Depends on |
|------|------------|
| Task 1 | — (root) |
| Task 2 | Task 1 |
| Task 3 | Task 2 |
| Task 4 | Task 3 |
| Task 5 | — (root) |
| Task 6 | Task 1, Task 5 |
| Task 7 | Task 6 |
| Task 8 | Task 4, Task 7 |
| Task 9 | Task 8 |
| Task 10 | Task 9 |

> One row per task in `## Tasks` above. `Depends on` names only **lower-numbered** `Task N`
> IDs already defined above (or "— (root)" for no prerequisite) — never a phantom or a
> higher-numbered task. Multiple roots are normal; this is dependency data, not an instruction
> to run tasks concurrently.

## Critical path

**Path:** Task 1 → Task 2 → Task 3 → Task 4 → Task 8 → Task 9 → Task 10

> Derived: chainLength T1=1, T2=2, T3=3, T4=4, T5=1, T6=2, T7=3, T8=5, T9=6, T10=7. Sink Task 10;
> walk back via the greatest-chainLength dependency (T8 → T4 [4] over T7 [3]).
> **Derived — never hand-authored.** Every task named here is non-skippable, in this order:
> `/feature-flow:ff-implement` STOPs if the approach skips or reorders one. Re-derive if the graph changes.

## Risk register

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|-----------|
| A sandbox exercises cold-start routing instead of the target behavior (wrong-reason STOP → false PASS) | Med | High | Marker-keyed assertions; FS1 mutation proof in Task 8 |
| Live arms cost more than expected / hit budget → ERROR | Med | Med | Measure in Task 2 before building the rest; default cap with ≥2× headroom |
| `assumption-gap` single-turn sign-off doesn't work headlessly | Med | Med | Built first in Task 2 (validates Assumption 2); fallback: transcript-text assertion, named |
| LLM variance makes an arm flaky | Med | Med | `--repeat N`; flaky reported FAIL, investigated not ignored |
| Guards/dist parity drift (many touched files) | Med | Low | Package + full guard sweep in Tasks 7 and 10 |
| Retro candidate quality depends on prose discipline | Med | Low | Closed signal list + materiality test; user edits at the gate. Accepted, not mitigated further: semantic quality is judgment |
| Real regression found in a shipped STOP (fired arm genuinely fails) | Low | High | Per spec: fix if cheap, else surface as a verify gap for the user |

## Rollback plan

| Task | Recovery action if `Step N: Verify` fails |
|------|--------------------------------------------|
| Task 1 | `rm -f scripts/forward-test.sh evals/forward/README.md` and redo |
| Task 2 | `rm -rf evals/forward/{delivery-gap,assumption-gap}`; re-plan assertion shape (Decisions section) |
| Task 3 | `rm -rf evals/forward/<behavior>` for the failing behavior only |
| Task 5 | `git checkout -- docs/manifest-schema.md schemas/manifest-v1.schema.json` |
| Task 6 | `rm -f commands/ff-retro.md templates/retro.md` |
| Task 7 | `git checkout -- commands/ff-verify.md commands/ff-review.md skills/feature-flow/SKILL.md README.md scripts/checks/durable-paths-guard.sh && rm -f scripts/checks/retro-guard.sh && bash scripts/package-codex-plugin.sh` |
| Task 10 | `git checkout -- CHANGELOG.md .github/workflows/ci.yml scripts/eval.sh .claude-plugin .codex-plugin README.md && bash scripts/package-codex-plugin.sh` |

## Status conventions

Stateful document. After each task bump its status:
`[ ]` pending · `[~]` in progress · `[x]` done · `[!]` blocked · `[→]` deferred.
Keep a Status summary line current; append Blockers / Deviations / Decisions as needed.

**Status:** 10/10 tasks done.

## Blockers

(none yet)

## Decisions made during execution

- **Assumption 2 — holds for delivery-gap and assumption-gap (2026-09-23).** Both arms of both
  behaviors PASS on disk-state assertions (delivery-gap: `⚠ DELIVERY GAP:` line in the written
  `delivery.md`; assumption-gap: `signOff.signed` false vs true + the spec's sign-off line). The
  single-turn embedded sign-off works headlessly. Evidence: `.feature-flow/forward-test-runs/t2-*`.
- **Budget default $2.00/session** — costliest observed session $0.27 (≥2× headroom, room for the
  heavier verify/implement arms). Timeout default 900 s.
- **Runner isolation** — sessions run with `--setting-sources project,local` (user-level plugins and
  hooks such as unrelated SessionStart skill mandates don't load), `--strict-mcp-config`,
  `--permission-mode bypassPermissions` (cwd is a throwaway temp repo). `--bare` rejected: it skips
  the plugin's own enforce-gate hook and requires an API key.
- **`.gitignore` negations** for `evals/forward/*/*/sandbox/.feature-flow{/,.json}` — the repo ignores
  those names at any depth, but planted sandboxes must be committed.
- **Blind sandboxes** — fixture content is re-authored without the "DELIBERATE HOLE … must flag"
  notes the `evals/fixtures/*` files carry, which would leak the expected outcome to the session.
- **`templates/retro.md` uses one `### Finding N` block of nine labeled bullets per finding** instead
  of a 9-column table (unreadable at that width; bullets are grep-pinnable). Same nine fields.
- **`ff-retro` makes no manifest write before the confirm gate** (the design said `in_progress` at
  start) — an unanswered gate then leaves the run byte-identical, which is what AC1/AC5/FS3 check.
- **Sandboxes are self-contained re-authorings, not copies** of `.feature-flow/ws5-/ws6-selfrun-*`: those
  were post-run snapshots whose ACs pointed at scripts inside this repo. Same scenario shapes, built on
  a tiny `slugify` project; fired-arm FS1/SM1 are production-only (unprovable in a sandbox by
  construction), controls carry a runnable local check.
- **FS1 mutation proof — split result (2026-09-23).** `delivery-gap`: with the gap cross-check stripped
  from command + schema + template + SKILL of a scratch plugin copy, the fired arm **FAILs** and the
  control still PASSes → the harness does catch a hollowed behavior. `decision-conflict`: with the
  do-not-contradict STOP stripped from **every** file (command section, schema §Decision recall,
  §Autopilot row), the fired arm **still PASSed** — the model refuses from the sandbox's explicit
  decision record on its own. Recorded as a named attribution limit in
  `evals/forward/decision-conflict/fired/expected.md`, the README-linked CHANGELOG entry, and the
  WS-1 gap annotation. Evidence: `.feature-flow/forward-test-runs/fs1-mutant{,-v2,-delivery}`.
- **FS3 proven (2026-09-23).** Headless `ff-retro` on a planted `done` run: turn 1 proposed 3 candidates
  (dropped the cleanly-waived FS1 as not material), wrote **nothing** (`git status` empty); turn 2
  (`--resume`, "1 accept, 2 reject, 3 accept") wrote only `retro.md` + the manifest — 2 findings,
  "1 candidate(s) … rejected", `phases.retro` complete, `currentPhase` done, `closedAt` null.
  Evidence: `.feature-flow/forward-test-runs/fs3-retro/`.
- **Explore missed a Go touchpoint.** `integrity/migration/plan.go` `knownPhase` and
  `integrity/doctor/doctor.go` `phaseArtifact` enumerate phases (incl. `deliver`); without `retro` a
  legacy manifest carrying `phases.retro` is **refused** by migration. Fixed both; new
  `TestPlanAcceptsPostTerminalPhases` observed RED with the fix reverted, GREEN restored; full
  `go test ./...` green (Go 1.26.8 installed to the scratchpad — this machine had no toolchain).
- **CHANGELOG gap annotations are scoped, not blanket**: WS-7 (SM half only), WS-2 v0.11.0 (the
  implement STOP, not plan derivation), WS-1 (attribution limit).
- **Task 9 was run twice.** The first full-suite run showed 14/14 arm PASS lines but died in its summary
  step (`syntax error near unexpected token |`, exit 2), because `scripts/forward-test.sh` was edited
  (review fix) while that run was executing and bash reads a running script incrementally. It is kept
  as evidence of nothing; the **final** run on the finished code is the AC19 evidence: 14/14 PASS,
  exit 0, $4.30. Lesson: never edit a script a background run is executing.
- **Review ran in parallel with the tail of Task 9** (reviewers read the diff, not suite output); its
  3 Important findings were fixed before the final suite run.
