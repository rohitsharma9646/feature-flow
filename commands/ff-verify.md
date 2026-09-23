---
description: "[shared] Run the project's tests/build/lint via ff-test-runner and map the contract to pass/fail with evidence."
argument-hint: "<run after /feature-flow:ff-implement (and /feature-flow:ff-review)>"
---

# /feature-flow:ff-verify — verification phase

Real, executed verification. Output: `verify.md` with evidence. This phase refuses to
declare "done" on reasoning alone.

> **Precedence — read first.** You are executing the feature-flow workflow. Its phases
> REPLACE any generic brainstorming / writing-plans / make-plan / docs-first planning: do
> **not** invoke those skills, and do **not** write to `~/.claude/plans/`, `docs/plans/`,
> or a separate brainstorm doc. All run state lives in the `.feature-flow/<slug>/` sandbox
> and its `manifest.json`. Follow this command's steps literally, create files with the
> Write tool, run only this one phase, then STOP. In autopilot mode, ceremonial phase-end
> STOPs become continuations — see **Autopilot** in
> `${CLAUDE_PLUGIN_ROOT}/docs/manifest-schema.md`.

> **Integrity boundary — before every manifest state write:** run the canonical Command-level
> preflight in `docs/manifest-schema.md`; follow its legacy/current mode rule and stop on an
> enforce-mode denial or invocation failure.

## Manifest contract

1. **Resolve the run** per **Run resolution** in
   `${CLAUDE_PLUGIN_ROOT}/docs/manifest-schema.md` (named slug → else the single /
   most-recently-updated run → ask if ambiguous), then read its `manifest.json`.
2. **Re-run guard:** if `phases.verify.status` is already `"complete"`, stop and ask for
   explicit confirmation before overwriting `verify.md` — see **Re-run guard** in
   `${CLAUDE_PLUGIN_ROOT}/docs/manifest-schema.md`.
3. Set `phases.verify.status = "in_progress"`, bump `currentPhase`.

## Cold-start

**Resolve the contract artifact through the manifest pointer first:** take the spec from
`manifest.artifacts.spec` (feature) or the diagnosis from `manifest.artifacts.diagnosis`
(bugfix) — manifest-first, sandbox fallback `<base>/<slug>/<name>.md` only when the manifest
is absent. There is no contract to verify against without an upstream artifact — route, don't
ask open-endedly: if the resolved spec is missing on the feature track, **STOP** and tell the
user to run `/feature-flow:ff-clarify` first; if the resolved diagnosis is missing on the
bugfix track, **STOP** and tell the user to run `/feature-flow:ff-diagnose` first.

