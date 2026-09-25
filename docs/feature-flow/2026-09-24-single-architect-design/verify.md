# Verify: one architect in ff-design instead of a three-way fan-out

**Track:** feature
**Tier:** full
**Date:** 2026-09-25 (fifth verify pass; passes 1–4 kept under `evidence/verify-1/`…`verify-4/`, pass 5 under `evidence/verify-5/`)
**Revision:** `1663391d96edb0abda9b743342f0cdb70f9c5e78`
**Verified by:** `ff-test-runner` (executed) — evidence below is real command output.

## Commands run (pass 5)

| Command | Kind | Status | Evidence |
|---------|------|--------|----------|
| `bash scripts/checks/<guard>.sh` × 28 | build/static-analysis | pass (27) / fail (1, expected) | exit 0 ×27 incl. `single-architect-guard.sh`, `forward-test-guard.sh`; `integrity-conformance-guard.sh` exit 1 — `FAIL: Go toolchain is required for WP1 conformance`, `command -v go` exit 1 — `evidence/verify-5/cli-output-1…`, `…-2…` |
| `bash scripts/eval.sh` | executed-test | pass | exit 0 — every fixture PASS — `evidence/verify-5/cli-output-3-eval-harness.md` |
| versions ×3; `diff -r commands dist/…`; `diff` of `ff-code-architect.md`, `codex-tools.md`, `manifest-schema.md` | build/static-analysis | pass | `0.24.0` ×3; diffs exit 0 — `evidence/verify-5/cli-output-4-version-dist-parity.md` |
| `FF_FORWARD_KEEP=1 scripts/forward-test.sh --repeat 2 … single-architect` | cli-output (paid) | pass | exit 0 — fired PASS ×2, control PASS ×2 — `evidence/verify-5/e2e-1-single-architect.md` |
| `FF_FORWARD_KEEP=1 scripts/forward-test.sh … architect-pick architect-decline` (two-turn) + `architect-pick` re-run | cli-output (paid) | fail | 3/4 PASS, then pick re-run 1/2 PASS — `architect-pick/fired` FAIL both times — `evidence/verify-5/e2e-2-ac5-pick-decline.md`, `evidence/verify-5/forward-pick-rerun/` |
| `sm1-ratio.sh <pass-5 fired> <pass-3 v0.23.0 fired>` | cli-output (measurement) | pass | exit 0 — `cost … ratio=0.876 (<= 0.90)`, `wall v0.24.0=133s v0.23.0=69.5s ratio=1.914 (recorded, not gated)`, `SM1 PASS` — `evidence/verify-5/cli-output-5-sm1-ratio.md` |

Paid-run spend: passes 1–3 $12.09 · pass 4 $1.12 · pass 5 $6.13 — **$19.34** in total.

## Evidence coverage matrix

| Detected surface | Expected kind | Ran? | Result | Notes (gap / N/A reason) |
|------------------|---------------|------|--------|--------------------------|
| `scripts/checks/*.sh` | build/static-analysis | yes | pass | Go-only guard fails for the absent toolchain, as on every run of this repo |
| `scripts/eval.sh` fixtures | executed-test | yes | pass | |
| `scripts/forward-test.sh` (headless `claude -p`) | cli-output | yes | pass (E2E) / fail (SM1) | |
| http/api, db, e2e/browser, logs | — | — | N/A | not detected — a plugin of prose + bash, no server, DB or UI |

## Contract mapping

### AC1: `ff-design` dispatches exactly one `ff-code-architect` per design (model `models.architect`), no fan-out, no agent-count setting read
- **Method:** build/static-analysis + cli-output
- **Evidence:** `single-architect-guard.sh` exit 0; every v0.24.0 forward session's transcript shows one `Agent` dispatch (fired run 1: `agent-ae59e09…`, run 2: `agent-a67c1f09…`), against three in each v0.23.0 baseline
- **Confidence:** Verified (multi-source)

