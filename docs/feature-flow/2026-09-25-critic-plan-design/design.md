# Design: a Critic inside the design and plan phases

**Spec:** `docs/feature-flow/2026-09-25-critic-plan-design/spec.md`
**Created:** 2026-09-25

## Chosen approach

**The post-write `ff-critic` leaf: one report per phase, screened, then revised once.** Full design:
`.feature-flow/critic-plan-design/architect.md`.

**The agent.** A new leaf, `agents/ff-critic.md`, built on the `ff-code-architect.md` template:
- the leaf and read-budget preambles
- `tools:` with a one-file `Write` and no `Edit`/`Bash`
- the report written to the caller-named path
- one-physical-line markers

Its body distills the user's `critical-plan-review` process:
- basis labels (`verified` / `from the contract` / `inferred`)
- an unverified load-bearing assumption is a finding
- do the arithmetic
- verify claims against the repo, read-only
- lenses trimmed to a code change: contract fit, assumptions, logic / contradictions, edge cases and
  failure, architecture / integration, security / data, operations / rollback, test-ability
- calibrated Critical / Important severity (Critical = the artifact cannot meet an AC / FS /
  constraint, contradicts the design or contract, or rests on a false premise about the repo;
  "if everything is critical, nothing is")
- the no-noise rule
- a report budget of ~400 words, up to ~800 for a multi-module change

It returns only these markers:
- `Verdict: ready | revise`
- one line per finding: `Critical C<n>: <title> — <where> — <basis>` or
  `Important I<n>: <title> — <where> — <basis>`
- or instead `No findings — <why>`

**Where it runs.** The Critic reviews the **written** artifact, the way `ff-review` reviews the real
diff. That gives every finding a stable `file:line` to cite, and lets the revision edit that file in
place.
- **`ff-design`:** after the devil's-advocate pass, `design.md` is written. Then the Critic runs.
  `decision.md` is written only after it clears, so it derives from the final design.
- **`ff-plan`:** after the No-Placeholders self-check and the Outcome gate, `plan.md` is written,
  then the Critic runs. On both tracks the contract is spec + design (feature) or the diagnosis
  (bugfix).
- Neither `phases.<phase>.status` becomes `"complete"` until the Critic clears.

**The procedure** lives once, in `docs/schema/critic.md` (house style: both commands reference
**§Critic** by name):
1. Dispatch once (`models.critic`) with the report path `<run dir>/critic-design.md` or
   `critic-plan.md`, and record `manifest.artifacts.critic-design` / `critic-plan`.
2. **Screen** every finding against the signed contract:
   - out of scope or a non-goal → rewritten as `Dropped (contradicts the spec): <finding> — <clause>`
   - the spec itself is wrong → STOP and route to `ff-clarify`
   - a design Critical whose fix is a different approach → STOP and ask the user
3. No Critical left → rule each Important (fix, or a `**Ruling:**` line in the report), then
   continue.
4. A Critical remains and the report has no `## Resolution` → **append `## Resolution` first**
   (the pre-fix Criticals and the fixes applied; grafted, see FS2). Then revise the artifact in
   place and re-dispatch the Critic **once**, with **no report path** and the Resolution as
   context. Append its return under `## Re-check` (never overwrite), then screen it the same way.
5. A Critical still open after the re-check, or a `## Resolution` already present on entry with a
   Critical open → the **Critic stop** (cross-turn, both modes). It clears when the user fixes or
   redirects and re-runs the phase, or writes `Critic finding accepted by user (<date>): <reason>`
   in the report.
6. Close the phase with the line
   `Critic: <ready | revised | stopped> — <n> Critical, <n> Important (<report path>)`.

## Rejected alternatives

| Alternative | Why rejected |
|-------------|--------------|
| In-session draft critic (critique before anything is written, write once) | The Critic can't cite a stable `file:line`, and the revise cycle re-runs against a copy inlined in the prompt |
| One shared `critic.md` for both phases | The plan phase overwrites the design phase's critique and its audit trail |

## Trade-off matrix

| Option | Complexity | Risk / operational impact | Test effort |
|--------|------------|----------------------------|--------------|
| Post-write critic, per-phase report (chosen) | med | med | med |
| In-session draft critic | low | med | med |
| One shared `critic.md` | low | high | med |

