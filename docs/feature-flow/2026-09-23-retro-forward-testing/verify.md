# Verify: Structured retrospective (ff-retro) + forward-testing of semantic behaviors

**Track:** feature
**Tier:** full
**Date:** 2026-09-23
**Verified by:** the orchestrating session. The plugin's `ff-test-runner` agent type is not installed
in this session, so every command below was executed directly via Bash and its real exit status
captured. "Live" items are **fresh headless `claude -p --plugin-dir <repo>` sessions** loading the
working-tree plugin: the only way to observe the semantic behaviors fire.

## Commands run

| Command | Kind | Status | Evidence |
|---------|------|--------|----------|
| `scripts/forward-test.sh` (all 7 behaviors, final code) | executed-test | pass | exit **0**, `14/14 PASS, 0 FAIL, 0 ERROR · total $4.3004` → `evidence/forward-test-full/summary.md` |
| `for g in scripts/checks/*.sh; do bash $g; done` | executed-test | pass | 20/20 guards exit **0** (incl. new `retro-guard`, `forward-test-guard`; `integrity-conformance-guard` with Go 1.26.8) → `evidence/guards.log` |
| `bash scripts/eval.sh` | executed-test | pass | exit **0** → `evidence/eval.log` |
| `go vet ./... && go test ./...` (+ `gofmt -l`) | executed-test | pass | exit **0**; gofmt clean; all packages ok incl. new `TestPlanAcceptsPostTerminalPhases` → `evidence/go.log` |
| `go test ./integrity/migration -run PostTerminal` with the `knownPhase` fix reverted | executed-test | fail (RED, expected) | exit **1** before fix, **0** after (captured in session; recorded in plan §Decisions) |
| `bash scripts/package-codex-plugin.sh` | build/static-analysis | pass | exit **0** → `evidence/package.log`; `dist/codex/feature-flow/` has no `evals/` and no `scripts/` |
| runner edge cases with a stub `claude` on PATH | executed-test | pass | each exit code/classification as specified → `evidence/runner-stub-tests.log` |
| headless `ff-retro` on non-done + abandoned runs | cli-output | pass | both STOP, `git status` empty → `evidence/ac1-not-done.*`, `evidence/ac1-abandoned.*` |
| headless `ff-retro` FS3 (turn 1 gate, turn 2 answer) | cli-output | pass | turn 1 changes: none; turn 2 changes: manifest + `retro.md` only → `evidence/fs3-retro/` |
| headless `ff-retro` clean run (turn 1 + confirm) | cli-output | pass | "no material events"; `retro.md` Findings `_No material events._` → `evidence/ac7-*` |
| headless `ff-retro` re-run on completed retro | cli-output | pass | asks to overwrite, changes: none → `evidence/ac9-rerun.*` |
| headless `ff-retro` with a forward-test-owned note | cli-output | pass | Proposed validation = Fired input / Expected outcome / Control input → `evidence/ac10-turn1.*` |
| mutation runs (plugin copies with a behavior's instruction stripped) | cli-output | pass (see FS1) | delivery-gap fired **FAIL**; planning-gap fired **FAIL**; decision-conflict fired still PASS → `evidence/mutation/`, `evidence/fs1-planning-mutant.*` |

> This is a plugin of prose commands + bash guards + a Go integrity kernel. There is no app build,
> browser, HTTP or DB surface. The "tests" are the guard suite, the eval harness, `go test`, and the
> live headless sessions, which are the project's real verification surfaces.

## Evidence coverage matrix

| Detected surface | Expected kind | Ran? | Result | Notes (gap / N/A reason) |
|------------------|---------------|------|--------|--------------------------|
| `scripts/checks/*.sh` guard suite | executed-test | yes | pass | 20/20 |
| `scripts/eval.sh` | executed-test | yes | pass | |
| Go module (`go.mod`) | executed-test + build/static-analysis | yes | pass | toolchain installed to the scratchpad (none on this machine) |
| `scripts/forward-test.sh` (the new runner) | executed-test | yes | pass | stubbed edge cases + one live full suite |
| live plugin behavior (`claude -p --plugin-dir`) | cli-output | yes | pass | 14 suite arms + 9 targeted sessions + 4 mutation sessions |
| Codex packaging | build/static-analysis | yes | pass | |
| e2e/browser, http/api, db, logs | — | — | N/A | no such surface in this repo |
| before/after | before/after | yes | pass | mutation runs = with/without the instruction; Go test RED→GREEN |

## Contract mapping

Confidence per item: one of `Verified (multi-source)` | `Verified (single-source)` | `Partially
verified` | `Unverified`, derived per `docs/manifest-schema.md` §Evidence, Confidence ladder.

### AC1: `/feature-flow:ff-retro <slug>` on a run whose `currentPhase` is not `done` (including an abandoned run) STOPs with a message naming the current phase and writes no file and no manifest change.
- **Method:** cli-output (live) + executed-test (guard)
- **Evidence:** `evidence/ac1-not-done.json`: "'url-slugs' is at `review`", `ac1-not-done.changes` empty; `evidence/ac1-abandoned.json`: "'url-slugs' is at `abandoned`", changes empty; `retro-guard.sh` exit 0 (done-gate + "Write **no** file" pinned)
- **Confidence:** Verified (multi-source)

### AC2: On a `done` run (either track, either tier, closed or not), `ff-retro` resolves upstream artifacts only via `manifest.artifacts.<name>` pointers and proposes candidate events from these on-disk signals when present: user override/waiver lines, review `## Resolution`, verify `## Repair`, evidence gaps, Critical findings — plus any free-text notes in `$ARGUMENTS`.
- **Method:** cli-output (live) + executed-test (guards)
- **Evidence:** `evidence/fs3-retro/turn1.json`: the signals found were the `## Repair` cycle, FS1 `Unverified` plus the "Evidence gap accepted by user" line, and the user's note. `ac7-turn1.json` lists each source "via `manifest.artifacts`" and marks absent ones "not available". `retro-guard.sh` pins all eight `artifacts.<name>` reads, and `durable-paths-guard.sh` §(k) finds no bare-name reader (both exit 0).
- **Confidence:** Verified (multi-source)
- **Note:** exercised on feature/full runs only; lite/bugfix/closed acceptance is pinned structurally ("**No tier gate.**") but not run live.

### AC3: Every proposed candidate carries all nine fields — event, expected, observed evidence (a path or quoted line), impact, safeguard, safeguard result ∈ {worked, failed, missing, ambiguous, bypassed}, generalizability ∈ {one-off, repo-specific, reusable}, recommended owner ∈ {…8 values…}, proposed validation — with no numeric score.
- **Method:** cli-output (live) + executed-test (guard)
- **Evidence:** `fs3-retro/turn1.json` (3 candidates) and `ac10-turn1.json` (3 candidates). Every candidate has all nine fields with in-enum values (`failed`/`missing`/`worked`; `reusable`/`one-off`; `feature-flow command/skill`, `guard/validator script`, `regression/forward test`, `no change`) and no numeric score. `retro-guard.sh` pins the schema enums and the template's nine labels.
- **Confidence:** Verified (multi-source)

### AC4: `docs/manifest-schema.md` §Retrospective states a materiality test, and `ff-retro` proposes only events that pass it.
- **Method:** executed-test (guard) + cli-output (live)
- **Evidence:** `retro-guard.sh` pins `### Materiality test`. Live, both `fs3-retro/turn1` and `ac10-turn1` report "Dropped by the materiality test: the FS1 waiver … clean one-off".
- **Confidence:** Verified (multi-source)

### AC5: `ff-retro` ends its turn presenting the candidates and writes nothing until the user accepts, edits, or rejects each one; this holds in autopilot.
- **Method:** cli-output (live) + executed-test (guard)
- **Evidence:** `fs3-retro/turn1-changes.txt`, `ac7-turn1.changes`, `ac9-rerun.changes` are all **empty** after the gate turn, and each output ends asking for accept/edit/reject. The `ac10` sandbox (manifest `autopilot: true`) also held: its only listed change, `?? verify.md`, is a planting artifact of the test setup (copied in after the baseline commit), not a session write. `retro-guard.sh` pins "Nothing is written until the user confirms" and "Never answer this gate yourself".
- **Confidence:** Verified (multi-source)

### AC6: After confirmation, `retro.md` is written from `templates/retro.md` at the durable-resolved path with only accepted findings plus a rejected count; `artifacts.retro` and `phases.retro = {status: complete, artifact}` are set; `currentPhase` stays `done`; no other file is created or modified.
- **Method:** cli-output (live) + executed-test (guard)
- **Evidence:** `fs3-retro/turn2-changes.txt` = ` M manifest.json`, `?? retro.md` only. Manifest: `currentPhase: done`, `phases.retro: {complete, .feature-flow/url-slugs/retro.md}`, `artifacts.retro` set, `closedAt: null`. `fs3-retro/retro.md` has 2 `### Finding` blocks ("1 accept, 2 reject, 3 accept") and "1 candidate(s) proposed and rejected". `ac7-turn2.changes` is the same two files. `retro-guard.sh` exit 0.
- **Confidence:** Verified (multi-source)

### AC7: With zero candidates and no notes, the gate says "no material events" and, on confirm, `retro.md` contains `_No material events._`.
- **Method:** cli-output (live) + executed-test (guard)
- **Evidence:** `ac7-turn1.json`: "**Candidates: none. No material events.**". `evidence/ac7-retro.md` Findings = `_No material events._`, Rejected = "0 candidate(s)". `retro-guard.sh` pins the sentinel.
- **Confidence:** Verified (multi-source)

### AC8: Autopilot never chains into `ff-retro`; the feature- and bugfix-terminal hand-off messages name `/feature-flow:ff-retro` as an optional next step alongside `ff-deliver`.
- **Method:** executed-test (guard) + cli-output (live)
- **Evidence:** `retro-guard.sh` pins "Retro is never chained", the non-"unconditional" pause row, and the ff-retro + ff-deliver mention in `ff-verify.md` and `ff-review.md`. Live: `first-pass/t3-verify/repair-gap/fired/run-1.json` (autopilot, reaches done) ends "Optional next steps: `/feature-flow:ff-deliver` … `/feature-flow:ff-retro`", and neither the fired nor the control autopilot arm wrote a `retro.md` (`changes-1.txt`).
- **Confidence:** Verified (multi-source)

### AC9: Running `ff-retro` on a run whose `phases.retro.status` is `complete` asks for confirmation before overwriting.
- **Method:** cli-output (live) + executed-test (guard)
- **Evidence:** `ac9-rerun.json`: "Re-run guard: `url-slugs` already has a completed retrospective … Do you want to overwrite?"; `ac9-rerun.changes` empty. `retro-guard.sh` pins "Re-run guard".
- **Confidence:** Verified (multi-source)

### AC10: A retro finding whose owner is "regression/forward test" states its proposed validation as a fired input + expected outcome (+ control input when applicable), matching the case shape documented in `evals/forward/README.md`.
- **Method:** cli-output (live) + executed-test (guard)
- **Evidence:** `ac10-turn1.json` candidate 1 has owner `regression/forward test` and Proposed validation "**Fired input:** … **Expected outcome:** … **Control input:** …". It even asks for a marker-keyed assert. `retro-guard.sh` pins the shape in the schema, command and template, and the README has §"From a retrospective finding".
- **Confidence:** Verified (multi-source)

### AC11: Wiring: `docs/manifest-schema.md` has `## Retrospective`; `retro` is in the durable-eligible artifact list; `phases.retro` is accepted by `schemas/manifest-v1.schema.json` (phases object + all four track enums); SKILL.md and README list `ff-retro`; new `scripts/checks/retro-guard.sh` pins these plus Codex dist parity; all `scripts/checks/*.sh` and `scripts/eval.sh` exit 0.
- **Method:** executed-test (guards, eval, Go tests) + build/static-analysis (package, JSON parse)
- **Evidence:** `guards.log` 20/20 exit 0 (the retro-guard JSON check asserts `phases.retro` + 4 track enums, not `currentPhase`). `eval.log` exit 0. `go.log` exit 0: the Go kernel's `knownPhase`/`phaseArtifact` were extended (explore missed this), and the new test was RED before and GREEN after. `package.log` exit 0 (dist parity: 47 files in sync).
- **Confidence:** Verified (multi-source)

### AC12: `evals/forward/<behavior>/{fired,control}/` exists for each of the 7 known-gap behaviors, and each arm contains a planted run sandbox, a prompt that does not state the expected outcome, a declared expected outcome, and an executable assertion.
- **Method:** executed-test (guard) + cli-output (live suite)
- **Evidence:** `forward-test-guard.sh` exit 0 (7×2 arms × 4 parts, blind-prompt lexical check, `autopilot` explicit, sandboxes committable). A mutated copy (leaky prompt + non-executable assert) exits 1. The live suite exercised all 14 arms (`forward-test-full/summary.md`).
- **Confidence:** Verified (multi-source)

### AC13: `scripts/forward-test.sh [behavior...]` runs each selected arm in a fresh temp copy of its sandbox via a new `claude -p --plugin-dir <repo>` process, then runs the arm's assertion in that copy; prints one `PASS|FAIL|ERROR <behavior>/<arm>` line per arm and a summary; exits 0 iff every arm is PASS.
- **Method:** executed-test (stub) + cli-output (live)
- **Evidence:** `runner-stub-tests.log`: an all-PASS selection exits 0, any FAIL/ERROR exits 1, one line per arm plus a summary. Live `forward-test-full/`: 14 `PASS` lines, summary, exit 0, and per-arm `changes-1.txt` shows each session worked in its own temp copy.
- **Confidence:** Verified (multi-source)

### AC14: Each arm's spend is capped via `--max-budget-usd` (configurable, with a default); the runner prints per-arm and total cost; a budget stop, non-zero CLI exit, or timeout marks the arm ERROR, never PASS.
- **Method:** executed-test (stub) + cli-output (live)
- **Evidence:** `runner-stub-tests.log`: `error_max_budget_usd` → ERROR, `claude exited 3` → ERROR, `timeout after 1s` → ERROR, assert crash → ERROR, and costs printed per arm and in total. Live summary: "Budget/run: $2.00", per-arm costs, total $4.3004.
- **Confidence:** Verified (multi-source)

### AC15: With `claude` not on PATH, or an unknown behavior name, the runner exits 2 with an explanatory message and runs no arm.
- **Method:** executed-test (stub)
- **Evidence:** `runner-stub-tests.log`: "'claude' CLI not found on PATH" exit=2; "unknown behavior 'nosuch' — valid: …" exit=2; no arm lines printed.
- **Confidence:** Verified (single-source)

### AC16: `--repeat N` runs each arm N times; the arm is PASS only if all N runs pass.
- **Method:** executed-test (stub)
- **Evidence:** `runner-stub-tests.log`: `--repeat 2` with an alternating assert → `FAIL flaky/fired` (run 1 PASS, run 2 FAIL); stable arm → PASS.
- **Confidence:** Verified (single-source)

### AC17: The runner writes each arm's transcript and a summary file to an output directory (default under a gitignored path).
- **Method:** executed-test (stub) + cli-output (live)
- **Evidence:** `runner-stub-tests.log` §AC17 lists `run-1.json`, `.err`, `assert-1.log`, `changes-1.txt` per arm. Live output dir `forward-test-full/` has the same plus `summary.md`. The default is `.feature-flow/forward-test-runs/<UTC>/`, and `.feature-flow/` is gitignored.
- **Confidence:** Verified (multi-source)

### AC18: The runner is not under `scripts/checks/`; new `scripts/checks/forward-test-guard.sh` fails if any of the 7 behaviors lacks either arm or any of the four arm parts, and `evals/forward/` is absent from the Codex dist.
- **Method:** executed-test (guard + mutation) + build/static-analysis (package)
- **Evidence:** guard exit 0 on the tree, exit 1 on the mutated copy. `package.log` exit 0, and `dist/codex/feature-flow/` contains `agents commands config docs integrity LICENSE README.md schemas skills templates`, with no `evals` or `scripts`.
- **Confidence:** Verified (multi-source)

### AC19: A full-suite run (`scripts/forward-test.sh`, all 7 behaviors) produces 14 PASS lines — every fired arm shows its STOP/fire signature and every control arm PROCEEDs — and its summary + transcripts are kept as this run's verify evidence.
- **Method:** cli-output (live)
- **Evidence:** `evidence/forward-test-full/summary.md`: **14/14 PASS**, exit 0, $4.3004. Each arm's `assert-1.log` shows its marker checks (e.g. delivery-gap fired "⚠ DELIVERY GAP line names Task 2", repair-gap fired "exactly one ## Repair section", planning-gap fired "STOP names the critical path"), and every `run-1.json` has `is_error: false`.
- **Confidence:** Verified (single-source)
- **Note:** a first full-suite attempt also showed 14/14 arm PASS lines but crashed in its summary step (exit 2) because the runner script was edited mid-run. That run is not counted.

### AC20: `CHANGELOG.md` (new entry), the `.github/workflows/ci.yml` eval comment, and the 7 behaviors' coverage-gap wording state that semantic firing is covered by the local forward-test runner (still not CI); the `scripts/eval.sh` header no longer says non-blocking.
- **Method:** cli-output (grep) + executed-test (version-sync guard)
- **Evidence:** `ac20-greps.log`: `NON-BLOCKING matches: 0` in `scripts/eval.sh`; the `ci.yml` comment names the local forward-test runner; 8/8 "Known coverage gap" callouts carry a v0.18.0 note, scoped where coverage is partial (WS-7 SM half only, WS-2 implement STOP not derivation, WS-1 attribution limit). `[0.18.0]` entry present; `version-sync-guard` exit 0 at 0.18.0.
- **Confidence:** Verified (multi-source)

### FS1: A fired arm STOPs for the **wrong reason** … and a loose `assert.sh` ("nothing was written") scores it PASS. Proof required: for at least one STOP-shaped behavior, a **mutation run** — the target STOP instruction removed from a scratch copy of the plugin — makes the fired arm **FAIL**.
- **Method:** cli-output (live mutation runs) + before/after
- **Evidence:** **planning-gap (STOP-shaped):** with the critical-path check stripped from `ff-implement.md`, the schema section, the §Autopilot row and the plan template, the session built `src/export.sh`, and the fired assert **FAILed** 3 marker checks (`evidence/fs1-planning-mutant.assert`, exit 1). **delivery-gap:** with the cross-check stripped, the fired arm FAILed and the control still PASSed (`evidence/mutation/delivery-gap-mutant/`). Every fired assert checks its behavior's own marker and rejects a sign-off-gate stop, and in the live suite every fired arm passed its gate checks before the target STOP (transcripts).
- **Confidence:** Verified (single-source)
- **Named limitation:** **decision-conflict** did not FAIL under mutation, even with the STOP stripped from every file (`evidence/mutation/decision-conflict-mutant-all-files/`). The model refuses based on the planted decision record alone, so that arm proves the behavior but can't detect a hollowed instruction. This is recorded in its `expected.md` and the CHANGELOG.

### FS2: Default per-arm budget/timeout sized from the $0.16 probe … arms hit the cap and report ERROR. Proof required: the full-suite run shows every arm finishing with `is_error:false` and recorded cost below its cap.
- **Method:** cli-output (live)
- **Evidence:** `forward-test-full/*/*/run-1.json` all have `is_error: false`. The costliest arm is $0.5292 (repair-gap fired), under the $2.00 cap (≥3.7× headroom), and there were no timeouts at 900 s.
- **Confidence:** Verified (single-source)

### FS3: `ff-retro` in a single headless turn … skips its confirm gate. Proof required: a headless `ff-retro` run on a planted `done` sandbox with material signals ends with no `retro.md`, no `phases.retro: complete`, no file changed, with the candidate table in its output.
- **Method:** cli-output (live) + executed-test (guard)
- **Evidence:** `fs3-retro/turn1.json` presents 3 candidates, and `turn1-changes.txt` is **empty**. `ac10-turn1` (an autopilot manifest) likewise wrote nothing. `retro-guard.sh` pins the gate wording.
- **Confidence:** Verified (multi-source)

**Overall confidence:** Verified (single-source), the minimum across items.

## Evidence artifacts index

| File | Kind | Backs |
|------|------|-------|
| `evidence/forward-test-full/` (`summary.md`, 14× `run-1.json`/`assert-1.log`/`changes-1.txt`) | cli-output | AC12, AC13, AC14, AC17, AC19, FS2 |
| `evidence/first-pass/` (t2/t3 batches) | cli-output | AC8 (repair-gap hand-off), history |
| `evidence/guards.log` | executed-test | AC1–AC12, AC18, AC20 |
| `evidence/eval.log` | executed-test | AC11 |
| `evidence/go.log` | executed-test | AC11 |
| `evidence/package.log` | build/static-analysis | AC11, AC18 |
| `evidence/runner-stub-tests.log` | executed-test | AC13–AC17 |
| `evidence/ac1-not-done.*`, `evidence/ac1-abandoned.*` | cli-output | AC1 |
| `evidence/fs3-retro/` | cli-output | AC2, AC3, AC5, AC6, FS3 |
| `evidence/ac7-turn1.*`, `evidence/ac7-turn2.*`, `evidence/ac7-retro.md` | cli-output | AC2, AC5, AC6, AC7 |
| `evidence/ac9-rerun.*` | cli-output | AC5, AC9 |
| `evidence/ac10-turn1.*` | cli-output | AC3, AC4, AC5, AC10, FS3 |
| `evidence/mutation/`, `evidence/fs1-planning-mutant.*` | cli-output / before-after | FS1 |
| `evidence/ac20-greps.log` | cli-output | AC20 |

## Regression risk

**Low.** Cross-referencing the plan's `## Risk register`:
- *Sandbox exercises cold-start instead of the target behavior* (Med/High): partly **materialized**
  in a different form. Assertions are marker-keyed and planning-gap/delivery-gap mutations FAIL as
  they should, but decision-conflict's fired arm can't attribute the STOP to the instruction (named).
- *Live cost / budget ERROR* (Med/Med): did not materialize (max $0.53 per session, $4.30 per suite).
- *assumption-gap headless sign-off* (Med/Med): did not materialize (disk-deterministic, both passes).
- *LLM variance* (Med/Med): not observed across two full passes (28 arm runs, all PASS), but
  `--repeat` was only exercised with a stub.
- *Guard/dist drift* (Med/Low): did not materialize (all guards green, dist in sync).
- *Real regression in a shipped STOP* (Low/High): not found. All 7 behaviors fire and stay quiet
  correctly.

Not in the register: the **Go integrity kernel** needed `retro` in two phase lists. Without it a
manifest carrying `phases.retro` would be refused by migration. This is fixed and covered by a new
test. Shared surfaces touched (`docs/manifest-schema.md`, the `ff-verify`/`ff-review` hand-off text,
the JSON schema) are additive text or enum additions; all existing guards and Go tests stay green.

## Limitations & remaining risks

- **decision-conflict attribution:** that arm cannot detect a hollowed do-not-contradict instruction
  (model common sense covers it). Named in CHANGELOG + `expected.md`.
- **WS-7 requirement-graph gap and `ff-plan` critical-path derivation** are still not forward-tested.
- **The all-rejected sentinel** (`_No accepted findings — see Rejected._`, added by the review fix) is
  verified structurally only; no live run rejected every candidate.
- **`ff-retro` on lite/bugfix/closed runs** is pinned structurally; live runs were feature/full only.
- **Forward tests are local and manual:** CI never runs them, so they must be re-run after editing a
  behavior's instruction text.
- **`--repeat N`** was exercised only with a stub `claude`; live runs used one repeat.
- **Substituted agents:** `ff-code-explorer` / `-architect` / `-reviewer` / `ff-test-runner` were not
  installed in this session, so general-purpose / Explore / Plan agents and direct execution stood in.
- **Go toolchain:** installed to the scratchpad for this run; the machine has none, so
  `integrity-conformance-guard.sh` fails locally without it (environmental; CI has Go).
- **Commit hygiene:** `docs/feature-flow/` and `.feature-flow/` are gitignored. This run's durable
  docs and evidence need a force-add if they should be committed (house practice). Evidence was
  captured against the **uncommitted** working tree at `a97b07c`.

## Verdict

**Ready for done.** All 20 acceptance criteria and all 3 failure scenarios are at
`Verified (single-source)` or better; overall `Verified (single-source)`. No waiver needed.