### AC2: The architect returns the recommended design plus 1–3 genuinely different scored rejected approaches — or `one obvious approach — <why>` with no invented alternatives
- **Method:** cli-output (single-architect ×2 per arm; 6 two-turn arms) + build/static-analysis
- **Evidence:** pass 5 fired 2/2 `ok: 2 Rejected: line(s)`, `ok: every Rejected: line carries the three scores`, `ok: no Rejected: line loses to the spec`; control 2/2 `ok: control arm says one obvious approach`, `ok: no Rejected: line`; `ff-design`'s screening rewrote a spec-breaking alternative as `Dropped (contradicts the spec): fixed-window counter — spec ## Problem: "…rolling window"` (`verify-5/forward-ac5/architect-pick/fired/run-1.feature-flow/rate-limit/architect.md:67`); guard pins the contract
- **Confidence:** Verified (multi-source)

### AC3: `agents/ff-code-architect.md` states the contract (three lenses, only the best in full, the rest briefly; no sibling wording)
- **Method:** build/static-analysis
- **Evidence:** guard exit 0 (`## Weighing approaches`, `never a strawman`, `**Report budget.**`, `**Last check before returning.**`, lacks `sibling`)
- **Confidence:** Verified (single-source)

### AC4: `architect.md` written before the choice pause (`artifacts.architect`, ephemeral); a re-entered design phase with it present asks again without re-dispatching
- **Method:** cli-output + build/static-analysis
- **Evidence:** all 4 forward sessions `ok: architect.md written` before stopping at the pause; guard pins the Re-entry check, the re-run discard and the post-pick resume
- **Confidence:** Verified (multi-source) — the re-entry half rests on the guard alone (not exercised live)

### AC5: The choice pause (recommended first, rejected as options, confirm-only for one obvious approach); a rejected pick re-dispatches once, appended; in-session in both modes
- **Method:** cli-output (two-turn forward tests) + build/static-analysis
- **Evidence:** `architect-decline/fired` PASS — `one obvious approach`, then exactly one `## Developed on request:` section (the once-only re-dispatch + append, live); `architect-decline/control` PASS — no re-dispatch, `design.md` written; `architect-pick/control` PASS ×2 — no re-dispatch, Chosen approach names the recommendation. `architect-pick/fired` FAIL ×2 without reaching the re-dispatch: (1) the follow-up "the first approach you rejected" was ambiguous against a `Dropped` line, and `ff-design` asked which was meant; (2) after rewording, the architect reported `one obvious approach` for the rate-limit spec (every other shape broke a spec clause), and `ff-design` said there was no alternative to pick and offered re-clarify / object / confirm
- **Confidence:** Partially verified — the pause, the accept, confirm and decline paths and the re-dispatch + append are proven live; the rejected-*pick* branch is structural only
- **Gap:** the `rate-limit` fixture no longer forks reliably under the no-strawman rules, so the pick branch was never reached; the product's replies in both failures were correct
- Evidence gap accepted by user (2026-09-25): "Waive AC5 pick, finish" — the live pick branch runs the same re-dispatch and append that `architect-decline` proved live, and the guard pins the wording.

### AC6: the matrix scores every approach considered; devil's advocate, FS<n>, decision.md unchanged
- **Method:** build/static-analysis
- **Evidence:** guard AC6 lines; `design-tradeoff-guard.sh`, `decision-record-guard.sh` exit 0
- **Confidence:** Verified (single-source)

### AC7: `architectAgents` removed; every "architects fan out" description updated
- **Method:** build/static-analysis
- **Evidence:** guard exit 0 (defaults, Known keys, README, frontmatter, templates, KB schema, SKILL)
- **Confidence:** Verified (single-source)

### AC8: new guard; every guard and eval exit 0 (Go-only excepted); 0.24.0 synced; dist repackaged
- **Method:** build/static-analysis + executed-test
- **Evidence:** 27/28 guards exit 0; eval exit 0; `0.24.0` ×3; dist diffs empty
- **Confidence:** Verified (multi-source)

### FS1: The single architect pads its report — develops every option in full, or lists strawman alternatives — so the cost saving vanishes or the user picks between fake options
- **Method:** cli-output + build/static-analysis
- **Evidence:** pass 5 — no `Rejected:` line cites the spec in any of 6 kept reports; the one spec-breaking alternative the architect produced was screened to `Dropped (…)` by `ff-design`; reports 399–619 words
- **Confidence:** Verified (multi-source)