**Also resolve the design (feature track, full tier only), for its failure scenarios.** Read
`manifest.artifacts.design` the same manifest-first way. **Absent is not an error and never a
STOP** — a pre-WS-5 run, a lite run (design never runs on lite), and a full-tier design that named
zero failure scenarios all resolve to "no FS items to map." When present, its `## Devil's advocate
→ ### Failure scenarios` is the source the contract mapping below reads (§Design trade-offs &
devil's advocate).

## Do the work

Read `models.testRunner` from config (`.feature-flow.json` →
`${CLAUDE_PLUGIN_ROOT}/config/defaults.json`) and pass it as the `model` for the dispatched
agent. Dispatch the **`ff-test-runner`** agent, telling it the run's `tier`. It detects and
**actually runs** the project's test / build / lint commands **and the project's detected
evidence surfaces** — e2e/browser (Playwright CLI), http/api, db, cli-output, logs,
before/after — per the evidence-kind taxonomy in `${CLAUDE_PLUGIN_ROOT}/docs/manifest-schema.md`
§Evidence (follow that canonical contract; do not restate it here). It returns evidence
records with real status codes and files under `<run dir>/evidence/`. It never edits code.

**Tier scaling (§Evidence, Tier scaling):** the floor — executed test/build/lint mapped per
contract item with real exit codes — is tier-invariant; **lite** runs stop there (the
coverage matrix collapses to its lite note). **Full** runs also fill the Evidence coverage
matrix from the runner's detection data and are expected to gather every detected kind.

**Evidence authority — record, never paraphrase.** The test runner's returned evidence
records `{kind, command, actual exit/HTTP status, excerpt, artifact paths}` are the evidence
of record; transcribe them into `verify.md` literally. A contract item may be marked `pass`
**only** when it is backed by a captured command with a success exit/HTTP status — never on
the runner's narration alone, never on your own reasoning, and never inferred from "it looks
right." A result without a captured status is `manual-unverified`, with the reason said.
Apply the **Detection and N/A rule** in §Evidence to every kind — detected-but-not-passed is
an explicit gap, never a silent omission or an `N/A`. Do not re-author or upgrade the
runner's verdict; you only map its real output to the contract.

**Derive confidence mechanically** per §Evidence, **Confidence ladder** — count the
**distinct** evidence kinds that passed per contract item; overall = the minimum across
items. Never invent, eyeball, or numerically score a level; the schema owns the ladder —
do not restate it here.

Build the contract mapping in `verify.md` from `${CLAUDE_PLUGIN_ROOT}/templates/verify.md`:

- **Feature track:** map **each acceptance criterion** from the spec (at `artifacts.spec`, as
  resolved in Cold-start) → `pass` / `fail` / `manual-unverified` (with a reason), each backed
  by evidence from the test runner.
- **Feature track — success metrics:** additionally map **each row** of the spec's `## Success
  metrics` (resolved via the already-read `artifacts.spec` — no new pointer) into its own `### SM<n>`
  contract item, **exactly as an acceptance criterion is mapped** — same `pass` / `fail` /
  `manual-unverified` derivation, the same §Evidence Confidence ladder, and the same evidence-gap
  stop + waiver line below (there is **no** separate success-metric waiver: an unproven SM is
  `manual-unverified`, identical to a manual AC). Absent `## Success metrics`, or a section with no
  rows (lite tier, or a pre-WS-7 spec) → skip, no SM blocks, no gap. This is a **presence check on
  the section's rows, not a tier check** — unlike `FS<n>` (gated structurally because the design
  artifact never exists on lite), the one shared spec template underlies both tiers, so
  content-absence gates (§Discovery fields → Actuation 1).
- **Feature track, full tier (`artifacts.design` present):** additionally map **each `**FS<n>:**`
  bullet** from the design's `## Devil's advocate → ### Failure scenarios` (resolved in Cold-start)
  into its own `### FS<n>` contract item, **exactly as an acceptance criterion is mapped** — same
  `pass` / `fail` / `manual-unverified` derivation, the same §Evidence Confidence ladder, and the
  same evidence-gap stop + waiver line below (there is **no** separate failure-scenario waiver: an
  unproven FS is `manual-unverified`, identical to a manual AC). Absent `artifacts.design`, or a
  design naming no scenarios (lite tier, or a pre-WS-5 design) → skip, no FS blocks, no gap.
- **Bugfix track:** confirm the bug no longer reproduces, and that the regression test
  shows RED (pre-fix) → GREEN (post-fix). Cite the `bugfix.red` / `bugfix.green` evidence
  captured by `/feature-flow:ff-implement` for the pre-fix failure, and the test runner's fresh run for
  the post-fix pass. If the manifest has no `bugfix.red` evidence, the fix was not done
  test-first — report it **incomplete** (the RED state can no longer be reconstructed).
