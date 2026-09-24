# Retrospective — feature-flow manifest contract
> Part of the manifest contract. Core rules and the topic index: `docs/manifest-schema.md`.

## Retrospective

The **retrospective** phase is **optional, post-terminal, and confirm-gated** (added v0.18.0). It runs
*after* a run reaches `currentPhase = "done"` and records **what the workflow's own safeguards did** on
this run — which gates, STOPs, cycles, and waivers fired, whether each worked, and where the fix for any
failure belongs. It is **not** a second KB: the KB captures *project* decisions and conventions; the
retrospective captures *workflow* behavior (feature-flow's own safeguards). `ff-retro` is the only
command that touches it; it is **never chained by autopilot** (see §Autopilot) and never answered on the
user's behalf. This is the canonical contract; `ff-retro` references it by name and never restates it
inline — same house style as §Delivery.

### Manifest shape (absent-defaulted)

- `phases.retro` (`{ status, artifact }`, the generic phase shape) and `artifacts.retro` (the resolved
  path of `retro.md`) — both **absent-defaulted** (never ran = optional, not-yet-run; never
  missing-and-invalid). No migration.
- **`currentPhase` stays `"done"` and the `currentPhase` enum is NOT extended with `retro`** — the
  §Delivery rule, reused verbatim: `done` is the immutable terminal; retro is tracked only in
  `phases.retro`.
- `retro` is **durable-eligible** (§Field notes): with `paths.durable` set, `retro.md` lands in
  `<paths.durable>/<D>-<S>/retro.md`; otherwise in the sandbox.

### Activation

Any `done` run — **either track, either tier (lite included, unlike delivery), closed or not**
(`closedAt` is left untouched). A run whose `currentPhase` is not `done` (in progress, or abandoned)
STOPs with a message naming its current phase and writes nothing. A second invocation on a run whose
`phases.retro.status` is `complete` goes through the **Re-run guard**.

### Signals (the closed list — never transcript-mined)

`ff-retro` resolves upstream artifacts **only** via `manifest.artifacts.<name>` (`spec` or
`diagnosis`, `design`, `decision`, `plan`, `review`, `verify`, `delivery` — each optional; an absent
one is "not available", never invented) and scans them for exactly these on-disk safeguard signals:

1. **User override / waiver lines** — `Decision override by user`, `Critical-path override by user`,
   `Assumption validation waived by user`, `Evidence gap accepted by user`, `sign-off waived by user`.
2. **Cycle records** — review `## Resolution` (a fix-and-re-review cycle ran), verify `## Repair`
   (a repair-and-re-verify cycle ran).
3. **Unproven contract items** — any AC / bugfix item / `FS<n>` / `SM<n>` / `E2E` left below
   `Verified (single-source)` in the final `verify.md`.
4. **Critical review findings** — raised, whether or not later resolved.
5. **`⚠ DELIVERY GAP:` lines** in `delivery.md`.
6. **User notes** — free text passed to `ff-retro` (friction that left no disk trace; the only way it
   is captured).

### Materiality test

A candidate is proposed **only if both** hold: **(a)** it traces to a specific signal above (or a
user note), and **(b)** that signal does not fully close it — the safeguard **failed**, was **missing**,
was **bypassed**, fired **ambiguously**, or the event **recurred / cost a cycle**. A clean waiver of a
one-off gap, or a gate that fired once and was resolved exactly as designed, is **not** material on its
own (it may still be proposed as `worked` when the user's notes ask about it). No signal and no notes →
no candidates.

### Candidate schema (nine fields, categorical — no numeric scores)

| Field | Content |
|---|---|
| Event | what happened, one line |
| Expected | what the workflow should have done |
| Observed evidence | an artifact path or a quoted line — never a paraphrase |
| Impact | effect on scope, quality, safety, time, or confidence |
| Safeguard | the gate / STOP / cycle / guard / instruction that applies |
| Safeguard result | `worked` · `failed` · `missing` · `ambiguous` · `bypassed` |
| Generalizability | `one-off` · `repo-specific` · `reusable` |
| Recommended owner | `repo instructions` · `run artifacts` · `feature-flow command/skill` · `feature-flow reference doc` · `guard/validator script` · `regression/forward test` · `new skill` · `no change` |
| Proposed validation | how a fix would be shown to work |

A finding whose owner is **`regression/forward test`** states its proposed validation as
**Fired input / Expected outcome / Control input** (control when applicable) — the case shape in
`evals/forward/README.md` in the feature-flow repository (repo-internal, not shipped with the
plugin), so it converts 1:1 into a forward-test case. `ff-retro` never creates the
case (or any other fix) itself. **`new skill`** is recommended only when the need has a distinct
intent, recurs across repositories, has a clear owner, and no existing command can own it.

### Confirm gate (cross-turn, mandatory in both modes)

The **KB capture confirm-gate shape**, reused (§Knowledge base → Capture rule): `ff-retro` presents
the candidates and **ends its turn**; **nothing is written until the user accepts, edits, or rejects
each one**. The user's own reply is the only input that resolves it — autopilot, a headless
session, or the assistant never answers it. It is a **passive confirm gate**: not an unconditional
STOP (nothing is wrong), not a capped cycle (nothing retries). Zero candidates → the gate says
**"no material events"** and still waits for the user's confirmation.

### Write mechanics

On confirmation, write `retro.md` from `templates/retro.md` at the **Durable artifact resolution**
path, containing **only accepted findings** (as edited) plus the **rejected count**. Zero candidates
proposed → the findings section reads `_No material events._`; candidates proposed but all rejected →
`_No accepted findings — see Rejected._` (the record never says "no material events" when events were found). Record the path in **both**
`artifacts.retro` and `phases.retro.artifact`, set `phases.retro.status = "complete"`, bump
`updatedAt`. **Nothing else is created or modified** — no KB entry, no code, no instruction or skill
edit, no `git add`/`commit`. Improvements are separate, user-initiated work.

### v1 non-goals

- Applying any improvement, or scaffolding forward-test cases, from a finding.
- Writing KB entries (KB capture already ran at the done-transition).
- Transcript mining — only on-disk signals and user notes.
- A machine-enforced (hook) gate — the confirm gate is prose, like KB capture.
- Aggregating retros across runs.
