# Design trade-offs & devil's advocate — feature-flow manifest contract
> Part of the manifest contract. Core rules and the topic index: `docs/manifest-schema.md`.

## Design trade-offs & devil's advocate

The single canonical contract for the **design-time adversarial pass**: the lean trade-off matrix,
the devil's-advocate failure-scenario list, and how a named scenario actuates at verify. `ff-design`,
`ff-verify`, and `templates/design.md` / `templates/verify.md` reference this section by name and
never restate it — same house style as §Planning intelligence and §Assumption records above.
**Full tier, feature track only** — the bugfix track has no design phase, and lite skips `ff-design`
by construction (§Field notes). **Always-on:** no `toggles.*` key gates it and **no new
`manifest.json` field** carries it — the matrix and failure scenarios live inside `design.md`,
located solely via `manifest.artifacts.design` (the sole locating authority, per **Durable artifact
resolution**). This closes the same Actuation line WS-1/2/4 close: a failure scenario a human reads
but no phase acts on is a documentation cost, not a capability.

### Trade-off matrix

`ff-design` scores **every** option the architect considered (chosen + rejected, not only the
winner) in `design.md`'s
`## Trade-off matrix` on three **core axes**, every run: **Complexity**, **Risk / operational
impact**, **Test effort** — categorical (`low | med | high`), never numeric (upholds §Evidence's
no-numeric-scores doctrine). Any other axis (performance, maintainability, scalability, security,
cost) is added as an extra column **only when it actually differentiates** the options — dropped,
never padded in. The matrix is not an actuator by itself; it is the structured input the
devil's-advocate pass and `decision.md`'s Trade-offs row are both derived from.

### Devil's-advocate notation

Scoped to the **chosen** option only. Each concrete failure scenario is a labeled `**FS<n>:**`
bullet under `design.md`'s `## Devil's advocate → ### Failure scenarios` — an **explicit inline
label** (write order, `FS1` first), because `ff-verify` quotes it verbatim into a `### FS<n>` block
exactly as it quotes a spec `AC<n>` from the acceptance-criteria checklist (the closer analog is the
AC checklist, not §Assumption records' positional-only table — both AC and FS are consumed as
literal contract-item headers). **At least one scenario is required** for every full-tier design,
even one with a single obvious option. Edge cases and migration/operational risks accompany the list
as prose in the same section — context, **not** contract items.

### Actuation — the FS<n> contract item (feeds ff-verify)

`ff-verify` resolves `design.md` via `manifest.artifacts.design` (full tier; absent on lite, on the
bugfix track, or on a pre-WS-5 design → skip, no FS blocks, never a STOP) and maps each named
failure scenario into its own `### FS<n>` block in `verify.md`'s `## Contract mapping` — **exactly
as an acceptance criterion is mapped**: same four Confidence-ladder levels (a design-time failure
scenario is one of the contract-item classes listed in §Evidence → Confidence ladder), same
evidence-gap-stop shape. An `FS<n>` stuck at `Partially verified` or `Unverified` holds the run at
the existing **Evidence gap stop** (§Autopilot) — the SAME turn-ending, waivable stop an unverified
AC already uses, **not** the do-not-contradict STOP (an unproven scenario is *unaddressed*, not
*contradicting*). It is cleared by proving it, or by the SAME verbatim `Evidence gap accepted by
user (<date>): <reason>` waiver ACs use (§Evidence, Evidence waiver) — **no new waiver line is
minted, no new §Autopilot row, no new hook**: the existing "Evidence gap stop" row already
generalizes over "any contract item," and Gate B (`hooks/enforce-gate`) is already scenario-agnostic.

### decision.md reconciliation

`ff-design` **derives** `decision.md`'s existing `## Trade-offs` row (`Effort | Risk |
Reversibility`, pinned unchanged by `decision-record-guard.sh`) from this matrix — Complexity + Test
effort → Effort, Risk / operational impact → Risk, Reversibility assessed as before — **never a
second, divergent scoring pass** — and names the chosen option's failure scenario(s) in
`## Chosen + rationale` **by reference** (`see design.md §Devil's advocate`), never copied verbatim.
`design.md` stays the single source of truth for the `FS<n>` list and its numbering (mirrors
§Assumption records' single-canonical-home discipline); `decision.md`'s schema is unchanged and
grows no numbered FS list.

### v1 non-goals

Stated, not silent: **no new `manifest.json` field, no `toggles.*` key, no new phase, no new
§Autopilot row, no new waiver line** (always-on, artifact-resident, reuses the evidence-gap stop
verbatim — WS-1/2/4 posture); **no numeric trade-off or risk scoring** (upholds §Evidence); **no
per-item on-disk distinction between an FS waiver and an AC waiver** (accepted — FS carries no
validation-required flag the way an assumption does; reopen only if a future workstream audits
FS-waiver rates); **no bugfix-track devil's-advocate pass**; **no automated regression guard** for an
`FS<n>` block actually blocking `done` and a covered scenario not false-firing — that catch is
semantic, a fresh-session STOP-vs-control self-run, named in the CHANGELOG (same posture as the
Decision-recall / Critical-path / Assumption-echo behavioral ACs).

