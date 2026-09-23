# Feature Flow — v2 Enhancement Plan (Claude Code)

> **Status:** Implementation plan, rev. 2 — actuation pass (supersedes the "Intelligence Foundation RFC" roadmap)
> **Baseline reviewed:** v0.9.0 (`skills/feature-flow/SKILL.md`, `docs/manifest-schema.md`, all `commands/`, `agents/`, `hooks/`, `templates/`, `scripts/checks/`, `config/defaults.json`)
> **Audience:** Core maintainers and AI implementation agents (Claude Code)
> **Rev. 2 change:** every workstream now carries an **Actuation** line — what behavior the artifact *changes*, not just what it records — and **v2.1 is marked as the starting slice** (§5). This closes the "records but doesn't act" gap.

---

## 1. Purpose and method

This plan is the output of the "Required Architecture Review" the original RFC mandated but skipped. It is written **against the actual v0.9.0 codebase**, not against an idealized blank slate. The organizing correction: the framework already implements a large fraction of what the RFC proposed as net-new, so the real work is **extension of existing artifacts, phases, and gates** — not a parallel "Intelligence" layer.

Every workstream below is expressed in the framework's own terms: which existing file it touches, which manifest fields it adds (and their absent-field default), which Claude Code mechanism enforces it (hook / command / subagent), what self-acceptance criteria prove it landed, and which CI guard pins it.

---

## 2. Guardrails every enhancement must obey

These are derived from how v0.9.0 is actually built, and are non-negotiable for any PR under this plan:

1. **Extend, never fork.** No new phase, agent, or artifact type unless an existing one provably cannot carry the capability. The RFC's own Non-Goals forbid "skill explosion" and "parallel workflow systems."
2. **Manifest discipline (`docs/manifest-schema.md`).** Every new manifest field must define its **absent-field default** so pre-existing runs keep working with **no migration** — exactly as `autopilot`, `lock`, and `closedAt` already do. `manifest.artifacts.<n>` stays the sole authority for locating a file.
3. **Backward compatibility.** Existing `.feature-flow.json` configs and in-flight runs must behave identically unless a new toggle is explicitly set.
4. **Dist/Codex parity.** Every edit to `commands/`, `agents/`, `templates/`, `skills/`, `hooks/`, or `config/` requires re-running `scripts/package-codex-plugin.sh`; CI's parity guards (`scripts/checks/*.sh`) diff `dist/codex/feature-flow` against source and fail on drift.
5. **Enforcement stays fail-open.** The `enforce-gate` PreToolUse hook denies only a *provably illegal, determinate* manifest transition; on any indeterminate state (no `jq`, unparseable, missing field, `toggles.enforce=false`) it must stay out of the way. New gates follow the same rule.
6. **Prose gate first, machine gate second.** On Codex there is no hook mechanism, so every gate must be honorable by prose instruction in the command/skill, with the hook as a Claude Code-only backstop.
7. **Evidence, not assertion.** Read-only analysis agents (`ff-code-explorer`, `ff-code-architect`, `ff-code-reviewer`, `ff-diagnostician`) never gain `Bash`. Only `ff-test-runner` executes. Any new "proof" flows through captured output, not model claims.
8. **Proportional ceremony.** New capability must respect `tier: lite` — it cannot make a one-line fix expensive. Default new machinery to full-tier and opt lite out.
9. **Artifacts must actuate.** An artifact that is only read by a human is a documentation cost, not a capability. Every new or extended artifact must **change a later action** — feed a gate, alter agent fan-out, drive scheduling, seed a verify surface, or be recalled and enforced downstream. The KB already models this (recall changes agent context); new artifacts follow suit. Each workstream states its actuation explicitly.

---

## 3. Corrected gap analysis

