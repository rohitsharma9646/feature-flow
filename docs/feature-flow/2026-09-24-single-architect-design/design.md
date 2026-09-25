# Design: one architect in ff-design instead of a three-way fan-out

**Spec:** `docs/feature-flow/2026-09-24-single-architect-design/spec.md`
**Created:** 2026-09-24

> Produced by **one** `ff-code-architect` under the new contract (this run's own design phase used
> the behaviour it specifies instead of the three-way fan-out, at the user's stated preference). Its
> report is `.feature-flow/single-architect-design/architect.md`.

## Chosen approach

**Single dispatch; `architect.md` as an ephemeral side artifact of the design phase (like
`decision.md`); a fixed-marker report; one re-dispatch when the user picks a rejected approach.**

- **`commands/ff-design.md`** — frontmatter and KB-recall wording drop the fan-out. `## Do the work`:
  dispatch **exactly ONE** `ff-code-architect` (`models.architect`) with the spec and explore findings;
  no agent-count setting is read. **Re-entry check** first: if `manifest.artifacts.architect` resolves
  to an existing file (or `<run dir>/architect.md` exists), read it and go straight to the choice pause
  — no re-dispatch. Otherwise **write the report before the pause**: the architect's return value
  verbatim to `<run dir>/architect.md`, then its repo-relative path (`<base>/<slug>/architect.md`) to
  `artifacts.architect`. The pause asks with the recommended design first and each `Rejected:`
  approach as an option; `one obvious approach —` → confirm-only. **Picking a rejected approach**
  re-dispatches the architect once to develop it in full; the new report is **appended** under a
  `## Developed on request: <name>` heading and is the one `design.md` derives from. The
  do-not-contradict STOP, devil's-advocate pass and the design/decision writes are unchanged.
- **`agents/ff-code-architect.md`** — the sibling-architect sentence goes; a **Weighing approaches**
  section: weigh the smallest change, the cleanest structure and the codebase's conventions as lenses,
  develop only the best in full, list 1–3 genuinely different rejected approaches briefly with scores,
  fold a graftable mechanism into the winner and say so, or write `one obvious approach — <why>`; a
  **Report format** section with fixed markers — `Recommended: <name>` first, `Rejected: <name> — <why>
  — complexity: low|med|high, risk: low|med|high, test effort: low|med|high` lines, or the single
  `one obvious approach — <why>` line.
- **Contract wording** — `templates/design.md` (Rejected-alternatives note; matrix "every option the
  architect considered") and `docs/schema/design-tradeoffs.md` §Trade-off matrix; no guarded string
  moves.
- **Config** — `architectAgents` removed from `config/defaults.json`, the Known-keys line and the README
  table; `docs/manifest-schema.md` lists `architect` among the ephemeral artifacts, the Schema example
  gains `"architect"`, and a field note describes it.
- **Docs** — README phase and command tables, SKILL's design description.
- **Guard** — `scripts/checks/single-architect-guard.sh`: one dispatch, no `architectAgents`, no
  three-focus list; the agent's markers and no sibling wording; `artifacts.architect`, re-entry, write
  → pause → devil's-advocate ordering; the re-dispatch + append; the autopilot row unchanged; the
  derive-not-diverge text still present; `architectAgents` absent from config/Known keys/README; no
  "architects fan out" wording in commands, README, SKILL; dist parity.
- **Forward test** `evals/forward/single-architect` — both arms plant a manifest at `design` with
  `autopilot: false`, so the session holds at the choice pause; asserts read `architect.md` off disk.
  Fired: a small bash project whose spec has a genuine architectural fork. Control: a spec with one
  sane approach. `sm1-ratio.sh` compares `total_cost_usd`; the baseline runs the same fired arm with
  `FF_FORWARD_PLUGIN_DIR` pointed at a git worktree of v0.23.0 (`e95c4de`).
- **Release** — 0.24.0, CHANGELOG, dist.

## Rejected alternatives

| Alternative | Why rejected |
|-------------|--------------|
| `architect` as a new phase in the enum | widens the phase enum; ripples into autopilot chaining, terminal convergence, status, resume and disk inference |
| No `architect.md`; re-dispatch on re-entry | fails AC4; a dropped session loses the architect's work and pays for it twice |
| Keep `architectAgents`, default 1 | the user chose removal; dead config and a path back to the fan-out |

> The architect develops the recommended approach in full and returns a short rejected list — this
> table is its `Rejected:` lines. Record the real trade-offs so the choice is auditable.

## Trade-off matrix

| Option | Complexity | Risk / operational impact | Test effort |
|--------|------------|----------------------------|--------------|
| Single dispatch + `architect.md` side artifact (chosen) | low | low | med |
| New `architect` phase | high | high | high |
| Always re-dispatch | low | high | low |
| Keep `architectAgents` = 1 | low | med | low |

## Component map

| File / module | Responsibility | New or modified |
|---------------|----------------|-----------------|
| `commands/ff-design.md` | one dispatch, re-entry, report before pause, pick + re-dispatch | modified |
| `agents/ff-code-architect.md` | weighing lenses, best-only, fixed report markers | modified |
| `templates/design.md`, `docs/schema/design-tradeoffs.md` | "every option the architect considered" | modified |
| `config/defaults.json`, `docs/manifest-schema.md`, `README.md`, `skills/feature-flow/SKILL.md` | remove `architectAgents`; `architect` artifact; wording | modified |
| `scripts/checks/single-architect-guard.sh` | structural guard | new |
| `evals/forward/single-architect/`, `forward-test-guard.sh`, `evals/forward/README.md` | forward test + SM1 helper | new / modified |
| version files, CHANGELOG, `dist/codex` | 0.24.0 | modified |

## Data flow

spec + explore.md → one `ff-code-architect` → return value → `architect.md` (+ `artifacts.architect`) →
choice pause → [picked alternative → re-dispatch → appended report] → do-not-contradict STOP →
devil's-advocate pass → `design.md` + `decision.md`.

## Risks

- **Prose-only contract.** Nothing mechanically stops an architect from developing every option in
  full; the forward test and SM1 are the check.
- **Design quality is unmeasured** (spec non-goal); accepted by the user for speed.
- **SM1 is a one-off manual measurement**; pricing changes can move it.

## Devil's advocate

> Stress-test the **chosen** option only (not the rejected ones — this is not a re-litigation of
> the pick). **At least one failure scenario is required**, even for a design with a single obvious
> option. See `docs/schema/design-tradeoffs.md` §Design trade-offs & devil's advocate.

### Failure scenarios

- **FS1:** The single architect pads its report — develops every option in full, or lists strawman
  alternatives ("do nothing", a trivially worse variant) — so the cost saving vanishes or the user
  picks between fake options.
- **FS2:** The session drops after `architect.md` is written but before `artifacts.architect` is
  recorded (or the reverse) → re-entry does not see the report, re-dispatches, and pays twice or
  overwrites the first report.
- **FS3:** The user picks a rejected approach; the appended report sits below the first one, and
  `design.md` is derived from the first (recommended) design instead of the picked one.

### Edge cases & operational risk

- A project still setting `architectAgents` gets the standard unknown-key warning — intended.
- Codex without multi-agent tooling runs the architect role inline; the same report and markers apply.
- The forward test's headless session cannot answer the choice pause; both arms rely on
  `architect.md` being on disk before it (Assumption 1).
