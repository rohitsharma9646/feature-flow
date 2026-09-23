# Spec: Structured retrospective (ff-retro) + forward-testing of semantic behaviors

**Created:** 2026-09-23
**Track:** feature
**Status:** signed-off

## Problem

feature-flow has no loop that turns **its own safeguard failures** into fixes. When a gate is
bypassed, a STOP misfires, or a run hits friction, the lesson lives only in a chat transcript.
KB capture records *project* decisions, not whether the *workflow's* safeguards worked. The
need: at the end of a run, systematically classify what the safeguards did and route each
lesson to the one place that should own the fix.

Separately, the 7 behavioral catches named as "Known coverage gap" in `CHANGELOG.md` (do-not-
contradict STOP, critical-path STOP, DELIVERY GAP line, assumption echo, FS<n> block, one-cycle
repair, SM<n>/requirement-graph gap) are only *structurally* guarded. CI's blocking eval gate
proves the instruction text exists, not that an agent actually STOPs on a fired input and
PROCEEDs on a control. Today that firing is proven by ad hoc, uncommitted, manual fresh-session
self-runs (`.feature-flow/ws*-selfrun-*`, scratchpads) that cannot be re-run after an edit —
so a hollowed STOP can regress silently.

## Expected outcome

1. After any finished run, `/feature-flow:ff-retro` proposes a table of material events, each
   classified by what the relevant safeguard did (worked / failed / missing / ambiguous /
   bypassed) and routed to one owner; the user accepts/edits/rejects each; accepted findings are
   written to `retro.md`. Nothing else is changed — fixes stay separate, user-initiated work.
2. `scripts/forward-test.sh` re-proves all 7 behaviors on demand: for each behavior it runs a
   **fired** and a **control** case in fresh headless Claude sessions against the working-tree
   plugin and reports PASS/FAIL/ERROR per arm, with cost and transcripts. The "manual self-run"
   caveat in CHANGELOG/CI is replaced by "covered by the local forward-test runner (not CI)".

## Solution approaches considered

**Retro shape** (user-picked):
- **Chosen — optional `ff-retro` post-terminal command** (clone of the `ff-deliver` shape: done-
  gated, never autopilot-chained, `currentPhase` stays `done`), focused on the *workflow's*
  safeguards, confirm-gated. No new pause on normal runs; no overlap with KB.
- Rejected — step inside the done-transition next to KB capture: guarantees retros but adds a
  second cross-turn pause to every run and blurs into KB capture.
- Rejected — repo-internal runbook only: loses the value for plugin users' runs.

**Forward-test automation** (user-picked):
- **Chosen — scripted local runner** launching a fresh headless session per case
  (`claude -p --plugin-dir <repo>`), which structurally solves "the authoring session can't prove
  the edit fires". Local-only (credentials + token cost), not CI.
- Rejected — fixtures + manual runbook: cheapest but stays manual and unrepeatable in practice.
- Rejected — runner in CI: secrets, cost, and LLM non-determinism inside a blocking gate.

**Coverage:** all 7 known-gap behaviors this run (user-picked) over framework + 2 pilots.
**Audience:** forward-testing is feature-flow-internal (`evals/` + `scripts/`), not packaged into
the Codex dist and not a user command (user-picked). `ff-retro` is user-facing.

**Link between the two:** kept loose on purpose — a retro finding routed to "regression / forward
test" carries its proposed validation in the same shape as a forward-test case (fired input +
expected outcome); the retro never scaffolds files itself.

## Assumptions (WHAT-changing)

| Statement | Confidence | Basis / evidence | If-wrong impact | Validation-required |
|---|---|---|---|---|
| A headless `claude -p --plugin-dir <repo>` process loads the working-tree plugin and executes `/feature-flow:*` commands | high | Probe 2026-09-23: fresh process ran `/feature-flow:ff-list` in an empty git dir → correct "No feature-flow runs found", `is_error:false`, $0.16, 5 turns | Runner approach collapses to manual runbook (AC12–AC16 change) | n |
| Each of the 7 behaviors leaves a deterministic on-disk / output signature that distinguishes STOP-or-fire from PROCEED (e.g. manifest phase not advanced, `⚠ DELIVERY GAP` line present, `## Repair` section count) so each arm's assertion is a script, not an LLM judgment | med | Prior self-run logs describe observable outcomes per behavior; not yet checked for all 7 | Some arms need an LLM-graded or output-text assertion; AC12's "executable assertion" weakens for those | y |
| On-disk artifacts (override/waiver lines, `## Resolution`, `## Repair`, gaps, Critical findings) plus user-supplied notes are enough to surface material events — the retro has no transcript access | med | Every gate in §Autopilot leaves a durable on-disk record by design | Friction that left no disk trace is only captured if the user names it in notes (accepted limitation) | n |

