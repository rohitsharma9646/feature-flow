# Discovery fields — feature-flow manifest contract
> Part of the manifest contract. Core rules and the topic index: `docs/manifest-schema.md`.

## Discovery fields

Two **optional, full-tier** structured fields in `spec.md` (added WS-7, v0.17.0), each **actuating**
a downstream phase rather than merely recording — the v2 guardrail that a field only a human reads is
a documentation cost, not a capability. Always-on, **artifact-resident**: both live inside `spec.md`
and are located solely via `manifest.artifacts.spec` (the sole locating authority) — **no new
`manifest.json` field, no `toggles.*` key, no new phase, no new hook.** A pre-WS-7 spec, or any spec
omitting a section, resolves unaffected. `ff-clarify` prompts for them only on **non-trivial
full-tier** work; a **lite** spec omits both with no placeholder and no warning (the template is
shared by both tiers, so the gate is a **presence check on the section's rows**, never a read of
`manifest.tier`).

### Success metrics

A `## Success metrics` section of **binary-threshold** rows — "metric M ≤/≥ T, measured by
`<method>`" — reusing the binary, checkable **acceptance-criterion discipline** (that section owns it;
this is not a divergent grammar). A metric that cannot be phrased as a checkable threshold is rejected
at clarify, never recorded as a soft/directional statement. An SM's number is its row order (first
row = SM1), stable once written. Metrics are **verify-time** items, **not** part of the sign-off
render — §Sign-off rendering stays "Three rules".

### Requirement graph

A `## Requirement graph` `| AC | Depends on |` table reusing §Planning intelligence's **dependency
notation** verbatim (not a divergent grammar): `Depends on` names only a strictly **lower-numbered**
`AC<n>` (or "— (root)") already defined under `## Acceptance criteria`, so a cycle is unexpressible —
the same lower-numbered invariant the task graph carries. Only dependent ACs need a row; an
all-independent spec omits the section.

### Actuation 1 — the SM<n> contract item (feeds ff-verify)

`ff-verify` resolves `spec.md` via `manifest.artifacts.spec` (already read in Cold-start; no new
pointer) and maps each `## Success metrics` row into its own `### SM<n>` block in `verify.md`'s
`## Contract mapping` — **exactly as an acceptance criterion is mapped**: the same four
Confidence-ladder levels (a success metric is one of the contract-item classes listed in §Evidence →
Confidence ladder), the same evidence-gap-stop shape. An `SM<n>`
stuck at `Partially verified` or `Unverified` holds the run at the existing **Evidence gap stop**
(§Autopilot) — the SAME turn-ending, waivable stop an unverified AC or `FS<n>` already uses, **not**
the do-not-contradict STOP — cleared by proving it or by the SAME verbatim `Evidence gap accepted by
user (<date>): <reason>` waiver. **No new waiver line, no new §Autopilot row, no new hook**: the
Evidence gap stop already generalises over "any contract item," and the unfilled `### SM1:`
placeholder's Gate-B digit-free safety is proven end-to-end by `enforce-gate-guard.sh`'s `b-template`
fixture (which copies the whole shipped `verify.md` through the real hook) — never re-derived.
**Presence, not tier, gates:** unlike `FS<n>` (whose home `design.md` structurally never exists on
lite), `## Success metrics` lives in the one shared `spec.md` template, so absent-or-empty gates —
never `manifest.tier`.

### Actuation 2 — task-dependency derivation (feeds ff-plan)

`ff-plan` derives edges in the plan's **existing** `## Dependency graph` — §Planning intelligence's
same table, notation, and lower-numbered invariant; this adds only the AC-edge → task-edge
translation, it does **not** widen `templates/plan.md` (no new column, no new table). For each
`AC_i depends-on AC_j` edge in `## Requirement graph`: every task whose `**Covers:**` line names
`AC_i` depends on every task covering `AC_j`.

