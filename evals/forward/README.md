# Forward tests — proving semantic behaviors fire

`scripts/eval.sh` + `evals/fixtures/` prove the **preconditions** of feature-flow's behavioral
catches (the fixture is well-formed, the STOP instruction text exists). They cannot prove the
**firing** — that an agent reading the shipped command actually STOPs on a bad input and proceeds
on a good one. That is an LLM judgment, and it can only be observed in a **fresh process** that
loaded the edited plugin (the session that wrote an edit cannot prove it fires).

`scripts/forward-test.sh` does exactly that: each case runs in a new headless
`claude -p --plugin-dir <repo>` session against a planted sandbox, then a script checks what the
session did.

> **Local only — not CI, not shipped.** Every arm is a real, paid session (needs Claude
> credentials). CI only checks the *structure* of these cases
> (`scripts/checks/forward-test-guard.sh`). `evals/` is never packaged into the Codex dist.
> **Re-run the affected behavior after any edit to its instruction text** — nothing else will
> catch a hollowed STOP.

## Running

```
scripts/forward-test.sh                         # all behaviors, both arms
scripts/forward-test.sh delivery-gap repair-gap # a subset
scripts/forward-test.sh --repeat 3 design-gap   # flakiness check: PASS only if all 3 pass
```

Options: `--max-budget-usd X` (per session, default `$FF_FORWARD_BUDGET_USD` or 2.00),
`--timeout SECS` (per session, default 900), `--output-dir DIR` (default
`.feature-flow/forward-test-runs/<UTC>/`, gitignored), `--model M`.

Output: one `PASS|FAIL|ERROR <behavior>/<arm>` line per arm, a summary line with total cost, and
per-run `run-<i>.json` transcripts, `assert-<i>.log`, `changes-<i>.txt` (`git status` of the
sandbox after the session) plus `summary.md` in the output dir. Exit `0` only when every arm
PASSes; `1` on any FAIL/ERROR; `2` when nothing ran (no `claude` on PATH, unknown behavior, bad
option).

- **ERROR is never PASS.** Timeout, non-zero CLI exit, unparseable output, a session error
  (including hitting the budget cap), or an `assert.sh` crash all report ERROR.
- **Flaky is not green.** With `--repeat N` an arm PASSes only if all N runs pass.