## Constraints

- Write-only doctrine: no `git add`/`commit` anywhere; `ff-retro` writes only `retro.md` + manifest.
- Sign-offs, confirmations and override/waiver lines come only from the user's words; autopilot never answers the retro confirm gate.
- Categorical classifications only — no numeric scores (§Evidence doctrine).
- Canonical-contract house style: new `## Retrospective` section in `docs/manifest-schema.md`; commands reference it by name, never restate.
- `currentPhase` enum is not extended; `phases.retro` is post-terminal like `deliver`.
- Codex parity for shipped files (`ff-retro`, template, schema/SKILL/README edits); forward-test assets are NOT shipped.
- Forward-test runner never runs in CI and must never claim coverage it did not observe (ERROR ≠ PASS).
- Must not rely on this authoring session to prove firing — only fresh processes count.

## Edge cases

- `ff-retro` on a non-done run (in progress, abandoned) → STOP naming the phase; nothing written.
- `ff-retro` on a closed run → allowed (retro after close is legitimate); `closedAt` untouched.
- Lite tier and bugfix track → allowed; reads whichever artifacts exist; missing ones are "not available", never invented.
- Zero material events and no notes → gate shows "no material events"; on confirm writes `retro.md` stating `_No material events._`.
- User rejects every candidate → `retro.md` written with the rejected count and no findings (the retro happened; that is the record).
- Duplicate: `ff-retro` again on the same run → re-run guard asks before overwrite.
- Retro notes that describe the feature itself ("retro didn't catch X") → treated as ordinary friction events.
- Runner: `claude` missing → exit 2, nothing run. Unknown behavior name → exit 2 listing valid names. Empty selection → all 7.
- Runner: budget cap hit, CLI non-zero, or timeout → arm = ERROR (never PASS); suite exit non-zero.
- Runner: an arm passes on some repeats and fails on others (`--repeat N`) → FAIL (flaky is not green).
- Runner: a fired arm genuinely fails (a real regression in a STOP) → reported FAIL; fixing the underlying behavior is in scope only if cheap, otherwise surfaced as a verify gap for the user.

## Non-goals

- `ff-retro` applying any improvement (editing skills, instructions, guards, tests) or writing KB entries.
- Scaffolding forward-test cases from retro findings.
- Running forward tests in CI, or as a user-facing capability for plugin users' own skills.
- Transcript mining for the retro.
- A machine-enforced (hook) gate for retro; it stays a prose confirm gate.
- Multi-run roadmap/epic layer; append-only run log (separate, demand-gated items).

## Acceptance criteria

