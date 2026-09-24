# Autopilot — feature-flow manifest contract
> Part of the manifest contract. Core rules and the topic index: `docs/manifest-schema.md`.

## Autopilot

`manifest.autopilot: true` makes ceremonial phase-end STOPs **continuations**: after
completing a phase (artifact written, manifest updated — **never batched**, so a dropped
session stays recoverable by `ff-resume` at the first incomplete phase), emit the progress
strip, then read `${CLAUDE_PLUGIN_ROOT}/commands/ff-<next-phase>.md` and execute it in the
same turn, exactly as written — no abbreviation, no improvisation. `false` **or absent** →
step-by-step: every STOP ends the turn (v0.2.0 behavior, unchanged).

**Ceremonial boundaries (chain through these):**
- feature: explore → clarify; post-sign-off → design → plan → implement → review → verify
- feature lite: explore → clarify; post-sign-off → implement → review → verify
- bugfix lite: diagnose → implement → verify → review
- bugfix full: post-sign-off → plan → implement → verify → review

**Delivery is never chained.** The optional `deliver` phase (§Delivery) is post-terminal and
manual: autopilot ends at the done-transition and **never** auto-runs `ff-deliver`. Delivery is a
value-add the user invokes explicitly — chaining it would add ceremony a non-gated phase must not.

**Retro is never chained.** The optional `retro` phase (§Retrospective) is post-terminal and manual in
exactly the same way: autopilot **never** auto-runs `ff-retro`, and never answers its confirm gate.

**Mandatory pauses — gates are physics, not preference; autopilot never skips, overrides,
or self-answers a gate:**