**Order-at-decomposition, never renumber.** Task numbering is an *output* choice `ff-plan` makes
while authoring the plan (unlike AC numbers, pinned at spec sign-off), so `ff-plan` numbers tasks to
satisfy the AC-derived edges **as it decomposes** — a valid topological order always exists unless an
edge is un-derivable. This is **not** a backward re-sort of already-written tasks (which would rewrite
`**Covers:**`/`**Validates:**` references — the "second divergent pass" §Assumption records' row
stability forbids). An edge that cannot be represented as a lower-numbered task dependency — the same
task covers both `AC_i` and `AC_j` (a self-edge), or no numbering satisfies it (e.g. multi-task
coverage forcing a forward edge) — surfaces as an **explicit named gap under the plan's Outcome gate**
naming the reason (e.g. `AC_i depends-on AC_j: covered by the same Task <n>`), never silently dropped
and never forced with a forward-pointing `Depends on`. Rendered in the Outcome gate's requirement-graph rule bullet
(`templates/plan.md`), alongside the existing AC-coverage and Assumption-validation gap bullets.

### Touchpoints

A `## Touchpoints` list (added v0.20.0) of the concrete files, modules, and interfaces the change
is expected to touch, taken from `explore.md` — *which* parts, never *how* (that is `ff-design`).
**Both tiers.** Actuation: the `ff-review` spec-conformance reviewer reads it as its scope
reference — a changed file far outside it is the usual out-of-scope signal (reported Important),
a necessary neighbour of a touchpoint is not. Absent section (older spec) → the reviewer judges
scope from the ACs and `## Non-goals` alone.

### End-to-end check

A `## End-to-end check` row (added v0.20.0): one check that proves the **whole** feature works as a
user would use it — a command, request, or flow run end to end with its observable result — under
the same binary discipline as an acceptance criterion (not a divergent grammar), and not a
restatement of one AC. **Both tiers, lite included** — it is the cheapest proof that the parts
compose. Like success metrics it is a verify-time item, not part of the sign-off render.

### Actuation 3 — the E2E contract item (feeds ff-verify)

`ff-verify` maps the `## End-to-end check` row into an `### E2E` block in `verify.md`'s
`## Contract mapping` **exactly as an acceptance criterion is mapped** — Actuation 1's shape
verbatim: same Confidence ladder, same Evidence gap stop, same waiver line, no new stop or row. It
is proven by running the stated command / flow end to end, never by pointing at per-AC evidence.
**Presence, not tier, gates** (the section lives in the shared spec template): absent or empty →
no E2E block, no gap. The `### E2E:` placeholder is digit-free for Gate B, proven by
`enforce-gate-guard.sh`'s `b-template` fixture like `### SM1:`.

### Tier / track scope

**Success metrics and the requirement graph: feature track, full tier only.** Lite features omit
both sections (no design/plan weight added to lite); the bugfix track has no `spec.md` and no
requirement graph. **Touchpoints and the end-to-end check: feature track, both tiers.** Every
actuation skips cleanly by presence check when its section is absent — a pre-WS-7 (or pre-v0.20.0)
spec is byte-identically unaffected.

### v1 non-goals

Stated, not silent: **no `## Stakeholders` field** (cut — no downstream consumer, so it would fail
guardrail #9); **no new `manifest.json` field, no `toggles.*` key, no new phase, no new §Autopilot
row, no new waiver line** (always-on, artifact-resident, reuses the evidence-gap stop and the
Outcome-gate gap verbatim — WS-1/2/4/5 posture); **no fourth §Sign-off rendering rule / no metrics
echo in the sign-off ask** (metrics are verify-time items); **no directional/soft metrics** (binary
thresholds only, upholding §Evidence); **no task renumbering pass** (order-at-decomposition instead);
**no automated regression guard** for a success metric actually blocking `done` and an un-derivable
requirement-graph edge actually surfacing at the Outcome gate — that catch is semantic, a
fresh-session fired-vs-control self-run, named in the CHANGELOG (same posture as the Decision-recall /
Critical-path / Assumption-echo / FS<n> behavioral ACs).