| Capability | v0.9.0 reality | Real remaining gap | Priority |
|---|---|---|---|
| Verification / Evidence | **Shipped** (8 evidence kinds, mechanical confidence ladder, gap-blocks-done, machine-enforced Gate B) | Almost none | — |
| Alternative generation | Present in two layers (grilling Beat 2 + `ff-design` architect fan-out with rejected-alternatives table) | Per-option axis capture only | Low |
| Discovery | Strong premise/scope/AC work (`ff-clarify` + grilling playbook) | Stakeholders, success metrics, requirement graph as **structured fields** | Med |
| Assumption detection | Beat 4 surfaces WHAT-changing assumptions | **Structured assumption record** (confidence / evidence / alternative / validation) | Med |
| Trade-off analysis | One-line prose per option | **Decision matrix** across named axes | Med |
| Devil's advocate | Pre-sign-off red-team pass on the *spec* | No adversarial pass on the *selected design* | Med |
| Decision records (ADR) | KB captures "Decision/convention" with provenance | Full ADR field set + design-time capture | **High** |
| Planning intelligence | Phased `plan.md` + AC coverage + Outcome gate | **Dependency graph, critical path, rollback strategy, risk score** | **High** |
| Feedback / repair loop | One autopilot fix-and-re-review cycle; verify gaps block | Named Verify→Diagnose→Repair→Verify cycle | Med |
| Delivery intelligence | **Absent** | Release notes, deployment/rollback/migration checklists | **High (net-new)** |
| Adaptive workflow types | 2 tracks × 2 tiers (feature/bugfix, full/lite) | refactor / investigation / migration / research | Low–Med |
| Knowledge intelligence | KB capture/recall/staleness on by default | dedup + supersession (their own stated non-goal) | Low |
| Measurability | **Absent** | Eval harness to make success metrics real | **High (cross-cutting)** |

The three genuinely high-value, mostly-net-new items — **Delivery Intelligence, Decision Records, and Planning Intelligence** — are the ones the RFC deferred to P1–P3. This plan pulls them forward.

---

## 4. Workstreams

Each workstream is independently shippable and ordered later in §5. Per guardrail #9, each carries an **Actuation** line stating what behavior the artifact changes — the answer to "does this get read, or does it feed back and change the next action?"

### WS-1 — Structured Decision Records (ADR)

**Goal.** Persist design-time decisions with alternatives, trade-offs, and outcome — the thing "Every decision must be traceable" currently over-claims.

**Current.** `templates/kb-entry.md` captures a decision *at run close* with provenance, but lacks alternatives/trade-offs/outcome and fires too late (post-hoc, confirm-gated).

**Changes.**
- New `templates/decision.md` with fields: Decision, Context, Options considered, Trade-offs (matrix), Chosen + rationale, Related ACs, Related files, Outcome, Future considerations.
- `commands/ff-design.md`: after the architecture pick, write a `decision.md` capturing the choice (reuses the fan-out output already produced). For `tier: lite` features and bugfixes, capture inline in `spec.md`/`diagnosis.md` rather than a separate file.
- `docs/manifest-schema.md`: add `decision` to the **durable, promotion-eligible** artifact set (co-locates in `<D>-<slug>/`); add `artifacts.decision`. Absent = no decision recorded (pre-existing runs unaffected).
- KB bridge: `decision.md` becomes the natural source for KB capture at close, so the two stop being redundant.