| Gate | Type | Behavior in autopilot |
|---|---|---|
| Spec sign-off (`ff-clarify`) | cross-turn | end the turn with the sign-off ask (**Sign-off rendering** above); never set `signOff.signed` yourself; chain resumes on the user's confirmation or `ff-resume` |
| Diagnosis sign-off, full tier (`ff-diagnose`) | cross-turn | same as spec sign-off |
| Not-reproduced stop (`ff-diagnose`) | cross-turn | ends the chain unconditionally — autopilot does not retry |
| Decision conflict stop (`ff-design` vs prior decisions; `ff-implement` vs this run's own decision) | cross-turn | **unconditional** STOP in both modes — autopilot does not auto-resolve or retry (unlike the Critical-review fix cycle); the chain resumes only when the user realigns the approach or replies with an explicit `Decision override by user (<date>): <reason>` — never self-authored — see §Knowledge base → **Decision recall** |
| Critical-path stop (`ff-implement` vs the plan's derived critical path) | cross-turn | **unconditional** STOP in both modes — autopilot does not auto-resolve or retry (same severity as the Decision conflict stop above); the chain resumes only when the user realigns the work to respect the critical path or replies with an explicit `Critical-path override by user (<date>): <reason>` — recorded in the plan's `## Critical path`, never self-authored — see §Planning intelligence → **Critical-path check** |
| Critical review block (`ff-review`) | cross-turn | one fix-and-re-review cycle (below), then stop if Criticals remain |
| Verify repair-and-re-verify cycle (`ff-verify`) | cross-turn | capped — one repair-and-re-verify cycle (below) on a genuine AC/bugfix failure (a captured non-success status), then the Evidence gap stop if it still fails; a pure evidence gap or a failed `FS<n>` never triggers a cycle |
| Stale-phase stop (done-transition on a revision-bound run — `ff-verify`, or `ff-review` on bugfix) | cross-turn | capped — one stale-phase re-run cycle (below) when the other phase's revision is stale, then STOP naming the phase if it is still stale; step-by-step always STOPs naming the phase |
| Evidence gap stop (`ff-verify`) | cross-turn | any contract item below `Verified (single-source)` blocks `done` — end the turn with the gap report (what could not be verified, why, what evidence is required); autopilot never records a waiver itself; chain resumes on the user's waiver (see §Evidence, Evidence waiver) or a re-run after the gap is addressed |
| Assumption validation stop (`ff-clarify`; `ff-diagnose` full tier) | cross-turn | an unvalidated `validation-required: y` assumption blocks a clean sign-off — end the turn with the `### Unvalidated assumptions` echo block (which assumptions are still unvalidated); autopilot never records a waiver itself; chain resumes once the user resolves each — validate it, waive it (`Assumption validation waived by user (<date>): <reason>`), or acknowledge it stays open (carried to the plan as a `**Validates:**` task; see §Assumption records → Actuation 1). Same waivable shape as the Evidence-gap-stop row above |
| KB capture confirm-gate (`ff-verify` feature-terminal / `ff-review` bugfix-terminal), only when `toggles.kb` active | cross-turn | distill candidates, end the turn for the user to accept/edit/reject; never write entries unconfirmed; chain resumes to `currentPhase="done"` on the answer or `ff-resume` — see §Knowledge base |
| Retro confirm-gate (`ff-retro`, only when the user invokes it after `done`) | cross-turn | distill retrospective candidates, end the turn for the user to accept/edit/reject each; never write `retro.md` unconfirmed and never answer the gate on the user's behalf; `ff-retro` is never chained, so there is no chain to resume — see §Retrospective |
| Design option choice (`ff-design`) | in-session | ask (AskUserQuestion), then continue the chain in the same turn |
| Run-start mode ask (every manifest-creating entry point, config `"ask"`) | in-session | resolve BEFORE the manifest write: ask (AskUserQuestion), then write the manifest including the answer — never choose `manifest.autopilot` yourself |
| Clarify interrogation questions | in-session | ask, then continue |
| Run disambiguation / re-run guard confirmations | in-session | ask, then continue |

Any **gate failure** mid-chain (missing artifact, unsigned contract, wrong track) stops the
chain with that gate's existing prescribed message — routing back, never forward.

**Fix-and-re-review cycle (Critical findings, autopilot only).** Before starting a cycle,
check `review.md` for an existing `## Resolution` section recording a prior autopilot fix
cycle — the review artifact is the durable cycle record (it survives session drops). No
prior cycle → apply fixes for the Critical findings, append the Resolution record (pre-fix
findings, fixes applied, outcome), and re-run the review dispatch **once**. A prior cycle
exists, or Criticals remain after the re-review → emit the standard Critical-block message
and end the turn. `phases.review.status` stays `in_progress` until the review is clear.
Zero Critical findings → no cycle; chain proceeds.

**Repair-and-re-verify cycle (verify failure, autopilot + full tier only).** Mirrors the
Fix-and-re-review cycle above, applied to a genuine verify *failure* instead of a review finding.
Before starting a cycle, check `verify.md` for an existing `## Repair` section — the verify
artifact is the durable one-cycle record (it survives session drops), exactly as review's
`## Resolution`. **No prior cycle AND ≥1 contract item is an acceptance criterion, bugfix item, or
the spec's end-to-end check (`E2E` — never a design-time `FS<n>`, and a success metric `SM<n>` is
not a trigger either) backed by a captured non-success exit/HTTP/status** (a check that ran
and failed — not a pure gap with no captured evidence) → emit the repair plan (what failed →
smallest diagnosis → proposed fix → re-touched contract items, drawn conservatively — when uncertain,
include), apply the fix inline (no `ff-implement` re-entry), append the `## Repair` record, and
re-verify **only the named re-touched contract items** (ACs, the E2E check, or the bugfix item(s)), **once** — the
scoped repair re-verify does **not** re-clear `<run dir>/evidence/` (an explicit exception to
§Evidence, Evidence directory: every un-touched item's evidence is preserved). A prior `## Repair` section exists, a re-touched item
still fails, the failure is a pure gap or a failed `FS<n>`, or the run is step-by-step / lite tier
→ fall through to the Evidence gap stop above — never a second cycle. `phases.verify.status` stays
`in_progress` throughout; the cap is **per-phase** (independent of review's cycle) and carries **no
manifest field** — the `## Repair` section is the sole record. The waiver is untouched by this
cycle (it never upgrades confidence; autopilot never records one).

**Stale-phase re-run cycle (revision-bound runs, autopilot only).** Triggered at a done-transition
when the other assurance phase's revision is missing or differs from the current fingerprint
(**Revision agreement** in `docs/schema/terminal-convergence.md`). The stale phase's own artifact is
the durable one-cycle record, exactly as `## Resolution` / `## Repair`: before starting, check it
(`review.md` when review is stale, `verify.md` when verify is stale) for an existing
`## Stale re-run` section. **None** → re-run that phase's **Do the work** once, exactly as its own
command specifies (review: the focus reviewers **and** the spec-conformance reviewer; verify: the
full `ff-test-runner` dispatch and contract mapping, evidence cleared as on any fresh verify), append
`## Stale re-run` to its artifact (the old revision, the new one, the changed paths, the outcome),
re-stamp its `phases.<phase>.revision`, then re-check agreement. Agreement, and the re-run found
nothing blocking (no Critical finding; every contract item at `Verified (single-source)` or better)
→ continue the done-transition. **A prior `## Stale re-run` section exists, the re-run itself
changed code (its fixes moved the fingerprint again), a Critical finding or an evidence gap
remains, or the run is step-by-step** → STOP naming the phase to re-run and the changed paths —
never a second cycle. The re-run's own fix or repair cycle, if it has not been used yet, still
applies inside it; the cap carries **no manifest field** — the section is the sole record.

**Run-start procedure (every entry point that creates a manifest: `ff`, and the cold-start
paths of `ff-explore` / `ff-clarify` / `ff-diagnose`).** The value is resolved
**before the manifest is written** — the creation Write includes `autopilot`; a manifest
written with a self-chosen `autopilot` is a defect:
1. If a manifest for this run already exists with an `autopilot` field (any value) →
   **skip; never re-ask** — not on resume, re-run, or any later phase.
2. Read `toggles.autopilot` from config (`.feature-flow.json` →
   `${CLAUDE_PLUGIN_ROOT}/config/defaults.json`; default `"ask"`).
3. `"ask"` → ask the user once (AskUserQuestion): **autopilot** (phases chain automatically,
   pausing only at sign-offs, design choice, and Critical review findings) vs
   **step-by-step** (each phase stops; current behavior). `true` / `false` → use that value
   directly; no question. The boolean may come ONLY from config `true`/`false` or the
   user's in-conversation answer — **never choose `manifest.autopilot` yourself**; include
   it in the manifest creation Write.

**Resume.** `ff-resume` on a run with `autopilot: true` re-enters the first incomplete
phase and **continues the chain** to the next mandatory pause, honoring every gate exactly
as a live run would. With `false`/absent: run exactly one phase and stop (unchanged).

