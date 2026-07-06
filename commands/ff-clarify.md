---
description: "[feature] Ask organized clarifying questions, then write spec.md with acceptance criteria and a sign-off gate."
argument-hint: "<answers to clarifying questions, or run after /feature-flow:ff-explore>"
---

# /feature-flow:ff-clarify — feature clarify phase

You are running the **clarify** phase of the feature track. Output: a `spec.md` with
acceptance criteria and a sign-off block.

> **Precedence — read first.** You are executing the feature-flow workflow. Its phases
> REPLACE any generic brainstorming / writing-plans / make-plan / docs-first planning: do
> **not** invoke those skills, and do **not** write to `~/.claude/plans/`, `docs/plans/`,
> or a separate brainstorm doc. All run state lives in the `.feature-flow/<slug>/` sandbox
> and its `manifest.json`. Follow this command's steps literally, create files with the
> Write tool, run only this one phase, then STOP. In autopilot mode, ceremonial phase-end
> STOPs become continuations — see **Autopilot** in
> `${CLAUDE_PLUGIN_ROOT}/docs/manifest-schema.md`.

## Manifest contract

1. **Resolve the run** per **Run resolution** in
   `${CLAUDE_PLUGIN_ROOT}/docs/manifest-schema.md` (named slug → else the single /
   most-recently-updated run → ask if ambiguous), then read its `manifest.json`.
2. **Cold-start:** if no manifest exists, **resolve `autopilot` first** (run-start
   procedure — see **Autopilot** in `${CLAUDE_PLUGIN_ROOT}/docs/manifest-schema.md`;
   never choose the value yourself),
   then create one (`track: "feature"`, including the resolved `autopilot`); if no
   `explore.md` exists, tell the user `/feature-flow:ff-explore` usually runs first — offer to
   proceed using `$ARGUMENTS` as the request, or stop so they can explore.
3. Read `explore.md` (if present) for context.
4. **Re-run guard:** if `phases.clarify.status` is already `"complete"`, stop and ask for
   explicit confirmation first — re-running clarify overwrites `spec.md` AND resets
   `signOff.signed` to `false` — see **Re-run guard** in
   `${CLAUDE_PLUGIN_ROOT}/docs/manifest-schema.md`.
5. Set `phases.clarify.status = "in_progress"`, bump `currentPhase`.

## Do the work

**Your one job — the invariant: lock the WHAT** — the right problem, the chosen solution
approach, and testable acceptance criteria. Everything below serves that. Anything that is not
WHAT is routed elsewhere, **never added here**:

| Concern | Home |
|---|---|
| **WHAT** — problem, solution options, scope, acceptance criteria | **this phase** |
| **HOW** — architecture, technical risk, migration, pre-mortem | `/feature-flow:ff-design` |
| **HOW-WELL** — security, UX, accessibility, cost, performance | `/feature-flow:ff-review` |

Run an **adaptive interrogation over this 4-beat floor** — probe the murkiest / highest-value
beat next, dig on shallow answers, and skip what is already obvious from `explore.md` or the
request. Don't over-ask. The technique *how-to* for each beat lives in
`${CLAUDE_PLUGIN_ROOT}/docs/grilling-playbook.md` — read it and follow it.

**Lite tier (`tier == "lite"`) — minimal clarify.** Skip beats 1–2 entirely (no
premise-challenge, no 2–3 approach weighing — a lite feature has one obvious approach). Run
only enough of beat 3 to make every acceptance criterion **binary and testable** — often
**zero questions** when the request + `explore.md` already pin them; ask at most a couple
if an AC is genuinely ambiguous. Fill the spec's **Solution approaches considered** with a
single line — *"lite tier — single obvious approach; alternatives not weighed"* — never a
blank section. Then write `spec.md` and go straight to the sign-off gate.

**Escalation (lite → full).** If clarify reveals the work actually needs competing
approaches weighed or a real multi-component design, **escalate**: set `tier = "full"`,
reset `signOff.signed = false`, keep the spec draft so far, run the **full** interrogation
(beats 1–4) over it, and route to `/feature-flow:ff-design` after sign-off. Escalation is
one-way — full never becomes lite.

1. **Premise** — anchor to the real underlying need, not the feature as phrased (The Mom Test;
   one "why" probe on a shallow answer).
2. **Solution options** — for non-trivial work, surface 2–3 distinct *problem-level* approaches
   to the need, weigh them lightly, recommend, and have the user pick. These are different
   *whats*, **not** architectures (that is `ff-design`). One genuinely obvious approach → say so,
   don't invent alternatives.
3. **Scope + examples→ACs** — set scope / non-goals for the chosen approach; drive its behaviours
   into concrete input→output examples (Example Mapping) so edge cases fall out; each example
   becomes a binary acceptance criterion.
4. **Assumptions that change the WHAT** — surface only assumptions that would alter the spec.
   Deep risk / pre-mortem and quality dimensions are **not** clarify's job (see the router above).
   Write **each surviving assumption as a table row** in the spec's `## Assumptions (WHAT-changing)`
   section — all five fields (`Statement`, `Confidence` `low|med|high`, `Basis / evidence`,
   `If-wrong impact`, `Validation-required` `y|n`), never a free-text bullet — per **Assumption
   records** in `${CLAUDE_PLUGIN_ROOT}/docs/manifest-schema.md`. Set `Validation-required: y` on any
   assumption that is load-bearing and still unproven; if the user validates it during this
   interrogation, mark it `n`. Row order is stable once written (position = Assumption N).