- Assess **regression risk** (`Low | Medium | High` + reason) from the surface the change
  touched — shared / central code raises it, isolated new code lowers it — **cross-referencing
  the plan's `## Risk register`** when a full-tier plan exists: read it via
  `manifest.artifacts.plan` (the sole locating authority), per the canonical **Planning
  intelligence** contract in `${CLAUDE_PLUGIN_ROOT}/docs/manifest-schema.md` — cite any register
  entry whose surface the just-verified change touched and whether it materialized (do not
  re-derive a risk the register already named), then assess whatever the register did **not**
  anticipate. No plan (lite tier, or a pre-WS-2 plan with no register) → derive risk cold from
  the touched surface alone, as before. Record the combined assessment in `verify.md`
  §Regression risk. No numeric score.

## Refuse premature "done" (evidence gap stop)

A contract item is done-eligible only at `Verified (single-source)` or `Verified
(multi-source)`. If **any** item sits at `Partially verified` or `Unverified`, the run is
**not done** — but first, on autopilot, check whether the bounded one-cycle repair applies.

- **Autopilot repair-and-re-verify cycle** (`manifest.autopilot: true` **and** `tier == "full"`
  only — mirrors the review cap; step-by-step and lite never enter this bullet). The trigger (a
  **captured non-success** status on an acceptance criterion or bugfix item — a check that ran and
  failed, never a pure gap and never a design-time `### FS<n>`), the one-cycle cap, and the
  fall-through conditions are the canonical **Repair-and-re-verify cycle** contract in
  `${CLAUDE_PLUGIN_ROOT}/docs/manifest-schema.md` §Autopilot — do not restate them here.
  Operationally: when it applies and `verify.md` has **no** prior `## Repair` section, emit a short
  repair plan (what failed → smallest diagnosis → proposed fix → the contract items it re-touches,
  drawn conservatively), apply the fix inline (no re-entry to `/feature-flow:ff-implement`), append
  the `## Repair` section (`${CLAUDE_PLUGIN_ROOT}/templates/verify.md`), then re-verify **only the
  named re-touched contract items** (ACs or the bugfix item(s)) by re-dispatching `ff-test-runner`
  — tell it explicitly this is a **scoped repair re-verify** so it does **not** clear
  `<run dir>/evidence/` (an explicit **exception to the start-of-verify evidence-clear rule**,
  preserving every un-touched item's evidence) — mapping its output back onto only those items'
  blocks, **exactly once**. Every re-touched item clears to `Verified (single-source)` or better and
  nothing else sits below that floor → proceed to **Update manifest + hand off** below; otherwise
  fall through to the gap-report STOP below — never a second cycle.
- **Otherwise (no repair applies, or the one cycle still leaves a gap):** render the report anyway
  (true confidence levels, gaps stated), then **STOP — end the turn with the gap report**, shaped:

> Verification found evidence gaps — this run is NOT done:
> - AC<n>: <requirement> — <Partially verified | Unverified> — <what could not be verified, why>
> To proceed: (a) address the gap and re-run `/feature-flow:ff-verify`, or (b) reply with an
> explicit waiver per gap — it will be recorded in `verify.md` as
> `Evidence gap accepted by user (<date>): <reason>` and the done transition re-attempted.

Record the waiver **only** per §Evidence, **Evidence waiver** (from the user's own reply,
never self-authored — the **Evidence gap stop** row in §Autopilot,
`${CLAUDE_PLUGIN_ROOT}/docs/manifest-schema.md`). If automated tests are absent, say so —
run build/lint/smoke instead and never call a no-tests run a pass. On the bugfix track, a
fix without a regression test (RED→GREEN evidence) is reported **incomplete**, not done.

## Update manifest + hand off (order differs by track)

Which command marks the run `done` is the canonical **Terminal convergence** rule in
`${CLAUDE_PLUGIN_ROOT}/docs/manifest-schema.md`; the per-track routing below implements it (it
does not re-derive it).

Resolve the report's path per the **Durable artifact resolution** rule in
`${CLAUDE_PLUGIN_ROOT}/docs/manifest-schema.md` (`verify` is durable-eligible:
`paths.durable` → `<paths.durable>/<D>-<slug>/verify.md`, else sandbox
`<run dir>/verify.md`; **create the target directory if absent**). **Use the Write tool**
to write `verify.md` at the resolved path. When the report promotes out of the sandbox,
copy the evidence directory alongside it — `rm -rf "<durable dir>/evidence" && cp -r
"<run dir>/evidence" "<durable dir>/evidence"` (replace, never merge — a bare `cp -r` into
an existing destination nests `evidence/evidence` on re-promotion) — so the report's
relative links keep resolving (**Evidence companion copy**, §Durable artifact resolution;
copy, never move the sandbox original). Record the resolved path
in **both** `artifacts.verify` and `phases.verify.artifact`: set
`phases.verify = { status: "complete", artifact: "<resolved verify path>" }`, bump `updatedAt`.

- **Feature track:** verify is the **terminal** phase. If all contract items pass, first run
  **KB capture** (see `## KB capture (when enabled)` below — a no-op unless the KB is active),
  then set `currentPhase = "done"`. **STOP** and report the run complete.
- **Bugfix track:** review is the terminal phase, so the two can be run in either order —
  converge on `done` only when **both** verify and review are complete:
  - If `phases.review.status == "complete"` (review already ran) and verify passed, both
    terminal phases are satisfied → this command is the one reaching the done-transition, so
    first run **KB capture** (see `## KB capture (when enabled)` below — a no-op unless the KB is
    active), then set `currentPhase = "done"` and report the run complete.
  - Otherwise review still has to run. If `manifest.autopilot` is `true`, emit the progress
    strip and proceed directly into the review phase per
    `${CLAUDE_PLUGIN_ROOT}/commands/ff-review.md` — see **Autopilot** in
    `${CLAUDE_PLUGIN_ROOT}/docs/manifest-schema.md`. If `false` or absent: leave
    `currentPhase = "verify"`, **STOP**, report the RED→GREEN result, and tell the user to
    run `/feature-flow:ff-review` next.

Report the verification result (pass/fail per contract item, with evidence), end the message
with the one-line progress strip — see **Progress strip** in
`${CLAUDE_PLUGIN_ROOT}/docs/manifest-schema.md` — and end your turn.

## KB capture (when enabled)

Runs whenever **this command transitions the run to `currentPhase = "done"`** — i.e. the
**feature-track terminal** (verify is always feature-terminal) **and** the **bugfix convergence**
branch above where review already completed and verify now passes. Sequenced **after** `verify.md` +
the manifest update but **before** `currentPhase = "done"`, so a dropped session re-runs verify and
re-fires the gate. **Skip** when this command is *not* the one reaching `done` — on the bugfix track
when review has not run yet (verify hands off to `/feature-flow:ff-review`, which fires capture at
its own done-transition). Capture fires at **exactly one** command — whichever sets `done` — so the
bugfix track never double-captures.

It is a **no-op unless the KB is active** (`toggles.kb === true` AND `paths.kb` non-null, read from
`.feature-flow.json` → `${CLAUDE_PLUGIN_ROOT}/config/defaults.json`). When inactive, do nothing and
proceed to `currentPhase = "done"` — behavior is byte-identical to today.

When active, follow the **Knowledge base** capture rule in
`${CLAUDE_PLUGIN_ROOT}/docs/manifest-schema.md` exactly — that is the canonical procedure (git SHA
→ provenance, distill 1–3 candidates, the cross-turn confirm gate, write accepted entries from
`${CLAUDE_PLUGIN_ROOT}/templates/kb-entry.md`, **no** `git add`/`commit`, reject-all writes
nothing); **do not restate its steps here.** The only command-specific input: read this run's
artifacts **only** via `manifest.artifacts.<name>` pointers (never bare filenames) — **feature
track:** the spec (`artifacts.spec`) + design (`artifacts.design`, if present); **bugfix track:**
the diagnosis (`artifacts.diagnosis`) + plan (`artifacts.plan`, if escalated); both tracks: plus
this `verify.md` and the review (`artifacts.review`).
