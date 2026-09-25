# Spec: a Critic inside the design and plan phases

**Created:** 2026-09-25
**Track:** feature
**Status:** signed-off

## Problem

The design and plan phases are the most important stages of the pipeline. The user does not want a
run to move forward on a weak or incomplete architecture or plan. Today nothing independent checks
either one.

- `ff-clarify`'s red-team and `ff-design`'s devil's-advocate pass are self-critiques: the
  orchestrator runs them in the same context that produced the work.
- `ff-plan` has no adversarial pass at all. Its planning intelligence (dependency graph, critical
  path, risk register) and the No-Placeholders check derive structure from the plan's own tasks.
  Nothing challenges the plan's decisions, its completeness, or its fit to the design.
- The first independent reviewer, `ff-review`, runs after the code is written, when a design or
  plan defect is at its most expensive.

## Expected outcome

Every full-tier design phase and every plan phase ends with an independent **Critic** review of what
it produced. The review happens inside the existing phase; no new step or command is added. The
Critic:
- challenges assumptions
- finds gaps against the signed contract
- checks claims against the real repo
- names risks

Critical findings are fixed before the phase completes: the orchestrator revises, and the Critic
re-checks once. A Critical that survives the re-check stops the run and shows the user. Important
findings are fixed or recorded as rulings. The user sees a one-line Critic verdict in each phase's
closing message, and the full critique is on disk.

## Solution approaches considered

- **Chosen — adapt the user's `critical-plan-review` skill into a plugin agent (`ff-critic`).**
  - Distill the skill's process:
    - basis labels
    - an unverified load-bearing assumption is a finding
    - do the arithmetic
    - verify premises against the repo
    - calibrated severity
    - no noise
  - Give it feature-flow's output conventions: a short report written to a named path,
    fixed marker lines, Critical/Important, and a check against the signed contract.
  - It ships with the plugin, so it works for every user and on Codex.
- **Rejected — invoke the user's skill as-is.**
  - It lives in the user's `~/.claude`, so it does not ship with the plugin or reach Codex.
  - Its 10-section, 2,500–4,000-word human report has no machine-readable verdict to gate on and
    does not check against a signed spec.
  - Its own benchmark: 234 s vs 124 s. Its grader notes flag its length and repetition.
- **Rejected — strengthen the orchestrator's self-critique, with no new agent.** This is the
  cheapest and fastest option. But the same context that wrote the design would critique it, and
  independence is the point.

## Assumptions (WHAT-changing)

| Statement | Confidence | Basis / evidence | If-wrong impact | Validation-required |
|---|---|---|---|---|
| An independent Critic catches real design/plan defects that the current pipeline lets through before implement (self-critique now; `ff-review` only after the code exists) | med | The user's skill benchmark: 100% vs 74% on planted flaws. KB "screen at the orchestrator": a self-check misses what its author believes. | The Critic is pure cost and time and the feature fails its purpose. | y |
| An Opus Critic fits the budget (≤ 1.35× cost and ≤ +90 s wall per phase on a clean fixture) | low | Today's design phase is ~$0.41 and ~133 s on the fixture, and the Opus main session is ~80% of it. An Opus leaf is the costliest option. | SM1/SM2 fail. The user amends the thresholds or sets `models.critic` to `sonnet`. | n |
| One revise-and-re-check cycle is enough for most Critical findings (they are fixable within the chosen approach) | med | `ff-review`'s single fix cycle is the precedent and has held. | Frequent Critical stops in autopilot. | n |

## Constraints

- **No new phase or command.** The Critic runs inside `ff-design` and `ff-plan`. `currentPhase`
  values, the phase list, the progress strip, and every existing gate are unchanged: sign-off,
  choice pause, do-not-contradict STOP, and the devil's-advocate pass stays.
- **Dispatch.** Exactly one Critic dispatch per phase, plus at most one re-check. No fan-out.
- **The Critic is a leaf.**
  - It never edits code or the artifacts it reviews: no `Edit`, no `Bash`.
  - Its only write is its own report, to the path the caller names.
  - It returns marker lines, each on one physical line.