## Component map

| File / module | Responsibility | New or modified |
|---------------|----------------|-----------------|
| `agents/ff-critic.md` | Leaf contract (process, severity, budget, markers, report path) | new |
| `docs/schema/critic.md` | §Critic: inputs per phase, screen, revise-once cycle, re-entry/re-run, Critic stop, `Critic:` line | new |
| `commands/ff-design.md` | Split the write (design.md → Critic → decision.md); Critic re-entry; AC10 re-entry screen | modified |
| `commands/ff-plan.md` | Critic after the plan write, both tracks; complete only on clear | modified |
| `docs/schema/autopilot.md` | Mandatory-pauses row: Critic stop | modified |
| `docs/manifest-schema.md` | `artifacts.critic-design` / `critic-plan` (ephemeral), `models.critic` Known key, Topic index §Critic | modified |
| `config/defaults.json` | `models.critic: "opus"` | modified |
| `skills/feature-flow/SKILL.md`, `references/codex-tools.md` | `ff-critic` listed; the architect and critic both "never edit code, write only their own report" | modified |
| `scripts/checks/critic-guard.sh` | Pins AC1–AC9 + dist parity | new |
| `scripts/checks/single-architect-guard.sh` | AC10 pin | modified |
| `evals/forward/critic-design`, `critic-plan`, ratio script | Fired/control arms, SM1/SM2 | new |
| README, CHANGELOG, version files, `dist/` | Docs, 0.25.0, repackage | modified |

## Data flow

**Design phase:**
1. spec + explore → architect → choice pause → do-not-contradict → devil's advocate
2. **design.md written**
3. `ff-critic` (spec, explore, design.md, KB decisions) → `critic-design.md`
4. screen
5. [`## Resolution` → revise design.md → re-check → `## Re-check`]
6. **decision.md derived**
7. complete + `Critic:` line

**Plan phase:**
1. contract (spec + design | diagnosis) → decompose → planning intelligence → No-Placeholders →
   Outcome gate
2. **plan.md written**
3. `ff-critic` → `critic-plan.md`
4. screen, then the same cycle
5. complete + `Critic:` line

## Risks

- **Cost and time.** Opus is the user's choice, and the budget is tight (spec Assumption 2, low).
  Mitigations: a report budget, the read budget, and briefing the Critic with paths only, never
  pasted content. SM1/SM2 measure the result.
- **Old commands in this run.** This run's own design and plan phases run on the v0.24.0 commands,
  without the Critic. The feature is proven only by the forward tests.
- **Codex.** Inline fallback. On Codex without subagents the critique is the orchestrator's own,
  which is weaker. The report says `inline` so the user can tell.

## Devil's advocate

### Failure scenarios

- **FS1:** The Opus Critic over-flags. It rates a sound design or plan's generic hardening ("add
  retries", "add monitoring") or a style preference as Critical. Every such run then pays a revise
  cycle and, in autopilot, hits spurious Critic stops. The Critic becomes the "time waste" the user
  objected to in v0.24.0.
- **FS2:** The session drops mid-cycle, after the revise and before the re-check is recorded. With
  the Resolution written after the re-check (the architect's original order), re-entry finds no
  `## Resolution`. It treats the cycle as unspent and runs a second one, breaking the one-cycle cap,
  or loses the pre-fix findings. *(Mitigated by the graft above: append `## Resolution` before
  re-dispatching, and append the re-check under `## Re-check` without overwriting.)*
- **FS3:** A design Critical says, in effect, "the chosen approach is wrong". The orchestrator
  treats it as an in-approach fix and quietly rewrites `design.md` into a different architecture
  that the user never chose. That bypasses the choice pause.

### Edge cases & operational risk

- The Critic's report is missing or has no `Verdict:` line → the orchestrator critiques inline once
  and records `inline`. The step is never skipped silently.
- A confirmed phase re-run deletes the old `critic-*.md` and clears its pointer, as the architect's
  re-run discard does.
- A pre-0.25.0 run resumed mid-plan has no pointer → the Critic runs as normal. No migration.
- `decision.md` now comes after the Critic, so a Critic stop leaves `design.md` without its decision
  record until the phase re-runs. `phases.design.status` stays `in_progress`, so `ff-plan` cannot
  start.