**Actuation.** Decisions are **recalled and enforced downstream**, not just filed. At `ff-design` and `ff-implement`, recorded decisions (this run's `decision.md` + tag-matched KB entries) are surfaced to the agent as a **do-not-contradict** set: if the agent's chosen approach diverges from a recorded decision, it must **stop and surface the prior decision** rather than silently re-litigate it. This reuses the existing KB recall path and makes "every decision must be traceable" behaviorally real — a settled decision constrains later phases.

**Claude Code mechanics.** No new hook — this is a command-authored artifact. It rides the existing durable-promotion path.

**Self-acceptance.** A full-tier feature run produces a promoted `decision.md` with a non-empty options table; `ff-status` lists it; disk-inference resume recognizes it.

**Guard.** `scripts/checks/decision-record-guard.sh`: `decision.md` template retains its field headers; `ff-design.md` references it; dist parity holds.

---

### WS-2 — Planning Intelligence (dependency graph, critical path, rollback, risk)

**Goal.** Make `plan.md` express execution structure and reversibility, not just an ordered task list.

**Current.** `templates/plan.md` has phased tasks, `**Covers:**` AC mapping, and an Outcome gate. No dependency edges, no rollback, no risk score.

**Changes.**
- Extend `templates/plan.md` (and `templates/plan-bugfix.md`) with: a **Dependencies** column per task (task IDs it blocks/needs), a **Critical path** callout (longest dependency chain), a **Parallelizable** marker, a **Rollback strategy** section (how to undo each phase), and a per-task **Risk** tag (`low|med|high`) with a one-line reason.
- `commands/ff-plan.md`: instruct the planner to derive the critical path mechanically from the dependency column and to require a rollback line for any task touching migrations, schema, or irreversible I/O.
- Keep it **full-tier only.** Lite features skip plan entirely (unchanged); do not add planning weight to lite.

**Actuation.** The graph **drives the orchestrator**, it is not read-only markdown. `ff-implement` dispatches independent tasks in parallel and follows the critical path for ordering, instead of walking the list top-to-bottom. The per-task **risk tag raises ceremony mechanically**: a `high`-risk task bumps `reviewerAgents` for its review and forces the deeper verify surfaces for the ACs it covers — so risk *changes what the system does*, not just how a task is labeled. (This is the primary answer to the "too documentation-focused" critique; the artifact schedules and escalates.)

**Manifest.** Optional `plan.riskMax` (`low|med|high`, absent = unknown) surfaced by `ff-status`. No gate change.

**Self-acceptance.** A plan with ≥2 dependent tasks renders a critical path; a migration task without a rollback line is flagged by the planner before sign-off.

**Guard.** Extend `evidence-guard.sh` (which already pins `**Covers:**`) to also pin the new **Rollback** and **Dependencies** headers in `plan.md`.

---

### WS-3 — Delivery Intelligence (release / deploy / rollback / migration)

**Goal.** Close the one genuinely absent capability: a delivery artifact produced at the end of a run.

**Current.** Nothing. Runs end at `verify` (feature) / `review` (bugfix) with `done`.

**Changes.**
- New `templates/delivery.md`: Release notes (from ACs + decisions), Deployment checklist, Rollback checklist (seeded from WS-2's rollback sections), Migration notes, Known issues (from verify Limitations & remaining risks), Release validation steps.
- New command `commands/ff-deliver.md`: a **shared, optional, terminal** phase run after `verify`. It is **not gated** and does not block `done` — delivery is a value-add, and forcing it would violate proportional ceremony. Off for `tier: lite` unless requested.
- `docs/manifest-schema.md`: add `deliver` phase (status `pending|complete`), `artifacts.delivery`, promotion-eligible. Absent phase = run predates delivery; resume/status treat it as optional.
- Wire into `SKILL.md` phase lists and README command table.

**Actuation.** Delivery **consumes upstream artifacts rather than restating them**: the rollback checklist is generated *from* WS-2's per-task rollback lines, known-issues are pulled from `verify.md`'s Limitations & remaining risks, and release notes derive from ACs + `decision.md`. Consequence: a missing rollback line upstream shows up here as a visible hole (a delivery gap), which back-pressures WS-2 to record rollbacks in the first place. Delivery is the point where upstream sloppiness becomes visible.

**Claude Code mechanics.** Pure command + template + manifest field. No hook: nothing to *deny* here, since delivery never blocks completion.

**Self-acceptance.** `/feature-flow:ff-deliver` on a `done` full-tier run produces a `delivery.md` whose rollback checklist references the plan's rollback sections and whose known-issues mirror `verify.md`.

**Guard.** `scripts/checks/delivery-guard.sh`: template headers intact, command references verify + plan artifacts, dist parity.

---

### WS-4 — Structured Assumption Records

**Goal.** Turn "if assumptions remain, the feature is not understood" from a slogan into a recorded, validatable list.

**Current.** Grilling Beat 4 surfaces WHAT-changing assumptions in conversation; nothing structured persists.

**Changes.**
- Add an **Assumptions** section to `templates/spec.md` (and `templates/diagnosis.md` for full bugfixes): each row = `{statement, confidence (low|med|high), basis/evidence, if-wrong impact, validation-required (y/n)}`.
- `commands/ff-clarify.md` (and `ff-diagnose.md`): during Beat 4, write each surviving assumption as a row. A `validation-required: y` assumption that is still unvalidated at sign-off must be **called out in the sign-off prompt** (not silently accepted) — this is the "never silently assume" rule made mechanical.
- No new gate; it rides the existing sign-off gate.

**Actuation.** An open assumption **changes the run's task list**, not just a note in the spec. A `validation-required: y` assumption either (a) spawns an explicit validation task in `plan.md` (full tier) or (b) blocks a clean sign-off until the user validates or waives it. So surfacing an assumption produces work or a decision — it cannot be recorded and then ignored.

**Self-acceptance.** A spec with an unvalidated high-impact assumption cannot reach a clean sign-off prompt without that assumption being echoed to the user.

**Guard.** Extend the clarify/spec structural guard to pin the Assumptions section.

---

### WS-5 — Design-time Trade-off Matrix + Devil's Advocate

**Goal.** Give the *selected design* an adversarial pass and a structured comparison, not just prose one-liners.

**Current.** `ff-design` fans out minimal/clean/pragmatic and records a rejected-alternatives table; the red-team pass exists only in `ff-clarify` against the *spec*.

**Changes.**
- `templates/design.md`: replace the free-text trade-off prose with a **decision matrix** (rows = options, columns = performance / complexity / maintainability / scalability / security / cost / operational impact / test effort), plus a **Devil's advocate** section (failure scenarios, edge cases, migration/operational risks for the *chosen* option).
- `commands/ff-design.md`: add a final adversarial beat mirroring the clarify red-team pass — challenge the selected design before writing it. Reuse the existing architect fan-out output; do not add a new agent.
- Feeds WS-1: the matrix and devil's-advocate notes populate `decision.md`.

**Actuation.** The devil's-advocate **failure scenarios seed verify's evidence surfaces**: each named failure scenario for the chosen option becomes a required check in `verify.md`, so a scenario left unproven surfaces as an evidence gap that blocks `done` (via the existing gap rule). Challenging the design therefore changes *what must later be proven* — the critique flows into the verification contract rather than ending in the design doc.

**Self-acceptance.** A design run emits a matrix with all options scored and ≥1 concrete failure scenario for the chosen option.

**Guard.** Pin the matrix + devil's-advocate headers in `design.md`.

---

### WS-6 — Feedback / Repair loop

**Goal.** Name and bound the Verify→Diagnose→Repair→Verify cycle instead of the current implicit one-shot.

**Current.** Autopilot does exactly one fix-and-re-review cycle on a Critical review finding; verify gaps block `done` pending waiver. There is no explicit repair cycle for a *verify failure* (as opposed to a review finding).

**Changes.**
- `commands/ff-verify.md`: on a verify failure (not just an evidence gap), emit a short **repair plan** (what failed → smallest diagnosis → proposed fix → which ACs it re-touches) and, in autopilot, run **one** repair-and-re-verify cycle before stopping — mirroring the existing review cap exactly, so behavior stays predictable.
- Record cycle count in the manifest (`verify.repairCycles`, absent = 0) so status/resume can see it and the cap is auditable.
- Unchanged: a waiver never upgrades confidence; autopilot never records a waiver.

**Actuation.** This workstream *is* actuation — the repair plan drives a bounded re-verify cycle rather than being advisory. Sharpening: the repair plan names the **re-touched ACs**, and only those are re-verified, so the loop narrows to what actually changed instead of re-running the whole surface. The failure produces a scoped next action automatically.

**Self-acceptance.** A seeded failing test triggers a repair plan; autopilot attempts exactly one cycle, then stops with the gap report if still failing.

**Guard.** Extend the autopilot mandatory-pauses guard to cover the verify repair cap.

---

### WS-7 — Discovery field completeness

**Goal.** Add the missing structured discovery fields the RFC named (stakeholders, success metrics, requirement graph) without bloating clarify.

**Current.** Problem-as-need, scope, non-goals, ACs are strong; the three fields above are not first-class.

**Changes.**
- `templates/spec.md`: add optional **Stakeholders**, **Success metrics** (each metric must be measurable — reuses the binary-AC discipline), and a lightweight **Requirement graph** (AC → depends-on-AC edges, reusing WS-2's dependency notation for consistency).
- `commands/ff-clarify.md`: prompt for these only when non-trivial; keep them optional so lite features stay cheap.

**Actuation.** Discovery structure **propagates into planning and verification** instead of ending at the spec: each measurable **success metric maps to a verify evidence check** (it becomes something `ff-verify` must confirm), and the **requirement graph's AC edges feed WS-2's task dependencies** (the spec's dependency notation is the same one the plan consumes). So a well-structured spec directly shapes the plan graph and the verify contract downstream.

**Self-acceptance.** A full-tier spec can express an AC dependency and at least one measurable success metric; lite specs omit them without warning.

**Guard.** Structural pin on the new optional headers (present-in-template, not present-in-every-run).

---

### WS-8 — Eval and measurement harness (cross-cutting)

**Goal.** Make the RFC's success metrics real. Today "reduce hallucinated assumptions / planning mistakes / rework" is unmeasurable — there is no baseline.

**Changes.**
- New `evals/` directory (dev-only, not shipped in the plugin package) with a small set of fixture runs: known-good specs, a plan with a deliberate missing dependency, a verify that must catch a seeded regression, an assumption that must be surfaced.
- A `scripts/eval.sh` harness that replays fixtures and scores: did the missing dependency get flagged, did the unvalidated assumption reach the sign-off echo, did verify block on the seeded gap.
- Add to CI as a **non-blocking** report initially (so it can't wedge releases), promote to blocking once stable.

**Actuation.** The harness **gates CI**: non-blocking from v2.1, blocking from v2.3, so a behavioral regression in any actuated workstream (a graph that stops scheduling, an assumption that stops spawning a task) turns a fixture red and stops the release. It is the measurement layer that makes every other actuation claim checkable rather than asserted.

**Self-acceptance.** `bash scripts/eval.sh` prints a pass/fail line per fixture; a regression in WS-2/WS-4 flips a fixture red.

**Guard.** N/A (this *is* the guard layer for behavior the grep-guards can't check).

---

### WS-9 — Adaptive workflow types (deferred, scoped)

**Goal.** The RFC's refactor / investigation / migration / research tracks — but only if a real user need exists. Today feature/bugfix × full/lite covers most cases.

**Recommendation.** **Do not build seven tracks.** Instead:
- Add `investigation` and `refactor` as **tier/track *flavors*** that reuse the existing spine with different terminal expectations (investigation → no code, produces a findings artifact + decision; refactor → verify emphasizes regression/no-behavior-change evidence).
- Treat `migration` as a **plan-level concern** (WS-2 rollback + WS-3 migration notes already cover it) rather than a new track.
- Revisit `research` only if demand appears.

**Actuation.** A flavor **changes terminal expectations the system enforces**, not a cosmetic label: `investigation` makes `ff-verify` expect a findings/decision artifact and *no* code (code presence is a warning), and `refactor` makes `ff-verify` require no-behavior-change regression evidence as a first-class surface. The flavor alters what "done" means and what evidence is demanded.

This honors "opinionated, simple, workflow-centric" and avoids the parallel-systems trap.

---

### WS-10 — KB dedup + supersession

**Goal.** Retire the KB's own stated v1 non-goal.

**Changes.** At capture, tag-match new entries against existing ones; on near-duplicate, offer supersession (`supersedes: <slug>`, old entry marked `[SUPERSEDED]`, shown not dropped — same philosophy as `[STALE]`). Add `kb.dedup` toggle (absent = off, preserving current behavior).

**Actuation.** Supersession **changes what recall surfaces**: a superseded entry is demoted (or hidden) at recall so `ff-explore`/`ff-design`/`ff-diagnose` act on the *current* decision, not a stale one — closing the loop between capture and the WS-1 do-not-contradict enforcement, which would otherwise pin an obsolete decision.

**Priority.** Low; do last. It's a polish item, not a capability gap.

---

## 5. Re-sequenced roadmap (by gap × value)

Ordering corrects the RFC's topic-first sequence. Each release is production-ready before the next.

**▶ v2.1 — START HERE. Close the real gaps, with actuation built in from the first commit.**
- **WS-1 Decision Records** — *recommended first PR.* Cleanest slice: a template + the recall/do-not-contradict enforcement. Lands quickly and validates the actuation pattern (record → recall → enforce) before the harder scheduling work.
- **WS-2 Planning Intelligence** — the highest-value and hardest workstream (deriving the critical path, teaching the orchestrator to consume the graph and escalate on risk). Do second, once WS-1 has proven the actuation loop.
- **WS-8 Eval harness** — built alongside WS-1/WS-2, non-blocking in CI — so v2.1's actuation claims are measured, not asserted. Ship it *in* v2.1, never last.

> **Starting instruction.** Do not begin any workstream from the rev. 1 (records-only) framing. Every v2.1 PR must implement the workstream's **Actuation** line, not just its artifact. A PR that adds a template or manifest field without the behavior it drives is out of scope for this plan. Suggested first commit: WS-1's `decision.md` template + the `ff-design`/`ff-implement` recall-and-refuse check + a WS-8 fixture that proves a contradicted decision is caught.

**v2.2 — Delivery + reasoning capture.**
- WS-3 Delivery Intelligence (the net-new artifact)
- WS-4 Structured Assumption Records
- WS-5 Trade-off matrix + Devil's advocate

**v2.3 — Loop + discovery polish.**
- WS-6 Feedback / repair loop
- WS-7 Discovery field completeness
- Promote WS-8 eval to blocking in CI

**v2.4 — Adaptive + knowledge polish.**
- WS-9 Investigation/refactor flavors (only if demand)
- WS-10 KB dedup/supersession

Rationale: v2.1 ships the highest-value, mostly-net-new work first (planning + decisions) **with measurement baked in and each artifact wired to actuate**; the already-strong areas (discovery, alternatives) get *field-level* polish later, not a rebuild. The autonomy / v3-vision question (raised in review) is deliberately **not** a prerequisite here — it is a parallel track that v2.1 does not block on. "Autonomous within the evidence rails" (parallelize because the graph proves it safe, escalate because risk is high, skip because a decision is settled) is the only autonomy this framework's constitution permits, and v2.1's actuated artifacts are precisely the substrate that later autonomy would act on.

---

## 6. Cross-cutting engineering checklist (per PR)

Every workstream PR must:

0. **Implement the workstream's Actuation line, not just its artifact.** A PR that adds a template, section, or manifest field without the downstream behavior it drives is incomplete and out of scope. The eval fixture (WS-8) for that behavior is part of the same PR.
1. Define the absent-field default for any new manifest field in `docs/manifest-schema.md`, and confirm a pre-v2 manifest still resolves/resumes.
2. Add/extend the matching `scripts/checks/*.sh` structural guard.
3. Re-run `scripts/package-codex-plugin.sh` and confirm dist parity guards pass.
4. Keep the `enforce-gate` hook fail-open; if it adds a deny path, prove it fires only on a determinate illegal transition and add a `*-guard.sh` around it.
5. Provide the Codex prose-equivalent for any Claude Code-only enforcement.
6. Confirm `tier: lite` behavior is unchanged (new ceremony is full-tier by default).
7. Update `SKILL.md`, `README.md` command table, and `CHANGELOG.md` (the repo's changelog style is per-release with Added/Changed sections).

---

## 7. Risks and mitigations

- **Ceremony creep** — the seven-role ambition inflates artifacts. *Mitigation:* every new artifact is full-tier-only and, for delivery, non-blocking; lite stays cheap.
- **Manifest sprawl** — too many optional fields erode the schema's clarity. *Mitigation:* group related fields, document absent-defaults, cap net-new phases at one (`deliver`).
- **Enforcement brittleness** — new deny paths break fail-open. *Mitigation:* guardrail #5; only `deliver` is truly new and it never denies.
- **Codex drift** — hook-based Claude Code enforcement has no Codex analogue. *Mitigation:* prose gate first; dist parity guards catch source/dist divergence.
- **Unmeasurable success (again)** — shipping WS-1..7 without WS-8 repeats the RFC's original sin. *Mitigation:* WS-8 lands in v2.1, not last.

---

## 8. Definition of done (per release)

A release is done when: all its workstream self-acceptance criteria pass; new/extended CI guards are green; `dist/codex/feature-flow` parity holds; a pre-v2 manifest resumes unchanged; `tier: lite` runs are byte-for-byte unaffected where untouched; and the eval harness (blocking from v2.3) shows no regression. Consistent with the framework's own doctrine: **evidence, not assertion** — the release proves itself the same way a feature does.
