# Assumption records — feature-flow manifest contract
> Part of the manifest contract. Core rules and the topic index: `docs/manifest-schema.md`.

## Assumption records

The single canonical contract for **structured assumption records**: what a Beat-4 assumption row
is, when its `validation-required: y` flag actuates, and how it is waived. `ff-clarify`,
`ff-diagnose`, and `ff-plan` reference this section by name and never restate it inline — the same
house style as §Planning intelligence and §Knowledge base above. Like WS-2's planning intelligence it
is **always-on**: no `toggles.*` key gates it and no new `manifest.json` field carries it — assumption
data lives inside the artifact, located solely via `manifest.artifacts.spec` / `.diagnosis` (the sole
locating authority, per **Durable artifact resolution**). This closes the same Actuation line WS-1/2/3
close: an assumption a human reads but no phase acts on is a documentation cost, not a capability.

### Row schema

Beat-4 assumptions are a **markdown table**, one row per assumption, header columns in this exact
order — replacing the former free-text bullets:

| Column | Values | Meaning |
|---|---|---|
| `Statement` | prose | the WHAT-changing assumption |
| `Confidence` | `low \| med \| high` | categorical only — **no numeric scores** (upholds §Evidence's ladder) |
| `Basis / evidence` | prose (may be empty) | why it is believed |
| `If-wrong impact` | prose (may be empty) | what breaks in scope/ACs if it is false |
| `Validation-required` | `y \| n` | the actuation trigger (below) |

**Positional identity:** an assumption's number is its **table row order** (first data row =
Assumption 1). Row order is **stable once written** — reordering rows silently breaks any
`**Validates:** Assumption N` reference (§Planning intelligence). There is no rendered number column
(it is outside the locked column set); position **is** N. A row is valid even when `If-wrong impact`
or `Basis` is empty — the trigger is the flag, not cell completeness.

### Tier / track scope

- **feature** — both tiers (`lite` and `full`) carry the table: both have a sign-off gate to echo into.
- **bugfix** — **full tier only**. A `lite` bugfix has **no sign-off gate** (`diagnosis.md` reads
  `n/a (lite)`), so it carries no assumptions table and no echo — consistent, not an exception.

### Trigger — `validation-required: y` alone

The actuation trigger is the `validation-required: y` flag **by itself** — **author-set, never
derived**. `Confidence` and `If-wrong impact` are descriptive context that inform the author's
judgment; they do **not** couple into the trigger (there is no "flag AND high impact" rule). An
assumption validated during clarify/diagnose (the user answers it) is marked `n` and no longer
actuates.

### Actuation 1 — the sign-off echo (feature both tiers; bugfix full)

At the sign-off gate, every **still-unvalidated** `validation-required: y` assumption is **echoed** in
the sign-off ask and **blocks a clean (silent) sign-off**: the run cannot reach `signOff.signed = true`
until the user **resolves each one** — **(a) validate** it now (mark it `n` — no task), **(b) waive**
it (**mark it `n`** and record the verbatim line below as the audit trail; accepted risk — no task), or, **full tier only, (c) acknowledge it stays
open** (the row remains `y` and is carried into the full-tier plan for **Actuation 2** to spawn a
`**Validates:**` task). Exit (c) requires a plan to carry the row into, so it is **full-tier only**: a
**lite** feature (no plan phase) resolves via (a) or (b) only — the assumption safety net still fires,
but there is no defer-to-plan option. What the gate forbids is a *silent* sign-off that never surfaces
the assumption — **not** a consciously-acknowledged open assumption carried forward as tracked work. The echo's
**rendering shape** is owned by
§Sign-off rendering **rule 3** (a distinct trailing block after the contract checklist, never folded
into the `- [ ] AC<n>` boxes, always states the true status). This is the **Evidence-gap-stop shape**
— a turn-ending, waivable stop on a *transition* — **not** the do-not-contradict STOP (§Decision
recall / §Critical-path check): an unvalidated assumption is *unaddressed*, not *contradicting*, so
there is nothing to diff. Consequently the §Autopilot row below must **not** carry the word
"unconditional" (that word is the do-not-contradict marker).

### Actuation 2 — the plan validation task (full tier)

On the **full** tier, `ff-plan` maps each still-unvalidated `validation-required: y` assumption
carried from the signed spec/diagnosis — the **exit-(c) "acknowledged-open" rows** of Actuation 1,
neither validated nor waived — to **≥1 task's `**Validates:** Assumption N` line**, or records
it as an explicit named coverage gap — cloning the `**Covers:**` AC→task discipline (§Planning
intelligence). A validation task logically precedes the tasks that depend on the assumption (the
lower-numbered dependency invariant). A **waived** assumption spawns **no** task (waive = accepted
risk, not deferred work); an assumption validated at sign-off likewise spawns none. Because exits (a)
and (b) both **mark the row `n`** (see Waiver), a surviving `validation-required: y` row *is* an
acknowledged-open row — the flag alone selects Actuation 2's targets, with no cross-referencing of the
waiver line, so `ff-plan` resolves them from the artifact in any session (never from conversational
memory).

### Waiver

The waiver is the verbatim line, recorded in the spec/diagnosis:

    Assumption validation waived by user (<date>): <reason>

It may be recorded **only from the user's own in-conversation words** — never assistant-authored,
inferred, or dated by the assistant, and **never on autopilot's behalf** (see the §Autopilot
"Assumption validation stop" row). Mirrors the §Evidence waiver exactly. A waiver **marks the row
`Validation-required: n`** — the verbatim line is the audit trail recording *that* the row was resolved
by waiver (accepted risk), not by empirical validation, and *why*. It **does not change the
assumption's recorded `Confidence`** or `Statement`. The `Validation-required` flag records
*resolution state*: validate and waive both set `n`; only exit-(c) acknowledge-open leaves `y`, so a
surviving `y` unambiguously marks Actuation 2's task target — readable from the artifact alone, never
from conversational memory. Telling a *waived* `n` from a *validated* `n` per-row is **not**
load-bearing — neither spawns a task nor echoes, and no phase branches on the difference — so it needs
no on-disk index; the waiver line's `<reason>` is the human record, not a machine key (per-row waiver
identification is out of scope).

### v1 non-goals

Stated, not silent: **no negative-outcome re-entry** (a validation task later proving an assumption
*wrong* during implement does not auto-reopen clarify/design — a named future workstream); **no
numeric confidence or scoring** (upholds §Evidence); **no new manifest field, no `toggles.*` key, no
new phase** (always-on, artifact-resident, WS-2 posture); **no automated regression guard for the echo
actually firing** (the catch is semantic — a fresh-session self-run, named in the CHANGELOG, same
posture as the Decision-recall / Critical-path behavioral ACs); **no cross-run KB recall of past
assumptions**.

