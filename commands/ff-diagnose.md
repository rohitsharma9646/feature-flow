---
description: "[bugfix] Reproduce + root-cause a bug (fan-out: ff-diagnostician), decide hotfix-vs-proper, write diagnosis.md."
argument-hint: "<the bug report, or run after /feature-flow:ff on a bug>"
---

# /feature-flow:ff-diagnose — bugfix diagnose phase

You are running the **diagnose** phase of the bugfix track. Output: a `diagnosis.md` with
reproduction, root cause, a hotfix-vs-proper fix decision, and a tier/sign-off gate. This
is the bugfix track's replacement for the feature track's clarify+design phases — there is
**no** 3-architecture design phase and **no** `design.md` for bugs.

> **Precedence — read first.** You are executing the feature-flow workflow. Its phases
> REPLACE any generic brainstorming / writing-plans / make-plan / docs-first planning: do
> **not** invoke those skills, and do **not** write to `~/.claude/plans/`, `docs/plans/`,
> or a separate brainstorm doc. All run state lives in the `.feature-flow/<slug>/` sandbox
> and its `manifest.json`. Follow this command's steps literally, create files with the
> Write tool, run only this one phase, then STOP. In autopilot mode, ceremonial phase-end
> STOPs become continuations — see **Autopilot** in
> `${CLAUDE_PLUGIN_ROOT}/docs/schema/autopilot.md`.

## Manifest contract

1. **Resolve the run** per **Run resolution** in
   `${CLAUDE_PLUGIN_ROOT}/docs/manifest-schema.md` (named slug → else the single /
   most-recently-updated run → ask if ambiguous; cold-start derives a new slug from the bug
   report), then read its `manifest.json`.
2. **Cold-start:** if no manifest exists, **resolve `autopilot` first** (run-start
   procedure — see **Autopilot** in `${CLAUDE_PLUGIN_ROOT}/docs/schema/autopilot.md`;
   never choose the value yourself),
   then create one with `track: "bugfix"` (slug from the bug report) including the
   resolved `autopilot` and `revisionBound: true`. If a manifest exists with
   `track: "feature"`, this is the wrong track — tell the user and stop.
3. **Re-run guard:** if `phases.diagnose.status` is already `"complete"`, stop and ask for
   explicit confirmation before overwriting `diagnosis.md` (a full-tier re-run also resets
   `signOff.signed`) — see **Re-run guard** in `${CLAUDE_PLUGIN_ROOT}/docs/manifest-schema.md`.
4. Set `phases.diagnose.status = "in_progress"`, bump `currentPhase = "diagnose"`.

## KB recall (when enabled)

Run this **before the diagnostician dispatch** in `## Do the work — reproduce + root-cause`. It
is a **no-op unless the KB is active** (`toggles.kb === true` AND `paths.kb` non-null, read from
`.feature-flow.json` → `${CLAUDE_PLUGIN_ROOT}/config/defaults.json`); when inactive, skip it and
dispatch the diagnosticians with no KB context.

When active, follow the **Knowledge base** recall rule in
`${CLAUDE_PLUGIN_ROOT}/docs/schema/knowledge-base.md` exactly — that is the canonical procedure
(glob the store, tag-match, staleness check, recency-ordered surfacing); **do not restate its
steps here.** The only command-specific input: extract the tag-match keywords from **`$ARGUMENTS`
(the bug report)**, and surface matches to the **diagnostician agents** as context — **stale**
entries flagged `[STALE — <reason>]`, never dropped. Empty store / no match → one-line note, proceed.

## Do the work — reproduce + root-cause

First run **KB recall** (see `## KB recall (when enabled)` above) — a no-op unless the KB is
active. Then read `diagnosticianAgents` (default 1) and `models.diagnostician` from config
(`.feature-flow.json` → `${CLAUDE_PLUGIN_ROOT}/config/defaults.json`); dispatch that many
**`ff-diagnostician`** agents (read-only), passing the model, to: reproduce the bug, isolate
the fault to the smallest responsible code region, and identify the **root cause** (not the
symptom) with `file:line` evidence and the failing path traced from trigger to fault.