**Retrospective (`ff-retro`)**
- [ ] AC1: `/feature-flow:ff-retro <slug>` on a run whose `currentPhase` is not `done` (including an abandoned run) STOPs with a message naming the current phase and writes no file and no manifest change.
- [ ] AC2: On a `done` run (either track, either tier, closed or not), `ff-retro` resolves upstream artifacts only via `manifest.artifacts.<name>` pointers and proposes candidate events from these on-disk signals when present: user override/waiver lines, review `## Resolution`, verify `## Repair`, evidence gaps, Critical findings — plus any free-text notes in `$ARGUMENTS`.
- [ ] AC3: Every proposed candidate carries all nine fields — event, expected, observed evidence (a path or quoted line), impact, safeguard, safeguard result ∈ {worked, failed, missing, ambiguous, bypassed}, generalizability ∈ {one-off, repo-specific, reusable}, recommended owner ∈ {repo instructions, run artifacts, feature-flow command/skill, feature-flow reference doc, guard/validator script, regression/forward test, new skill, no change}, proposed validation — with no numeric score.
- [ ] AC4: `docs/manifest-schema.md` §Retrospective states a materiality test, and `ff-retro` proposes only events that pass it.
- [ ] AC5: `ff-retro` ends its turn presenting the candidates and writes nothing until the user accepts, edits, or rejects each one; this holds in autopilot.
- [ ] AC6: After confirmation, `retro.md` is written from `templates/retro.md` at the durable-resolved path with only accepted findings plus a rejected count; `artifacts.retro` and `phases.retro = {status: complete, artifact}` are set; `currentPhase` stays `done`; no other file is created or modified.
- [ ] AC7: With zero candidates and no notes, the gate says "no material events" and, on confirm, `retro.md` contains `_No material events._`.
- [ ] AC8: Autopilot never chains into `ff-retro`; the feature- and bugfix-terminal hand-off messages name `/feature-flow:ff-retro` as an optional next step alongside `ff-deliver`.
- [ ] AC9: Running `ff-retro` on a run whose `phases.retro.status` is `complete` asks for confirmation before overwriting.
- [ ] AC10: A retro finding whose owner is "regression/forward test" states its proposed validation as a fired input + expected outcome (+ control input when applicable), matching the case shape documented in `evals/forward/README.md`.
- [ ] AC11: Wiring: `docs/manifest-schema.md` has `## Retrospective`; `retro` is in the durable-eligible artifact list; `phases.retro` is accepted by `schemas/manifest-v1.schema.json` (phases object + all four track enums); SKILL.md and README list `ff-retro`; new `scripts/checks/retro-guard.sh` pins these plus Codex dist parity; all `scripts/checks/*.sh` and `scripts/eval.sh` exit 0.

**Forward-testing**
- [ ] AC12: `evals/forward/<behavior>/{fired,control}/` exists for each of the 7 known-gap behaviors, and each arm contains a planted run sandbox, a prompt that does not state the expected outcome, a declared expected outcome, and an executable assertion.
- [ ] AC13: `scripts/forward-test.sh [behavior...]` runs each selected arm in a fresh temp copy of its sandbox via a new `claude -p --plugin-dir <repo>` process, then runs the arm's assertion in that copy; prints one `PASS|FAIL|ERROR <behavior>/<arm>` line per arm and a summary; exits 0 iff every arm is PASS.
- [ ] AC14: Each arm's spend is capped via `--max-budget-usd` (configurable, with a default); the runner prints per-arm and total cost; a budget stop, non-zero CLI exit, or timeout marks the arm ERROR, never PASS.
- [ ] AC15: With `claude` not on PATH, or an unknown behavior name, the runner exits 2 with an explanatory message and runs no arm.
- [ ] AC16: `--repeat N` runs each arm N times; the arm is PASS only if all N runs pass.
- [ ] AC17: The runner writes each arm's transcript and a summary file to an output directory (default under a gitignored path).
- [ ] AC18: The runner is not under `scripts/checks/`; new `scripts/checks/forward-test-guard.sh` fails if any of the 7 behaviors lacks either arm or any of the four arm parts, and `evals/forward/` is absent from the Codex dist.
- [ ] AC19: A full-suite run (`scripts/forward-test.sh`, all 7 behaviors) produces 14 PASS lines — every fired arm shows its STOP/fire signature and every control arm PROCEEDs — and its summary + transcripts are kept as this run's verify evidence.
- [ ] AC20: `CHANGELOG.md` (new entry), the `.github/workflows/ci.yml` eval comment, and the 7 behaviors' coverage-gap wording state that semantic firing is covered by the local forward-test runner (still not CI); the `scripts/eval.sh` header no longer says non-blocking.

## Success metrics

none

## Requirement graph

| AC | Depends on |
|----|------------|
| AC5 | AC3 |
| AC6 | AC5 |
| AC7 | AC5 |
| AC10 | AC3 |
| AC13 | AC12 |
| AC14 | AC13 |
| AC16 | AC13 |
| AC17 | AC13 |
| AC18 | AC12 |
| AC19 | AC13 |
| AC20 | AC19 |

## Sign-off

**User signed off:** yes (2026-09-23)

Assumption 2 acknowledged by user as staying open (2026-09-23) — carried to the plan as a `**Validates:** Assumption 2` task.

> A spec without sign-off does not proceed to **design, planning, or implementation** —
> `/feature-flow:ff-design`, `/feature-flow:ff-plan`, and `/feature-flow:ff-implement` each stop and
> route back to `/feature-flow:ff-clarify` if this reads `no` (implement is the hard backstop). A
> waived review is recorded explicitly: "sign-off waived by user (date)" — never assumed.