### FS2: session drops between writing `architect.md` and recording `artifacts.architect` → re-entry misses the report
- **Method:** build/static-analysis
- **Evidence:** guard pins the Re-entry check reading the manifest pointer **or** `<run dir>/architect.md`
- **Confidence:** Verified (single-source)

### FS3: a rejected pick's appended report sits below the first, and `design.md` derives from the wrong one
- **Method:** build/static-analysis
- **Evidence:** guard pins "That appended report is the one the design and decision writes below derive from."
- **Confidence:** Verified (single-source)

### E2E: `scripts/forward-test.sh single-architect` — fired arm → one recommended design + ≥ 1 scored rejected approach; control arm → `one obvious approach`, no rejected approaches
- **Method:** cli-output
- **Evidence:** exit 0 — fired PASS ×2 ($0.403 / $0.423), control PASS ×2 ($0.264 / $0.307) — `evidence/verify-5/e2e-1-single-architect.md`
- **Confidence:** Verified (single-source)

### SM1: The fired arm's session cost is ≤ 60% of the same arm run against v0.23.0 (`total_cost_usd`)
- **Method:** cli-output (measurement, n = 2 per side; wall from `run-<i>.wall`). SM1 as amended and re-signed by the user 2026-09-25
- **Evidence:** `sm1-ratio.sh` exit 0 — cost $0.413 vs $0.471, **ratio 0.876** (≤ 0.90); wall 133 s vs 69.5 s, **ratio 1.914** (recorded, not gated); `SM1 PASS`
- **Confidence:** Verified (single-source)
- **Note:** the ratios moved with each tightening of the architect's rules — cost 0.72 → 0.88, wall 1.38 → 1.91 (pass 3 → pass 5): the architect now spends 96–101 s before writing its report (27–84 s in pass 3)

## Pass 3 changes (user-directed, "Cut time, then amend" + "Follow-up turn in harness")

The architect writes its own report to the path `ff-design` names (`Write` tool; no `Edit`/`Bash`)
and returns only markers and a summary; the choice pause points to `architect.md`. The harness gained
an optional `followup.txt` turn, `run-<i>.wall` and `FF_FORWARD_KEEP=1`; two new behaviors,
`architect-pick` and `architect-decline`; `sm1-ratio.sh` reports ratio-of-means for cost and wall.

## Repair

Autopilot repair-and-re-verify cycle (verify 1; full tier; E2E control arm a captured non-success).
- **What failed:** E2E control arm — `Rejected:` lines on a one-approach spec.
- **Fix:** `agents/ff-code-architect.md` defined "genuinely different" (structure-changing and within
  every constraint; a detail variant belongs in the design; nothing passes → `one obvious approach`).
- **Outcome:** control arm still FAIL (`evidence/verify-1/e2e-2-repair-reverify.md`). One cycle; no second.

**Gap fix directed by the user (2026-09-25, option (a)).** The session transcripts showed v0.23.0's
orchestrator capping each architect at "~400 words", while v0.24.0's brief had no cap and seeded
candidate approaches that came back as `Rejected:` lines. Fix: a design-level **report budget** (~400
words, ~800 multi-module), a **last check** deleting self-declared non-viable `Rejected:` lines, and
`ff-design` never seeding candidate approaches. Recorded in the plan's Decisions; pinned in the guard.

Both fixes edited code after review was stamped (`a21a956`): review's revision is stale, and the
done-transition re-runs review once (Stale-phase re-run cycle) before `done`.

## Regression risk

**Low–Medium.** The plan's risk register named design quality from one architect (spec Assumption 2):
after the fix the reports are focused and the alternatives real, so it did not materialise in the
forward test; it is unmeasured on a realistic codebase. What did materialise is outside the register:
the design phase is 1.4–1.9× **slower** on wall time on this fixture (passes 3–5), since parallelism is lost. The
change touches prose contracts only (no hooks or libs); every full-tier design phase runs through it.
