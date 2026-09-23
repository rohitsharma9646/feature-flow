# Design: Structured retrospective (ff-retro) + forward-testing of semantic behaviors

**Spec:** `docs/feature-flow/2026-09-23-retro-forward-testing/spec.md`
**Created:** 2026-09-23

## Chosen approach

**Pragmatic — mirror existing precedents line-for-line** (user-picked), with the output-dir tweak
from the minimal option.

**Retrospective.** `commands/ff-retro.md` is a structural clone of `commands/ff-deliver.md`:
precedence blockquote → run resolution → **done gate** (`currentPhase != "done"` → STOP naming the
phase, write nothing; covers abandoned) → **no tier gate** (allowed on lite and bugfix, unlike
deliver — stated explicitly) → **re-run guard** (by name) → `phases.retro.status = "in_progress"`,
`currentPhase` untouched → pointer-only cold-start over `artifacts.{spec|diagnosis, design,
decision, plan, review, verify, delivery}` (each optional, "not available" when absent, never
invented) → **candidate scan** over a *closed* list of on-disk signals (override/waiver verbatim
lines, review `## Resolution`, verify `## Repair`, contract items below `Verified (single-source)`,
Critical review findings, `⚠ DELIVERY GAP` lines, plus `$ARGUMENTS` notes) → **materiality test**
(by name) → 9-field candidates → **confirm gate** (the KB capture gate's shape, reused by name:
cross-turn, mandatory in both modes, nothing written until the user accepts/edits/rejects each) →
write `retro.md` from `templates/retro.md` at the durable-resolved path → `artifacts.retro` +
`phases.retro = {status: complete, artifact}` → hand-off + progress strip. Never chained by
autopilot; never fires KB capture; no git.

`docs/manifest-schema.md` gains `## Retrospective` (after §Delivery) as the canonical contract:
purpose (the workflow's own safeguards — explicitly *not* project decisions, which are KB's),
activation, the signal list, the **materiality test** — *a candidate is material iff it traces to a
specific safeguard signal from the closed list (or a user note) AND it is not fully closed by that
signal alone: a clean waiver with no recurring gap is not material; a bypass, false-fire,
missed-catch, or recurring gap is* — the 9-field schema with its closed enums, the confirm-gate
shape classification (**passive confirm-gate shape — same row shape as KB capture; not
unconditional, not a capped cycle**), the zero-candidate and reject-all paths, the AC10 link to
`evals/forward/README.md`'s case shape, and v1 non-goals. Plus: a `phases.retro`/`artifacts.retro`
Field-notes bullet (absent-defaulted, no migration), `retro` appended to the durable-eligible list,
and a new §Autopilot mandatory-pauses row. `schemas/manifest-v1.schema.json` gains `phases.retro`
in the `phases` object and all four per-track `propertyNames` enums — **not** in `currentPhase`.
`ff-verify` (feature terminal) and `ff-review` (bugfix terminal) done hand-offs name
`/feature-flow:ff-retro` alongside `/feature-flow:ff-deliver` as optional next steps.

**Forward-testing.** A repo-internal sibling of the WS-8 eval harness, one layer deeper: fixtures
prove *preconditions* by grep; forward cases prove *firing* via a live fresh process.

- `evals/forward/<behavior>/{fired,control}/` with the 7 slugs **identical to `evals/fixtures/*`**
  (`decision-conflict`, `planning-gap`, `delivery-gap`, `assumption-gap`, `design-gap`,
  `repair-gap`, `discovery-gap`). Each arm: `sandbox/` (a full planted repo root incl.
  `.feature-flow/<slug>/manifest.json` + artifacts, `autopilot` set explicitly), `prompt.txt` (blind
  — never states the expected outcome), `expected.md` (human-readable expected observable),
  `assert.sh <tmpdir> <run.json>` (exit 0 = behaved as expected, 1 = not; anything else = ERROR).
- Sandboxes are **seeded from what already works**: `design-gap` ← `.feature-flow/ws5-selfrun-{fired,control}-v2`,
  `repair-gap` ← `.feature-flow/ws6-selfrun-{fired,control}`, `delivery-gap`/`assumption-gap` ←
  `evals/fixtures/*` artifact content promoted into full run sandboxes; the rest authored against
  the self-run evidence logs. (Source `.feature-flow/` dirs are gitignored — copies become
  committed files under `evals/forward/`.)
- **Assertions key on the behavior-specific marker**, never merely "didn't advance": each fired
  `assert.sh` checks its own STOP/fire signature (e.g. `Decision conflict` text + no source write;
  `⚠ DELIVERY GAP` in `delivery.md`; `## Repair` newly present; `currentPhase` not `done` **and**
  the `### FS1`/`### SM1` block below `Verified`), so an unrelated gate (enforce-gate hook, sign-off
  gate, cold-start route-back) cannot produce a false PASS.