- **Report shape.** A short report (on the order of the architect's ~400–800-word budget), not a
  multi-section human report. Severity is feature-flow's Critical / Important, not a third
  vocabulary.
- **User-authored lines.** The Critic never authors a waiver, sign-off or override.
  `Critic finding accepted by user (<date>): <reason>` is user-authored only; autopilot never writes
  it.
- **Codex parity.** On Codex the Critic runs as a native subagent, or inline when subagents are
  unavailable. `dist/` is repackaged and stays byte-identical to its sources.
- **Safety and green checks.** No commits, and the user's `~/.claude/skills/critical-plan-review`
  is left untouched. Every guard and `scripts/eval.sh` exits 0; the Go-only guard is excepted, as on
  every run of this repo.

## Touchpoints

- `agents/ff-critic.md` — new leaf agent
- `commands/ff-design.md` — the Critic step after the pick and devil's-advocate pass; also the
  v0.24.0 re-entry screen fix
- `commands/ff-plan.md` — the Critic step after the plan draft, both tracks
- `docs/schema/` — a canonical Critic contract (new topic file) and `autopilot.md` (a new Mandatory
  pauses row)
- `docs/manifest-schema.md` — artifact pointer(s), Known keys, Topic index
- `config/defaults.json` — `models.critic`
- `skills/feature-flow/SKILL.md` — design description, agent list (the `ff-code-architect`
  read-only carve-out from v0.24.0 and the new `ff-critic`)
- `skills/feature-flow/references/codex-tools.md` — Agent Mapping
- `scripts/checks/` — new `critic-guard.sh`, plus `single-architect-guard.sh` for the re-entry pin
- `evals/forward/` — new Critic behaviors (design + plan, fired + control) and a cost/wall ratio
  script
- `README.md`, `CHANGELOG.md`, version files, `dist/`

## Edge cases

- **The Critic finds nothing:** `ready` verdict, no revise cycle, one-line summary, the phase
  completes.
- **Only Important findings:** each is fixed or recorded as a ruling. No stop.
- **A finding asks for work outside the signed spec** (a non-goal, beyond scope, a different WHAT):
  the orchestrator screens it out, records it as dropped with the clause it contradicts, and never
  applies it.
- **A finding says the spec itself is wrong:** STOP and route to `/feature-flow:ff-clarify`. The
  spec is never changed silently.
- **A design Critical whose only fix is a different approach:** STOP and ask the user. The
  orchestrator never switches the chosen approach on its own.
- **The re-check reports a Critical that is still open, or a new one:** Critical stop (cross-turn,
  both modes).
- **Dispatch fails, the report is missing, or it has no verdict line:** the orchestrator runs the
  critique inline once, as Codex does without subagents, and says so. The step is never skipped
  silently.
- **Session drops mid-phase:** re-entry reuses the critique already on disk (no re-dispatch). A
  cycle that was already recorded counts as spent.
- **A confirmed re-run of the phase:** the previous critique is discarded and the Critic runs again.
- **Lite tier:** no design or plan phase, so no Critic.
- **Full-tier bugfix:** the plan Critic checks against the signed diagnosis and the RED→GREEN
  order.
- **Step-by-step mode:** the same revise-once behavior (it is phase work, not a skipped gate). The
  Critical stop is cross-turn in both modes.

## Non-goals

- A new pipeline phase, command, or `currentPhase` value.
- Replacing the devil's-advocate pass, the red-team pass, `ff-review` or planning intelligence. The
  Critic complements them.
- A Critic in explore, clarify, implement, review or verify.
- Several critics or a critic fan-out, or a second revise cycle.
- Numeric quality scores.
- Changing the user's `~/.claude/skills/critical-plan-review`.

## Acceptance criteria

- [ ] AC1: `agents/ff-critic.md` exists.
  - Its `tools:` line is `Glob, Grep, LS, Read, Write, NotebookRead, WebFetch, WebSearch, TodoWrite`
    (no `Edit`, no `Bash`).
  - Its contract states all of: basis labels (verified / from the contract / inferred); an
    unverified load-bearing assumption is a finding; do the arithmetic; verify claims against the
    repo read-only; calibrated Critical / Important severity; the no-noise rule; a report budget;
    and a report written to the caller-named path.
  - Its return is marker lines only, each on one physical line: a `Verdict:` line (`ready` or
    `revise`), one line per finding with its severity and ID, or a single no-findings line.
- [ ] AC2: `config/defaults.json` has `models.critic` set to `"opus"`, documented in the Known keys.
  `ff-design` and `ff-plan` pass it as the Critic's model.
- [ ] AC3: In a full-tier `ff-design` run, exactly one `ff-critic` is dispatched.
  - It runs after the user's pick, the do-not-contradict STOP and the devil's-advocate pass.
  - It is given the signed spec, the explore findings and the chosen design (including the
    trade-off matrix and `FS<n>` list).
  - `phases.design.status` becomes `"complete"` only once no Critical finding is open.
- [ ] AC4: In every `ff-plan` run (feature and full-tier bugfix), exactly one `ff-critic` is
  dispatched after the plan draft and its No-Placeholders self-check.
  - It checks the plan against the signed spec + design (feature) or the signed diagnosis (bugfix).
  - `phases.plan.status` becomes `"complete"` only once no Critical finding is open.
- [ ] AC5: Critical findings in either phase trigger at most one revise cycle.
  - The orchestrator revises the design or plan, then re-dispatches the Critic once.
  - The cycle is recorded in a section of the critique report on disk (the durable one-cycle
    record).
  - A Critical still open after the re-check is a cross-turn **Critic stop** in both modes. The stop
    names the findings. The run resumes when the user fixes or redirects and re-runs the phase, or
    writes `Critic finding accepted by user (<date>): <reason>`, which is never self-authored.
  - Important findings are each fixed or recorded as a `**Ruling:**` line and never stop the run.
- [ ] AC6: The orchestrator screens every finding against the signed contract before applying it.
  - A finding that asks for out-of-scope or non-goal work is rewritten as
    `Dropped (contradicts the spec): <finding> — <clause>` and not applied.
  - A finding that says the spec itself is wrong stops the run and routes to
    `/feature-flow:ff-clarify`.
  - A design Critical whose fix is a different approach stops the run and asks the user, and is
    never applied silently.
- [ ] AC7: Each critique report's path is recorded in a `manifest.artifacts` pointer, and the
  phase's closing message contains one `Critic:` line with the verdict and the Critical / Important
  counts.
- [ ] AC8: Re-entry and re-runs.
  - A phase re-entered after a session drop with the critique report on disk reuses it and does not
    re-dispatch.
  - A recorded revise cycle counts as spent.
  - A confirmed re-run of the phase discards the old critique.
- [ ] AC9: Documentation and packaging.
  - `docs/schema/autopilot.md` has a Mandatory-pauses row for the Critic stop.
  - `docs/manifest-schema.md` documents the new pointer(s) and topic.
  - `skills/feature-flow/SKILL.md` and `references/codex-tools.md` list `ff-critic`, and describe
    both it and `ff-code-architect` as never editing code and writing only their own report.
  - README and CHANGELOG describe the Critic.
  - The version is `0.25.0` in all three version files, and `dist/` is repackaged.
  - A new `scripts/checks/critic-guard.sh` pins AC1–AC9's wording.
  - Every guard (Go-only excepted) and `scripts/eval.sh` exit 0.
- [ ] AC10: `ff-design`'s Re-entry check re-runs the (idempotent) **Screen the rejected list** before
  the choice pause. Lines already `Dropped (contradicts the spec):` stay as they are. The rule is
  pinned in `single-architect-guard.sh`.

## End-to-end check

- [ ] E2E: `scripts/forward-test.sh critic-design critic-plan` exits 0.
  - **Fired arms** carry a seeded defect the current pipeline lets through. The Critic reports it as
    Critical, the orchestrator revises, the re-check has no open Critical, and the phase completes
    with a `Critic:` line.
  - **Control arms** are sound. The Critic reports `ready`, no revise cycle runs, and the phase
    completes.

## Success metrics

- [ ] SM1: On the `critic-design` control arm (clean design, no revise cycle), mean session cost
  ≤ 1.35× and mean wall time ≤ +90 s against the same arm run on v0.24.0. Measured by a ratio script
  over `total_cost_usd` and `run-<i>.wall`, n = 2 per side.
- [ ] SM2: On the `critic-plan` control arm (clean plan, no revise cycle), mean session cost ≤ 1.35×
  and mean wall time ≤ +90 s against the same arm run on v0.24.0. Measured the same way.

## Requirement graph

| AC | Depends on |
|----|------------|
| AC1 | — (root) |
| AC2 | — (root) |
| AC3 | AC1, AC2 |
| AC4 | AC1, AC2 |
| AC5 | AC3, AC4 |
| AC6 | AC3, AC4 |
| AC7 | AC5 |
| AC8 | AC5 |
| AC9 | AC1 |
| AC10 | — (root) |

## Sign-off

**User signed off:** yes (2026-09-25)

Assumption 1 acknowledged by the user as staying open (2026-09-25) — carried to the plan as a `**Validates:** Assumption 1` task.

> A spec without sign-off does not proceed to **design, planning, or implementation** —
> `/feature-flow:ff-design`, `/feature-flow:ff-plan`, and `/feature-flow:ff-implement` each stop and
> route back to `/feature-flow:ff-clarify` if this reads `no` (implement is the hard backstop). A
> waived review is recorded explicitly: "sign-off waived by user (date)" — never assumed.