The diagnostician is **read-only and cannot execute the program** — its "reproduced" verdict
is a **static hypothesis** (trigger + failing path established from source), not an executed
run. Diagnose's job is to confirm the bug is *understood* and locate it; the **binding
executed evidence** is the RED regression test captured in `/feature-flow:ff-implement`
(`bugfix.red`). Treat a confirmed diagnosis as "we know what's wrong and where," never as
"we ran it and watched it fail" — that proof comes at implement.

When you search the repo yourself during reproduction, use the **Grep**/**Glob** tools —
never Bash `grep -r`/`find` over the root (they ignore `.gitignore` and walk ignored
dependency/build trees; see **Searching the repo** in
`${CLAUDE_PLUGIN_ROOT}/skills/feature-flow/SKILL.md`).

On the **full** tier, enumerate **≥2 root-cause candidates** with evidence for/against in
`diagnosis.md` §Root cause candidates, then record the **Confirmed root cause** (which
candidate the evidence decides, with `file:line`). On the **lite** tier a single Confirmed
root cause is enough — skip candidate enumeration (no ceremony on a one-spot bug).

> **Not reproduced → STOP (edge case).** If the bug cannot be reproduced, record
> "not reproduced" in the diagnosis along with what was tried, and tell the user exactly:
>
> > Diagnosis cannot proceed: the bug was not reproduced. Provide <the specific missing
> > detail>, then re-run `/feature-flow:ff-diagnose`. Guessing a fix for an unconfirmed bug
> > is forbidden.
>
> Then STOP — do not proceed to a fix. End your turn here. This stop **ends the chain
> unconditionally in both modes** — autopilot does not retry an unreproduced bug.

## Decide the fix approach (hotfix-vs-proper — required)

From the root cause, name **both** a hotfix/band-aid option and a root-cause/proper option,
each with cost/risk, then give a **recommendation** (default to the proper fix unless a
stated reason makes the hotfix right). This solution-horizon decision is required even when
the answer is "proper fix only". If a hotfix is recommended, record what the proper fix
*would* be as a follow-up so it doesn't calcify.

**Assumptions (full tier only).** On the **full** tier, record every WHAT-changing assumption behind
the chosen fix approach as a **row** in the diagnosis `## Assumptions` table — all five fields
(`Statement`, `Confidence` `low|med|high`, `Basis / evidence`, `If-wrong impact`, `Validation-required`
`y|n`) — per **Assumption records** in `${CLAUDE_PLUGIN_ROOT}/docs/schema/assumption-records.md`; set
`Validation-required: y` on any load-bearing, still-unproven assumption. On the **lite** tier, **skip
this entirely** — a lite bug has no sign-off gate to echo into, so it carries no assumptions table.

## Set the tier

- **lite** — trivial/obvious bug (clear one-spot fix, low blast radius): a *confirmed*
  diagnosis is itself the gate; no separate sign-off. The Sign-off line reads `n/a (lite)`.
- **full** — non-trivial bug (ambiguous root cause, broad surface, risky change): escalates
  to a plan + sign-off, exactly like the feature track. The Sign-off line reads `no`
  until the user signs off.

Record `tier` in the manifest. **Full** → set `signOff.required = true` (the diagnosis is the
bug's signed contract and must be signed before a fix). **Lite** → `signOff.required = false`.
When in doubt between lite and full, choose **full**.

## Write the artifact + update manifest

Resolve the diagnosis's path per the **Durable artifact resolution** rule in
`${CLAUDE_PLUGIN_ROOT}/docs/manifest-schema.md` (`paths.durable` → sandbox `<run
dir>/diagnosis.md`; **create the target directory if absent**). **Use the Write tool** to
write the diagnosis from `${CLAUDE_PLUGIN_ROOT}/templates/diagnosis.md`: bug report,
reproduction, root cause candidates (full tier) + confirmed root cause, fix approach
(hotfix-vs-proper + recommendation), fix surface,
regression-test plan, the `Tier:` line, and the Sign-off line (`no` for full / `n/a (lite)`
for lite). Record the resolved path in **both** `artifacts.diagnosis` and
`phases.diagnose.artifact`.

Update the manifest: set `track: "bugfix"`, `tier`, `artifacts.diagnosis`, bump `updatedAt`.
- **lite:** set `phases.diagnose = { status: "complete", artifact: "<resolved diagnosis path>" }` now.
- **full:** leave `phases.diagnose.status = "in_progress"` until sign-off (next section).

## Sign-off gate — full tier only (mirrors `/feature-flow:ff-clarify`)

A **full**-tier diagnosis is the bug's signed contract, exactly like a feature spec.
After writing `diagnosis.md`, **STOP: end your turn by explicitly asking the user to sign off
on the fix approach.** The sign-off ask presents the diagnosis's chosen fix approach and
contract items (root cause, fix surface, regression-test plan) **verbatim, as a grouped
checklist — never a blockquote wall** — see **Sign-off rendering** in
`${CLAUDE_PLUGIN_ROOT}/docs/schema/sign-off-rendering.md`. This gate is a hard turn-end **in both
modes**: autopilot never bypasses it and never sets `signOff.signed` itself.

**Unvalidated-assumptions echo (the actuation).** Before presenting the ask, read the diagnosis's
`## Assumptions` table (resolved via `manifest.artifacts.diagnosis`) and collect every row whose
`Validation-required` is `y` and is still unvalidated. Render them per **Sign-off rendering rule 3** —
a **distinct `### Unvalidated assumptions` block after** the contract checklist, never folded into the
checkboxes — and the block **blocks a clean sign-off**: do **not** set `signOff.signed = true` while
any such assumption remains **unresolved** — each must be validated (mark it `n`), waived (also mark
it `n`), or explicitly **acknowledged by the user as staying open** (row stays `y`, carried to the plan as a
`**Validates:**` task per §Assumption records → Actuation 2); when there are none it states
`_None unvalidated._` (clean ask, never false-fired). The waiver is the verbatim, **user-authored**
line `Assumption validation waived by user (<date>): <reason>` recorded in the diagnosis — **never
assistant-authored, never dated by the assistant, and autopilot never records it** (mirrors the
Evidence waiver); it does not change the recorded `Confidence`. See **Assumption records** in
`${CLAUDE_PLUGIN_ROOT}/docs/schema/assumption-records.md`.

Do **not**
plan, implement, or mark sign-off yourself. When the user
confirms (this or a later turn) — every unvalidated `validation-required: y` assumption having been
validated, waived, or acknowledged-open — set `signOff.signed = true` and `signOff.date`, update the
diagnosis `User signed off:` line to `yes (<date>)`, and set
`phases.diagnose = { status: "complete", artifact: "<resolved diagnosis path>" }` — then **re-read
`manifest.autopilot` from the manifest on disk** (the confirmation arrives in a fresh turn;
never assume the mode from memory) and route per the STOP section below. A **lite** diagnosis
needs no sign-off — its confirmed diagnosis is itself the gate.

## STOP — route by tier

- **lite:** if `manifest.autopilot` is `true`, emit the progress strip and proceed directly
  into the implement phase per `${CLAUDE_PLUGIN_ROOT}/commands/ff-implement.md` — see
  **Autopilot** in `${CLAUDE_PLUGIN_ROOT}/docs/schema/autopilot.md`. If `false` or absent,
  tell the user to run `/feature-flow:ff-implement` next.
- **full:** **only once the diagnosis is signed off** (above): if the re-read
  `manifest.autopilot` is `true`, emit the progress strip and proceed directly into the
  plan phase per `${CLAUDE_PLUGIN_ROOT}/commands/ff-plan.md`; if `false` or absent, tell
  the user to run `/feature-flow:ff-plan` next, then `/feature-flow:ff-implement`. If it
  is not yet signed, STOP at the sign-off ask — do **not** route forward (in either mode).

End the message with the one-line progress strip in the run's actual phase order — **full**
tier includes plan: `diagnose[done] → plan[NEXT] → implement → verify → review`; **lite**
skips it: `diagnose[done] → implement[NEXT] → verify → review` — see **Progress strip** in
`${CLAUDE_PLUGIN_ROOT}/docs/manifest-schema.md`.

In step-by-step mode, end your turn here — do not plan, implement, or fix now. The routing
instructions above govern autopilot continuation.