- `scripts/forward-test.sh [behavior...] [--repeat N] [--max-budget-usd X] [--timeout S]
  [--output-dir D]` — bash, like every other script. Preflight (`claude` on PATH; names validated
  against `evals/forward/*/`) → exit 2 before any arm. Per arm × repeat: `mktemp -d` → `git init` +
  empty commit → `cp -R sandbox/.` → `timeout S claude -p --plugin-dir <repo> --max-budget-usd X
  --output-format json "$(cat prompt.txt)"` → ERROR on timeout (124) / non-zero exit /
  unparseable JSON / `is_error:true` → else `assert.sh` → PASS/FAIL (other exit → ERROR). Arm
  rollup: any ERROR → ERROR; else any FAIL → FAIL; else PASS. Prints `PASS|FAIL|ERROR
  <behavior>/<arm>  ($x.xx)` + summary; writes transcripts + `summary.md` to
  `.feature-flow/forward-test-runs/<UTC-timestamp>/` (already gitignored). Exit 0 iff all PASS.
  JSON parsing via `python3` (already assumed by CI). Lives in `scripts/`, never `scripts/checks/`.
- **WS-7 scope narrowing (named, not silent):** `discovery-gap` exercises the `SM<n>` evidence-gap
  half (ff-verify); the requirement-graph half (ff-plan) is recorded as uncovered in
  `evals/forward/discovery-gap/*/expected.md`, the README, and the CHANGELOG.

## Rejected alternatives

| Alternative | Why rejected |
|-------------|--------------|
| Minimal (bash runner, static hand-authored sandboxes) | Near-identical runner, but re-authors sandboxes that already exist and accepts a transcript-text-only assertion for `assumption-gap`; doesn't address the enforce-gate false-PASS hazard. Its gitignored output dir *was* adopted. |
| Clean (Go runner `cmd/ff-forward-test` + JSON-schema'd `case.json` + JSONL records/rollup) | Most extensible and typed, but adds a Go binary, a schema, and unit tests for a local-only tool with 14 fixed cases; breaks the repo's bash-scripts convention. Revisit if the case count grows well past the 7 known gaps. |

## Trade-off matrix

| Option | Complexity | Risk / operational impact | Test effort |
|--------|------------|----------------------------|--------------|
| **Pragmatic (chosen)** | med | med | med |
| Minimal | med | low | high |
| Clean | high | med | high |

> Risk is `med` for pragmatic/clean because both shell out to a paid `claude` process whose
> assertions must separate the target behavior from unrelated gates; minimal rated itself `low`
> but did not address that hazard. No extra axis differentiates enough to add a column.

## Component map

| File / module | Responsibility | New or modified |
|---------------|----------------|-----------------|
| `docs/manifest-schema.md` | `## Retrospective` contract; `phases.retro` field note; durable list + `retro`; §Autopilot confirm-gate row | modified |
| `schemas/manifest-v1.schema.json` | `phases.retro` in phases object + 4 track enums (not `currentPhase`) | modified |
| `templates/retro.md` | report shape: header, source blockquote, 9-column findings table, `_No material events._` sentinel, `## Rejected` count, `## Notes` | new |
| `commands/ff-retro.md` | the phase procedure (ff-deliver clone, confirm-gated) | new |
| `commands/ff-verify.md`, `commands/ff-review.md` | terminal hand-off names `ff-retro` + `ff-deliver` | modified |
| `skills/feature-flow/SKILL.md`, `README.md` | list `ff-retro` (README also a dev-docs note on forward-testing) | modified |
| `scripts/checks/retro-guard.sh` | pins schema/command/template/enum/pause-row shape (row must NOT say "unconditional") + dist parity | new |
| `scripts/checks/durable-paths-guard.sh` | `check_writer commands/ff-retro.md retro`; `retro` in `DURABLE` regex | modified |
| `evals/forward/README.md` | case shape (AC10 target), fired/control convention, how to add a behavior | new |
| `evals/forward/<7 behaviors>/{fired,control}/{sandbox/,prompt.txt,expected.md,assert.sh}` | the 14 forward-test arms | new |
| `scripts/forward-test.sh` | local runner | new |
| `scripts/checks/forward-test-guard.sh` | 7×2×4-part structure; runner not under `scripts/checks/`; `dist/codex/feature-flow/evals` absent | new |
| `CHANGELOG.md`, `.github/workflows/ci.yml` (comment), `scripts/eval.sh` (header) | honest coverage wording; drift fix | modified |
| `.claude-plugin/plugin.json`, `.codex-plugin/plugin.json`, `.claude-plugin/marketplace.json`, README badge | version bump 0.17.1 → 0.18.0 (version-sync-guard) | modified |
| `dist/codex/feature-flow/**` | regenerated by `scripts/package-codex-plugin.sh` | regenerated |

## Data flow

**Retro:** `manifest.artifacts.*` → `ff-retro` reads each resolved artifact → closed signal scan →
materiality filter → 9-field candidates (in the turn) → **confirm gate, turn ends** → user's
accept/edit/reject → `templates/retro.md` render → Write at durable path → `artifacts.retro` +
`phases.retro` → hand-off. `currentPhase` stays `done`; nothing else touched.

**Forward-test:** `evals/forward/<b>/<arm>/sandbox/` → fresh temp git dir → `claude -p
--plugin-dir <repo>` (fresh process loads the **working-tree** commands/templates/hooks; agent
writes land in the temp dir) → `assert.sh` reads the temp dir's final state (+ transcript as a
secondary signal) → PASS/FAIL/ERROR per repeat → arm rollup → stdout lines + `summary.md` +
transcripts under `.feature-flow/forward-test-runs/<ts>/` → exit code. The full-suite output is
copied into this run's `evidence/` for AC19.