The interrogation is an **in-session pause in both modes** — in autopilot, ask the
questions (AskUserQuestion), then continue writing the spec and proceed to the sign-off
gate in the same turn once the user answers.

Then write `spec.md` from `${CLAUDE_PLUGIN_ROOT}/templates/spec.md`, filling Problem, Expected
outcome, **Solution approaches considered** (chosen + rejected, each justified), Scope,
**Constraints** (hard limits: compatibility, performance, security, deadlines — from the
user's answers or `explore.md`), Edge cases, Non-goals, the WHAT-changing **Assumptions**,
and binary **Acceptance criteria**. Resolve
the spec's path per the **Durable artifact resolution** rule in
`${CLAUDE_PLUGIN_ROOT}/docs/manifest-schema.md` (legacy `paths.spec` → `paths.durable` →
sandbox `<run dir>/spec.md`; **create the target directory if absent**). Record the resolved
path in **both** `artifacts.spec` and `phases.clarify.artifact`.

**Red-team your own draft before sign-off** (one discipline, not a checklist): re-read the spec
against the invariant — is the problem the real need? is the chosen approach the best of the
options? is every AC binary and checkable? any WHAT-changing assumption left implicit? — then
revise, or ask the user the questions that survive. The how-to is in the playbook. Then proceed
to the sign-off gate below.

## Sign-off gate (required)

The spec must end with `User signed off: no`. Write `spec.md` with the Write tool, then
**STOP: end your turn by explicitly asking the user to sign off.** The sign-off ask
presents the spec's `## Acceptance criteria` **verbatim, as a grouped checklist — never a
blockquote wall** — see **Sign-off rendering** in
`${CLAUDE_PLUGIN_ROOT}/docs/manifest-schema.md`. This gate is
a hard turn-end **in both modes**: autopilot never bypasses it and never sets
`signOff.signed` itself.

**Unvalidated-assumptions echo (the actuation).** Before presenting the ask, read the spec's
`## Assumptions (WHAT-changing)` table (resolved via `manifest.artifacts.spec`) and collect every
row whose `Validation-required` is `y` **and** is still unvalidated. Render them per **Sign-off
rendering rule 3** — a **distinct `### Unvalidated assumptions` block after** the AC checklist, never
folded into the `- [ ] AC<n>` boxes — and the block **blocks a clean sign-off**: do **not** set
`signOff.signed = true` while any such assumption remains **unresolved** — each must be validated
(mark it `n`), waived (also mark it `n` — the waiver line is the audit trail), or (**full tier only**) explicitly **acknowledged by the user as staying open**
(the row stays `y` and is carried to the full-tier plan as a `**Validates:**` task per §Assumption
records → Actuation 2). On a **lite** feature (no plan phase) exit (c) is unavailable — resolve via
validate or waive only.
When there are
none (or none are `y`), the block states `_None unvalidated._` — a **clean** sign-off ask, never a
false-fired block. The trigger/scope/waiver live in **Assumption records**
(`${CLAUDE_PLUGIN_ROOT}/docs/manifest-schema.md`); this echo is its Evidence-gap-stop-shaped sign-off
half — **not** a do-not-contradict STOP. The waiver is the verbatim, **user-authored** line
`Assumption validation waived by user (<date>): <reason>` recorded in the spec — **never
assistant-authored, never dated by the assistant, and autopilot never records it** (mirrors the
Evidence waiver); a waiver does not change the assumption's recorded `Confidence`.

Do not design, plan, or implement, and do not mark sign-off
yourself. When the user confirms (this or a later turn) — every unvalidated `validation-required: y`
assumption having been validated, waived, or acknowledged-open — set `signOff.signed = true` and
`signOff.date`, and update the spec's Sign-off line to `yes (<date>)` — then **re-read
`manifest.autopilot` from the manifest on disk** (the confirmation arrives in a fresh turn;
never assume the mode from memory) and continue per the Update-manifest section below.

## Update manifest (after sign-off)

Once sign-off is recorded, set
`phases.clarify = { status: "complete", artifact: "<resolved spec path>" }`,
`signOff.required = true`, bump `updatedAt`. Then **STOP (step-by-step) / continue
(autopilot)**, routing by tier:
- **Lite tier (`tier == "lite"`):** set `manifest.artifacts.decision` to the **same resolved
  path** as `artifacts.spec` — lite skips `ff-design`, so the spec's inline `## Solution
  approaches considered` section *is* the decision record, and pointing `artifacts.decision`
  there lets `ff-implement`'s **Decision recall** resolve uniformly through one pointer with no
  tier fork. Then route to `/feature-flow:ff-implement` — lite skips the design + plan phases.
  Autopilot → emit the progress strip and proceed directly into implement per
  `${CLAUDE_PLUGIN_ROOT}/commands/ff-implement.md`; step-by-step → **STOP** and tell the user to
  run `/feature-flow:ff-implement` next.
- **Full tier:** route to `/feature-flow:ff-design`. Autopilot → emit the progress strip and
  proceed directly into the design phase per `${CLAUDE_PLUGIN_ROOT}/commands/ff-design.md` —
  see **Autopilot** in `${CLAUDE_PLUGIN_ROOT}/docs/manifest-schema.md`; step-by-step →
  **STOP** and tell the user to run `/feature-flow:ff-design` next.

End the message with the one-line progress strip — the **lite** strip omits design + plan
(`explore[done] → clarify[done] → implement[NEXT] → review → verify`) — see **Progress
strip** in `${CLAUDE_PLUGIN_ROOT}/docs/manifest-schema.md`.
