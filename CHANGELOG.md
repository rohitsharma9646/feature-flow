# Changelog

## [0.11.0] — 2026-07-05 — Planning intelligence (dependency graph → critical path → STOP)

Plans stop being a flat task list. `ff-plan` now derives four sections into every `plan.md` /
`plan-bugfix.md` (between `## Tasks` and `## Status conventions`): a **Dependency graph** (edges
naming only lower-numbered `Task N` IDs — so task order is always topological and cycles are
unexpressible), a **Critical path** *derived* from that graph (the longest dependency chain,
deterministic tie-break — never hand-authored), a categorical **Risk register**, and a **Rollback
plan**. The critical path is the **sole hard actuator**: `ff-implement` reads it (via
`manifest.artifacts.plan`) and **STOPs** — unconditional in both modes, cloned from the
decision-recall do-not-contradict STOP — if the approach skips or reorders a critical-path task; an
override is the user's own words, recorded verbatim as `Critical-path override by user (<date>):
<reason>` in the plan, never self-authored. The other three plug into existing consumers: the risk
register feeds `ff-verify`'s `## Regression risk`; the rollback plan is the recovery `ff-implement`
runs on a failed `Step N: Verify`. Additive and non-breaking: **no new config toggle, no new
manifest field** (the sections live inside the already-durable plan); a pre-WS-2 plan with no
sections is absent-tolerated everywhere (STOP proceeds, verify derives risk cold).

**Known coverage gap (named, not silent):** the *semantic* catch — `ff-implement` actually
STOPping on a critical-path-skipping approach — has **no automated regression guard**; it is a
manual/fresh-session self-run behavioral AC (AC15). `planning-intelligence-guard.sh` pins only the
STOP *instruction's presence*, section placement, and the derivation rule's wording — not that the
catch fires. Same honest posture as v0.10.0's AC13.

### Added
- **Four planning-intelligence sections** in `templates/plan.md` and `templates/plan-bugfix.md`
  (`## Dependency graph`, `## Critical path`, `## Risk register`, `## Rollback plan`), each with
  house-style `> ` fill-in guidance; categorical risk (Low/Med/High), no numeric scores.
- **`## Planning intelligence`** canonical contract (`docs/manifest-schema.md`) — the dependency
  notation + lower-numbered invariant, the deterministic critical-path derivation, the
  `ff-implement` do-not-contradict STOP, and the risk/rollback consumer contracts; plus a
  **Critical-path stop** row in the Autopilot mandatory-pauses table (unconditional, no
  auto-resolve retry).
- **`scripts/checks/planning-intelligence-guard.sh`** — pins both templates' four sections
  (presence, order, placement, categorical risk table, Task-ID edges), the schema section +
  Autopilot row, the `ff-plan` derive-instruction placement, the `ff-implement` `## Critical-path
  check` section (placement + `artifacts.plan` + unconditional + override string + rollback
  pointer), the `ff-verify` risk cross-reference, the no-new-config/manifest-field negatives, and
  Codex dist parity.

### Changed
- **`ff-plan`** derives the four sections after task decomposition / AC-mapping and before the
  Outcome gate (both tracks); the critical path is derived from the graph, never hand-authored.
- **`ff-implement`** gained a `## Critical-path check` section (between `## Decision recall` and
  `## Do the work — feature track`): the critical-path STOP plus the rollback-on-failed-Verify
  recovery pointer.
- **`ff-verify`** cross-references the plan's `## Risk register` into its `## Regression risk`
  assessment instead of deriving risk cold (full tier; lite/pre-WS-2 unchanged).

## [0.10.0] — 2026-07-05 — Structured decision records (record → recall → enforce)