## Risks

- **Cost.** 14 arms × repeats of real headless sessions. Mitigation: per-arm `--max-budget-usd`
  (default set after measuring the cheapest arm first), `--repeat` default 1, per-arm + total cost
  printed.
- **Fixture fidelity.** `ff-implement`/`ff-verify` cold-start depends on exact template wording
  (task checkboxes, `## Critical path`, `## Contract mapping`); a near-miss sandbox exercises
  cold-start routing instead of the target STOP. Mitigation: seed from sandboxes that already
  fired in past self-runs; build in ascending risk order (delivery-gap first).
- **LLM variance.** A single arm run can flake. Mitigation: `--repeat N` with "flaky is not green".
- **Hook dependency.** The enforce-gate hook needs `jq`; missing `jq` fails open (hook silent), which
  only removes a safety net, never flips an assertion.
- **Tracked-files gap.** `docs/feature-flow/` is gitignored; this run's durable docs + evidence
  need a force-add (house practice) if the user commits them.

## Devil's advocate

### Failure scenarios

- **FS1:** A fired arm STOPs for the **wrong reason** — e.g. the planted `signOff`/`artifacts`
  shape trips enforce-gate Gate A or ff-implement's sign-off route-back before the do-not-contradict
  check ever runs — and a loose `assert.sh` ("nothing was written") scores it PASS. The suite goes
  green while the target STOP is actually hollow: the exact silent regression this feature exists
  to catch. Proof required: for at least one STOP-shaped behavior, a **mutation run** — the target
  STOP instruction removed from a scratch copy of the plugin — makes the fired arm **FAIL**.
- **FS2:** Default per-arm budget/timeout is sized from the $0.16 `ff-list` probe, but `ff-verify` /
  `ff-implement` arms dispatch subagents and run checks; arms hit the cap and report **ERROR**, so
  the suite can never go green and the runner is abandoned as "flaky". Proof required: the full-suite
  run shows every arm finishing with `is_error:false` and recorded cost below its cap.
- **FS3:** `ff-retro` in a single headless turn (no human to answer) skips its confirm gate — writes
  `retro.md` or edits other files straight away — violating AC5/AC6 in exactly the unattended
  setting where nobody would notice. Proof required: a headless `ff-retro` run on a planted `done`
  sandbox with material signals ends with **no** `retro.md`, no `phases.retro: complete`, and no
  file outside the manifest changed, with the candidate table in its output.

### Edge cases & operational risk

- `assumption-gap` depends on `ff-clarify` accepting a sign-off reply embedded in the same `-p`
  prompt rather than restarting interrogation; if it restarts, that arm needs a transcript-text
  assertion instead (the open Assumption 2 — plan task 1 validates it before fixtures are built).
- `repair-gap` requires `autopilot: true` in its planted manifest; absent defaults to `false` and
  silently turns the test into a plain gap-stop.
- Behaviors that STOP before writing (decision-conflict, planning-gap) use a dual assertion: marker
  text in `run.json` `.result` **and** no tracked-file change outside `.feature-flow/`.
- Planted sandboxes copied from gitignored `.feature-flow/ws*` dirs may reference absolute or
  scratch paths; each must be rewritten to be self-contained.
- The forward-test suite must be re-run manually after any edit to a STOP's instruction text —
  nothing in CI enforces that (named in CHANGELOG, same honesty as before).