Sessions run isolated: `--setting-sources project,local` (your user-level plugins and hooks do not
load), `--strict-mcp-config` (no MCP servers), `--permission-mode bypassPermissions` (safe: the
session's cwd is a throwaway temp repo).

## Case shape

```
evals/forward/<behavior>/
  fired/      the input that MUST trigger the behavior (STOP / gap line / repair / block)
  control/    the closest input that must NOT trigger it (proves specificity — a degenerate
              "always STOP" agent fails the control)
```

Each arm holds four parts:

| Part | What it is |
|---|---|
| `sandbox/` | A planted repo root: `.feature-flow.json`, `.feature-flow/<slug>/manifest.json` + artifacts, any source files. Copied into a fresh temp dir, `git init`-ed and committed as the baseline, so `git status` afterward shows exactly what the session changed. Set `autopilot` explicitly in every planted manifest. |
| `prompt.txt` | The blind prompt passed to `claude -p`. Says what to do, **never** what the expected outcome is. Both arms of a behavior normally use the same prompt — the sandbox is the variable. |
| `expected.md` | Human-readable expected observable for each arm, and any named coverage limits. Not executed. |
| `assert.sh` | `assert.sh <tmpdir> <run.json>` — `exit 0` the arm behaved as expected, `exit 1` it did not; any other exit is reported ERROR. Reads the sandbox's final state (manifest via `jq`, artifacts via `grep`, `git -C <tmpdir> status`) and, where a STOP writes nothing, the transcript's `.result` text. |
| `followup.txt` | *Optional.* The user's answer to a pause. The runner resumes the **same** session (`claude -p --resume <session_id>`) with it as a second turn, sums both turns' cost, and hands `assert.sh` the second turn's `run-<i>.followup.json`. Use it only where the behavior lives *after* an in-session pause a headless turn cannot answer. |

**Assert on the behavior's own marker, never just "nothing happened".** A fired arm can STOP for
the wrong reason — an unrelated gate (sign-off, cold-start route-back, the enforce-gate hook) —
and "no code was written" would score that as PASS while the target STOP is hollow. Each fired
`assert.sh` checks the specific signature of *its* behavior (the conflict/critical-path STOP text,
the `⚠ DELIVERY GAP` line, a new `## Repair` section, the `### FS1`/`### SM1` block below
`Verified (single-source)`), and each control asserts the behavior did *not* fire **and** the run
made normal progress.

## The behaviors

| Behavior | Command | Fired → | Control → |
|---|---|---|---|
| `decision-conflict` | `ff-implement` | do-not-contradict STOP, no source written | implements |
| `planning-gap` | `ff-implement` | critical-path STOP, no source written | implements |
| `delivery-gap` | `ff-deliver` | `⚠ DELIVERY GAP` line in `delivery.md` | no gap line |
| `assumption-gap` | `ff-clarify` | unvalidated-assumption echo, sign-off NOT recorded | sign-off recorded |
| `design-gap` | `ff-verify` | unproven `FS1` blocks `done` | reaches `done` |
| `repair-gap` | `ff-verify` (autopilot) | one `## Repair` cycle recorded | no repair, reaches `done` |
| `discovery-gap` | `ff-verify` | unproven `SM1` blocks `done` | reaches `done` |
| `implement-controller` | `ff-implement` | task controller: ledger, a subagent + review per task, a fix round on the seeded Task 2 finding | inline implement, no ledger |
| `single-architect` | `ff-design` | one architect's `architect.md`: `Recommended:` + ≥ 1 scored `Rejected:` line | `one obvious approach —`, no `Rejected:` line |
| `architect-pick` | `ff-design` + `followup.txt` picking the first alternative offered (not the recommendation) | one `## Developed on request:` section; `design.md`'s Chosen approach names the pick, the original recommendation under Rejected alternatives | followup accepts the recommendation → no re-dispatch; Chosen approach names the recommendation |
| `architect-decline` | `ff-design` on the one-approach spec + `followup.txt` declining it | `one obvious approach —`, then one `## Developed on request:` section | followup confirms → no re-dispatch; `design.md` written |
| `critic-design` | `ff-design` | the Critic flags a false repo premise as Critical, one revise cycle | `Verdict: ready`, no cycle, design complete |
| `critic-plan` | `ff-plan` | the Critic flags the plan's false premise as Critical, one revise cycle or a route to ff-design | `Verdict: ready`, no cycle, plan complete |

SM1/SM2 (v0.25.0): `evals/forward/critic-ratio.sh` compares each control arm to v0.24.0 (`488bc5d`).

**`implement-controller` is a measurement too.** Its fired arm is the v0.23.0 spec's E2E check, and
SM1 compares the two arms' main-session input tokens:
`bash evals/forward/implement-controller/sm1-ratio.sh <out>/implement-controller/fired/run-1.json <out>/implement-controller/control/run-1.json`
(PASS at ≤ 0.60). Its sessions dispatch several subagents, so run it with a higher cap —
`scripts/forward-test.sh --max-budget-usd 8 implement-controller`.

**`single-architect` is a measurement too.** Its fired arm's spec forces a persistence choice
(`src/api.sh` runs as a fresh process per request), so a competent architect genuinely forks
between counter-storage mechanisms; the control arm's spec has one sane implementation. SM1
compares the fired arm's mean `total_cost_usd` and mean wall time (`run-<i>.wall`) against the same arm
run on the pre-v0.24.0 three-architect fan-out (`e95c4de`), both with `--repeat 2`:
`bash evals/forward/single-architect/sm1-ratio.sh <out>/single-architect/fired <baseline out>/single-architect/fired`
(PASS at cost ≤ 0.90; wall time recorded, not gated — the amended SM1) — see the script's header for
the baseline worktree steps.

`architect-pick`'s design check matches the words that tell the picked approach's name from the
recommendation's (`distinct` in `lib.sh`) — a heuristic: a Chosen approach that only mentions the
picked mechanism to dismiss it would pass.

Coverage limit (named, not silent): `discovery-gap` covers WS-7's `SM<n>` half only; the
requirement-graph → Outcome-gate gap in `ff-plan` is not forward-tested.

## Adding a behavior

1. `mkdir -p evals/forward/<behavior>/{fired,control}` and fill the four parts in each arm.
2. Add `<behavior>` to the list in `scripts/checks/forward-test-guard.sh`.
3. Run `scripts/forward-test.sh <behavior>` until both arms PASS; then `--repeat 3` once.

## From a retrospective finding

An `ff-retro` finding whose recommended owner is **regression / forward test** states its proposed
validation as **Fired input / Expected outcome / Control input**. Those map 1:1 onto a new case:
fired input → the fired arm's sandbox + `prompt.txt`, expected outcome → `expected.md` + the fired
`assert.sh`, control input → the control arm. `ff-retro` never creates the case itself; converting
a finding is ordinary, user-initiated work.