Design decisions stop being write-only. `ff-design` now records the chosen architecture in a
structured `decision.md` (options, trade-offs, chosen rationale), promoted alongside `design.md`;
and that decision **constrains later phases** — `ff-implement` recalls this run's own decision
(and, when the KB is active, prior decisions from other runs) before writing code and **STOPs** if
the approach diverges, and `ff-design` STOPs if a pick contradicts a prior settled decision. The
STOP is a **prose gate** (an LLM judgment, like sign-off — no hook, semantic contradiction is not
machine-checkable) and **unconditional in both modes**; an override is the user's own words,
recorded verbatim, never self-authored. Additive and non-breaking: no new phase or agent; the one
new manifest field (`artifacts.decision`) is absent-tolerated with no migration, and `tier: lite`
stays cheap (the spec's inline decision *is* the record — `artifacts.decision` points at the spec).

**Known coverage gap (named, not silent):** the *semantic* catch — the agent actually STOPping on a
contradiction — has **no automated regression guard**; it is a manual/self-run behavioral AC
(AC13). Automated coverage pins only the STOP *instruction's presence* in the command files
(`decision-record-guard.sh`) and the recall *preconditions* (`scripts/eval.sh`). A future
fast-follow could deepen this; today it is honestly manual.

### Added
- **`templates/decision.md`** — the decision record: frontmatter (`tags`, `referencedFiles`, for
  recall tag-match + staleness) + `## Decision / Context / Options considered / Trade-offs
  (matrix) / Chosen + rationale / Outcome / Future considerations` + `**Related ACs:**` /
  `**Related files:**`.
- **`### Decision recall`** contract (`docs/manifest-schema.md` §Knowledge base) — the canonical
  two-source rule (this run's `artifacts.decision`, unconditional; prior KB decisions, KB-gated)
  and the do-not-contradict STOP; a **Decision conflict stop** row in the Autopilot mandatory-pauses
  table; `artifacts.decision` field note (absent = no decision recorded, no migration; dual-shaped
  full/lite); `decision` added to the durable-artifact list + the disk-inference tuple.
- **`scripts/checks/decision-record-guard.sh`** — pins the template headers (against the verbatim
  shipped template), the ff-design/ff-implement/ff-clarify wiring, the STOP-instruction survival in
  both command files, and dist parity of `templates/decision.md`.
- **`scripts/eval.sh` + `evals/`** (WS-8) — a **non-blocking** precondition harness (outside
  `scripts/checks/`, not in CI): one fixture asserting a decision record is well-formed,
  tag-matchable against a contradicting request, and that the STOP wiring exists. Not the semantic
  catch (see coverage gap above).

### Changed
- **`commands/ff-design.md`** — after the architecture pick, writes `decision.md` (recorded in
  `artifacts.decision`) and STOPs on a pick that contradicts a prior settled decision.
- **`commands/ff-implement.md`** — new `## Decision recall` section (between Cold-start and Do the
  work) recalls the run's decision and STOPs on divergence before any code is written.
- **`commands/ff-clarify.md`** — lite branch points `artifacts.decision` at the spec, so implement's
  recall is tier-agnostic (no fork).
- **KB capture** now reads `decision` (preferred distillation source over `design` prose), closing
  the decision-record ↔ KB-entry redundancy.
- **`scripts/checks/kb-guard.sh`** (`check_recall` generalized + `ff-implement` decision-recall
  call) and **`durable-paths-guard.sh`** (`decision` writer check + bare-name coverage) extended.

## [0.9.0] — 2026-07-05 — Evidence-based verification

No task reaches `done` without objective, reproducible, multi-source evidence. The verify
pipeline widens from generic test/build/lint to the project's whole **detected** evidence
surface, `verify.md` becomes a client-sign-off-grade report, and insufficient evidence now
**blocks completion** pending an explicit user waiver. Additive and non-breaking: no new
phase, agent, config key, or artifact type; existing runs and configs behave as before —
the verify phase simply produces (and is gated on) more than a bare pass/fail table.

### Added
- **Canonical `## Evidence` contract** (`docs/manifest-schema.md`): the 8-kind taxonomy
  (executed-test, build/static-analysis, e2e/browser via Playwright CLI, http/api, db,
  cli-output, logs, before/after), the literal record shape
  `{kind, command, actual exit/HTTP status, excerpt, artifact paths}`, the evidence
  directory rule (`<run dir>/evidence/`, cleared per run, copied on durable promotion),
  the **mechanical confidence ladder** (`Verified (multi-source)` / `Verified
  (single-source)` / `Partially verified` / `Unverified`; overall = minimum; independence
  = distinct kinds), the detection→gap/N-A rule, the waiver rule, tier scaling, an
  "Adding an evidence kind" recipe, and stated v1 non-goals. Commands reference it by
  name — never restate it.
- **Widened `ff-test-runner`** (`agents/ff-test-runner.md`): detects `composer.json`
  scripts, `phpunit.xml(.dist)`, `playwright.config.*`, `bin/magento`, and MFTF alongside
  package.json/Makefile/pyproject; captures all 8 kinds with real status codes; writes
  only under `<run dir>/evidence/` (cleared at start); bounds every command with a
  timeout; guarantees ≥1 attempted command with a real exit code even on a no-tests
  project (cheapest smoke/syntax check).
- **Client-grade `verify.md`** (`templates/verify.md`): evidence coverage matrix
  (full-tier; lite renders the floor-only note), per-criterion evidence blocks
  (requirement verbatim → method → evidence with commands + status codes + `evidence/`
  artifacts → confidence), evidence artifacts index, Limitations & remaining risks, and an
  overall-confidence verdict. `## Commands run`, `## Contract mapping`, and
  `## Regression risk` headings unchanged.
- **Evidence gap stop** (`commands/ff-verify.md` + §Autopilot mandatory-pauses row): any
  contract item below `Verified (single-source)` blocks `done` — the run ends with a gap
  report (what could not be verified, why, what evidence is required). Only the user's own
  waiver line — `Evidence gap accepted by user (<date>): <reason>` — unblocks it; a waiver
  never upgrades confidence, and autopilot never records one.
- **Gate B content check** (`hooks/enforce-gate`): `artifacts.verify` must now also contain
  a `## Contract mapping` heading and ≥1 captured exit/HTTP/status token — the historic
  `# Verify` stub that previously passed Gate B is now denied
  (`scripts/checks/enforce-gate-guard.sh` fixtures flipped/added to prove it: stub → deny,
  filled report → allow, heading-without-token → deny). Still fail-open, `jq`-only,
  verify-specific (`artifacts.review` keeps the generic check), Claude-Code-only.
- **Durable client report**: `verify` joins the durable-eligible artifacts — with
  `paths.durable` set, `verify.md` promotes to `<paths.durable>/<D>-<slug>/` with the
  run's `evidence/` directory **copied** alongside (Evidence companion copy), keeping
  relative links resolving. README warns about committing binary-heavy evidence dirs.
- **Guards**: `scripts/checks/evidence-guard.sh` extended with sections (f)–(l) pinning
  the §Evidence subsections + record shape + taxonomy, the four confidence tokens (schema
  AND template), the new report headings + lite note, the ff-test-runner detection tokens +
  evidence-dir discipline, the Autopilot pause row, the ff-verify wiring + waiver line, and
  dist parity for the newly pinned files. `durable-paths-guard.sh` now `check_writer`s
  `commands/ff-verify.md` for `artifacts.verify`.

### Changed
- `commands/ff-verify.md`: evidence authority extends to all kinds (a detected surface that
  did not run/pass is an explicit **gap**; N/A only for undetected surfaces, always with a
  reason); confidence derived mechanically (count distinct passing kinds — never eyeballed);
  `## Refuse premature "done"` is now the evidence gap stop; verify resolves its path per
  Durable artifact resolution and records it in `artifacts.verify`.
- `docs/manifest-schema.md` §Disk inference: `verify.md` minimal validity now matches Gate
  B's content check (heading + status token), so inference and the hook never disagree.

### Reconciliation with v0.5.0
v0.5.0 deferred a "completion-proof framework" (duplicative of verify.md) and rejected
numeric confidence/readiness scores ("unfalsifiable LLM output"). **Both decisions are
upheld**: there is still no parallel report artifact — `verify.md` itself is the report,
upgraded in place — and there are still no numeric scores — confidence is categorical and
mechanically recountable from the captured evidence (count the distinct passing kinds).
What changed since v0.5.0 is the external requirement: client sign-off now depends on the
verification report, and the evidence surface widens from test/build/lint to everything
the project detectably has (incl. Magento/PHP stacks: composer, PHPUnit, `bin/magento`,
MFTF — and Playwright e2e via CLI).

### Deferred (stated, not silent)
MCP/interactive browser automation (Playwright CLI via Bash only); Gate B waiver-coverage
checking (semantic, not grep-determinate — v2 hardening candidate); environment
provisioning; CI integration; perf-benchmark framework; retroactive re-verification.

## [0.8.0] — 2026-07-04 — Knowledge base on by default + bugfix-track recall

The KB (0.4.0, opt-in) becomes **on by default**, and recall reaches the bugfix track. **Zero
runtime-logic change**: the activation AND-gate, recall procedure (tag-match + staleness
flag-not-drop), confirm-gated capture, and Codex degrade path are all semantically identical —
only the shipped default *values* and the set of recall-hooked commands change. Projects with an
explicit `.feature-flow.json` behave exactly as before (explicit keys override defaults).

### Changed
- **KB defaults flipped** (`config/defaults.json`): `toggles.kb` `false` → `true`, `paths.kb`
  `null` → `".feature-flow-kb"`. A fresh project has an active KB from its first run — capture
  at the done-transition, recall before the fan-outs. **Opt out per-project** with
  `{ "toggles": { "kb": false } }` (or `paths.kb: null`); either cleanly deactivates (the
  half-config warning from 0.6.0 still fires on an explicit `paths.kb: null` with the toggle on).
  `kb.freshnessWindowDays` (90) and `kb.maxRecallEntries` (5) unchanged.
- **`kb-guard.sh` re-pinned**: section (a) now asserts the *new* defaults (RED→GREEN
  demonstrated against the old config); sections (e)/(g)/(h) extended to cover
  `commands/ff-diagnose.md`.

### Added
- **KB recall on the bugfix track** (`commands/ff-diagnose.md` `## KB recall`): tag-matched
  entries are surfaced to the diagnostician agents before dispatch, keyword source = the bug
  report (`$ARGUMENTS`). Previously recall was feature-track-only (`ff-explore`/`ff-design`),
  leaving the KB write-only on bugfix-heavy projects — captured at `ff-review` but never
  consumed. The canonical contract (`docs/manifest-schema.md` §Knowledge base) now names five
  hooked commands and a three-command recall rule.

### Docs
- `manifest-schema.md` §Activation rewritten for on-by-default (+ the half-config example now
  says *explicitly null*, matching the post-flip reality — also mirrored in `ff.md`); SKILL.md
  §Knowledge base and README (section + config table) updated; the repo's own KB entry
  recording the old default-off decision rewritten in place to the new convention. Historical
  CHANGELOG entries (0.4.0–0.7.0) untouched.

## [0.7.0] — 2026-06-26 — lite feature tier

Brings the feature track to parity with the bugfix track's lite/full split (M2 from the v0.5.0 architecture review). **Non-breaking and additive**: `tier` already existed on the manifest; this teaches the feature track to use `lite`. A feature with no/`full` tier behaves byte-identically to before.

### Added
- **Lite feature tier (M2).** Small, single-approach features can run `tier: lite` — `explore → clarify → implement → review → verify` — **skipping the design + plan phases** and using a **1-agent explore**, while keeping sign-off + review + verify. Tier is **soft-judged at `/ff` entry** (announced; ambiguous → ask once; **in doubt → full**), mirroring the existing feature-vs-bugfix classification. A lite run can **escalate to full before implement** (sets `tier=full`, resets sign-off, carries the spec forward into the full clarify → design path). `ff-clarify` runs a minimal clarify on lite (skips the premise + approach-weighing beats, asks only enough to lock binary ACs); `ff-implement`'s feature cold-start is now tier-aware (lite requires only the signed `spec.md`, never routes to the non-existent design/plan phases). `enforce-gate`'s Gate A already covers `feature/*`, so a lite feature is enforced (no implement without sign-off) with **no hook change**. Contract pinned by `scripts/checks/lite-tier-guard.sh`; the free hook coverage pinned by two new `enforce-gate-guard.sh` fixtures.

## [0.6.0] — 2026-06-26 — reliability hardening + fail-closed enforcement

Foundation-safety fixes from the v0.5.0 architecture review (`docs/feature-flow/architecture-review-2026-06-25.md`). All **non-breaking**: additive frontmatter, additive schema rules, prose clarifications, one optional manifest field (`lock`, absent = unlocked), and new dev/CI tooling. Manifests authored before this change still validate; no migration.

### Added
- **Manifest write safety** (`manifest-schema.md` §Manifest write safety, wired via Run resolution step 7): mandates whole-object atomic writes (never partial line-edits that can leave torn JSON) — closing the highest-probability corruption path — and adds an **advisory `lock`** field, a soft staleness-self-healing concurrency guard (15-minute stale-takeover) so two sessions touching one run warn rather than silently clobber. The lock is advisory prose, not an enforced mutex (C1).
- **Universal corrupt-manifest handling** (`manifest-schema.md` Run resolution step 6): the "on a corrupt manifest, fall back to Disk inference — never improvise or blind-overwrite" rule, previously honored only by `ff-resume`/`ff-status`, now applies to **every** command. Phase commands inherit it via their existing `Run resolution` reference (C3).
- **Least-privilege `allowed-tools`** on the inspect/management commands: `ff-status`/`ff-list` → `Read, Glob, Grep`; `ff-abandon`/`ff-close` → `Read, Glob, Write`. The read-only/scoped claims are now tool-enforced, not prose-only (C4).
- **Config validation at run start** (`manifest-schema.md` §Config resolution & validation, wired from `ff`): `/feature-flow:ff` now validates the resolved config and **warns** on an unknown/typo'd key (e.g. `explorerAgent` vs `explorerAgents`), a half-configuration (`toggles.kb` true with `paths.kb` unset), or a type/domain mismatch — then falls back to the safe default. Misconfigurations are surfaced instead of silently no-op'ing (Q2).
- **Comprehensive dist-parity guard** (`scripts/checks/dist-parity-guard.sh`): checks **every** packaged file is byte-identical to source, not the ~half the other guards spot-checked — so a future edit to any packaged file that isn't re-packaged is caught (Q4).
- **CI workflow** (`.github/workflows/ci.yml`): builds the Codex package (fixing the fresh-clone landmine where the gitignored `dist/` left parity checks with nothing to diff), JSON-parses every config/manifest, then runs all guard scripts on every push and PR. Previously nothing ran the guards (Q5).
- **Fail-closed enforcement on Claude Code** (`hooks/enforce-gate` + `toggles.enforce`, default on): a `PreToolUse` hook now **denies** two illegal `manifest.json` transitions instead of merely asking commands not to make them — entering `implement` without the track's sign-off precondition (**Gate A**) and reaching `done` without valid on-disk verify (and, on bugfix, review) evidence (**Gate B**). The hook **fails open** (allows on any indeterminate state — `jq` absent, unparseable manifest, missing fields, `toggles.enforce: false`) and denies only a determinate-illegal write, so it can never block normal editing or wedge a run. Requires `jq`; warns loudly (`systemMessage`) if absent. Codex (no hook mechanism) keeps the prose gates — the hook backstops the prose, it does not replace it. Behavioral test: `scripts/checks/enforce-gate-guard.sh` (19 cases incl. the `run-hook.cmd` dispatch seam). Turns the workflow's hardest promises from "asked nicely" to enforced (M1).

### Changed
- **Single-sourced the KB recall/capture procedures** (Q3): `ff-explore`/`ff-design` (recall) and `ff-verify`/`ff-review` (capture) inlined the full numbered procedure that the schema's §Knowledge base already owns — a triple. Each command now keeps only its gating sentence, a by-name reference to the canonical rule, and its command-specific input (recall keyword source / capture artifact list); the procedure guts live only in the schema. Behavior byte-identical. Also enriched the schema capture rule to name `plan` (previously omitted there while both commands relied on it).
- **Single-sourced the terminal-convergence rule** (Q6): which command marks a run `done` (feature → `ff-verify`; bugfix → whichever of verify/review runs second) is a core-workflow invariant that governs even KB-off runs, but its only statement was buried inside the §KB capture rule. Extracted to a canonical `manifest-schema.md` §Terminal convergence section; §KB capture and both terminal commands now reference it. The two commands' status-check routing is intentionally left in place (it is irreducibly two-sided); `kb-guard` gained checks pinning the new single-source structure and still counts the `**KB capture**` invocations.
- **Design fan-out builds on exploration** (`ff-design`): architects are now passed the `explore.md` findings as context instead of cold re-scanning the repo, eliminating ~3× redundant codebase scans per design phase (Q7).
- **Verification authority moved off read-only agents** (C2, minimal prose): `ff-diagnostician` now labels its reproduction a **static hypothesis** (it is read-only and cannot execute); `ff-diagnose` states the binding executed evidence is the RED regression test in `ff-implement`; `ff-verify` records the test runner's literal exit evidence and may mark `pass` only when backed by a captured success exit code (no narration-only or reasoning-only passes); `ff-test-runner` derives each status from the **actual exit code** and has an explicit no-write-to-tracked-files constraint.

## [0.5.0] — 2026-06-24

Evidence over assumptions. Three additive guardrails folded into existing templates and phase
prompts — no new artifacts, no new workflow phase, no migration. Runs authored against the v0.4.0
templates still validate.

### Added
- **AC traceability (feature track)**: the `plan.md` task template gains a `**Covers:**` field,
  and the Outcome gate now requires every spec acceptance criterion to map to ≥1 task — an
  uncovered AC is flagged as an explicit gap, never left silent. `ff-plan` enforces this, scoped
  to the feature track (a full-tier bugfix has no spec/ACs; its contract is the diagnosis).
- **Regression risk in verification**: `verify.md` gains a `## Regression risk` section
  (`Low | Medium | High` + reason; no numeric score), filled by `ff-verify` from the surface the
  change touched.
- **Root-cause candidate ranking (full-tier bugfix)**: `diagnosis.md` separates
  `## Root cause candidates` (≥2 hypotheses with evidence for/against) from
  `## Confirmed root cause`. `ff-diagnose` requires candidate enumeration on the full tier and
  leaves lite (trivial) bugs single-cause — no ceremony on a one-spot fix.

### Deferred (stated, not silent)
- New `test-design.md` / `investigation.md` artifacts and a completion-proof framework (they
  duplicate the existing design / diagnosis / verify artifacts); numeric confidence/readiness
  scores (unfalsifiable LLM output); and the verify→review reorder (entangled with the KB
  single-fire invariant and `kb-guard` assertions — warrants its own guard-tested change).

## [0.4.0] — 2026-06-15

Knowledge base. **Off by default** — with `toggles.kb` false or `paths.kb` null, every phase
behaves byte-identically to v0.3.1 (no migration, no new prompts).

### Added
- **Knowledge base (opt-in)**: a finished run can **capture** its architectural decisions /
  project conventions as project-local markdown entries (confirm-gated, fired exactly once at the
  run's done-transition across both tracks), and later runs **recall** tag-matching entries into
  the `explore` and `design` fan-outs. Stale entries (referent missing/moved, or older than
  `kb.freshnessWindowDays`) are flagged `[STALE — …]`, never silently dropped or shown as fresh.
- Config: `toggles.kb` (default `false`), `paths.kb` (default `null`), `kb.freshnessWindowDays`
  (default `90`), `kb.maxRecallEntries` (default `5`).
- Canonical `## Knowledge base` contract in `docs/manifest-schema.md` (store layout, entry schema,
  capture/recall/staleness rules, Codex degrade table); entry template `templates/kb-entry.md`;
  regression guard `scripts/checks/kb-guard.sh`.
- v1 non-goals (deferred to a fast-follow, stated not silent): dedup, supersession, an index
  query surface, content-similarity relevance, mid-run capture, auto-committing, and a global KB.

### Note
- The KB's **structural** wiring is guard-pinned (RED→GREEN). Its **behavioral** path
  (live capture/recall/staleness) is verified by a manual smoke in a KB-enabled session; treat the
  opt-in feature as **beta** until that smoke is run.

## [0.3.1] — 2026-06-12

### Fixed
- **Run-start autopilot ask was silently skippable** (first real-world v0.3.0 run locked
  itself to step-by-step: the executor wrote `autopilot: false` without asking, and
  "never re-ask" made it permanent). The ask is now structurally non-droppable: the value
  is resolved **before** the manifest is written, `autopilot` is a required creation
  field at all four manifest-creating entry points, the unconditional doctrine gains
  "never choose `manifest.autopilot` yourself", and the mandatory-gate table gains the
  in-session "Run-start mode ask" row. `ff-status` now prints the run's mode. Regression
  guard: `scripts/checks/run-start-ask-guard.sh`.

## [0.3.0] — 2026-06-12

Autopilot mode. No breaking changes; pre-v0.3.0 manifests (no `autopilot` field) behave as
step-by-step everywhere — no migration, no mid-run ask.

### Added
- **Autopilot mode**: per-run `manifest.autopilot` boolean — when `true`, ceremonial
  phase-end STOPs become continuations (the assistant chains into the next phase in the
  same turn), pausing only at human gates: spec/diagnosis sign-off, the design option
  choice, an unreproduced bug, and an unresolved Critical review block. Step-by-step
  behavior is unchanged.
- Config `toggles.autopilot` (`"ask"` | `true` | `false`, default `"ask"`): `"ask"` asks
  once at run start (every manifest-creating entry point); the answer is recorded per-run
  and never re-asked.
- Canonical sections in `docs/manifest-schema.md`: **Autopilot** (chaining rule,
  mandatory-pause table, fix-cycle bound, run-start procedure, resume semantics) and
  **Sign-off rendering** (verbatim rule + grouped-checklist format).
- Autopilot Critical-review handling: exactly one fix-and-re-review cycle, recorded in
  `review.md`'s `## Resolution` section (the durable cycle record); then stop if Criticals
  remain.
- Progress strip renders auto-completed phases as `<phase>[auto]`; the strip is emitted
  after each chained phase.

### Changed
- Sign-off asks (`ff-clarify`, full-tier `ff-diagnose`) now render the contract as a
  **grouped checklist** (theme headings, `**AC<n> — <label>**` items, text verbatim) —
  never a blockquote wall.
- A user sign-off on an autopilot run continues the chain in the same turn (the commands
  re-read `manifest.autopilot` from disk when the confirmation arrives).
- `ff-resume` on an autopilot run continues the chain from the resume point to the next
  mandatory pause; step-by-step resume is unchanged (one phase, then stop).
- All 8 phase commands + `ff`, `ff-resume`, and SKILL.md doctrine are mode-conditional;
  the unconditional gate lines (never auto-sign, never pass a sign-off/not-reproduced/
  exhausted-Critical gate) are explicit in both modes.

## [0.2.0] — 2026-06-12

Pre-promotion hardening round. No breaking changes; v0.1.0 run manifests need no migration.

### Added
- `/feature-flow:ff-list` — list all runs (slug, track, tier, phase, dates), including
  abandoned/closed ones.
- `/feature-flow:ff-abandon <slug>` — mark a run abandoned; abandoned runs are excluded from
  automatic run resolution.
- `/feature-flow:ff-close <slug>` — close a completed (`done`) run; closed runs are excluded
  from automatic run resolution.
- `templates/explore.md` — structure contract for the explore artifact.
- `templates/plan-bugfix.md` — bugfix-track plan template (diagnosis gate, test-first Task 1).
- Manifest fields: `closedAt`; `currentPhase` value `abandoned`.
- Canonical sections in `docs/manifest-schema.md`: Disk inference procedure, Re-run guard,
  Progress strip.
- Config: `diagnosticianAgents` (default 1).
- Sign-off asks now quote the contract inline: `ff-clarify` quotes the spec's acceptance
  criteria verbatim; `ff-diagnose` (full tier) quotes the fix approach + contract items.

### Changed
- `models.*` config is now honored: every agent-dispatching command passes `models.<role>` as
  the dispatched agent's model.
- Run resolution excludes abandoned/closed runs; ambiguity prompts list
  `slug | track | currentPhase | updatedAt` per candidate.
- `ff-resume` validates manifest claims against disk (artifact existence + minimal validity)
  instead of trusting `status: complete`.
- `ff-status` performs its own disk inference on a missing/corrupt manifest, labeled
  `[inferred from disk]`.
- Every phase command: re-run guard on already-complete phases; progress strip in every
  STOP/hand-off message.
- `ff-review` (feature track) now blocks on Critical findings instead of routing to verify;
  bugfix branch routes to `ff-verify` when verify hasn't run yet.
- `ff-implement` gates on `design.md` (feature cold-start) and states that `toggles.tdd`
  never applies to the bugfix track.
- `ff-design` / `ff-plan` / `ff-diagnose` gained prescribed quoted gate-failure messages.
- `ff-verify` cold-start routes to `ff-clarify`/`ff-diagnose` instead of asking an open question.
- `ff.md` delegates the explore procedure to `ff-explore.md` (duplication eliminated).
- `ff-clarify` fill-list now includes the spec's Constraints section.
- README rewritten: worked example, configuration reference, command table, teammate vs
  author install, troubleshooting.

### Fixed
- `plugin.json`: added `repository`; `marketplace.json`: real plugin description.

## [0.1.0] — 2026-06-11

Initial release: feature track (explore → clarify → design → plan → implement → review →
verify) and test-first bugfix track (diagnose → implement RED→GREEN → verify → review),
durable `.feature-flow/<slug>/` run state, soft gates, read-only analysis agents, executed
verification via `ff-test-runner`.
