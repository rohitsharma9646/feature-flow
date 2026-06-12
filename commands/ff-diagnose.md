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
> `${CLAUDE_PLUGIN_ROOT}/docs/manifest-schema.md`.

## Manifest contract

1. **Resolve the run** per **Run resolution** in
   `${CLAUDE_PLUGIN_ROOT}/docs/manifest-schema.md` (named slug → else the single /
   most-recently-updated run → ask if ambiguous; cold-start derives a new slug from the bug
   report), then read its `manifest.json`.
2. **Cold-start:** if no manifest exists, create one with `track: "bugfix"` (slug from the
   bug report), then apply the run-start procedure to record `autopilot` — see **Autopilot**
   in `${CLAUDE_PLUGIN_ROOT}/docs/manifest-schema.md`. If a manifest exists with
   `track: "feature"`, this is the wrong track — tell the user and stop.
3. **Re-run guard:** if `phases.diagnose.status` is already `"complete"`, stop and ask for
   explicit confirmation before overwriting `diagnosis.md` (a full-tier re-run also resets
   `signOff.signed`) — see **Re-run guard** in `${CLAUDE_PLUGIN_ROOT}/docs/manifest-schema.md`.
4. Set `phases.diagnose.status = "in_progress"`, bump `currentPhase = "diagnose"`.

## Do the work — reproduce + root-cause

Read `diagnosticianAgents` (default 1) and `models.diagnostician` from config
(`.feature-flow.json` → `${CLAUDE_PLUGIN_ROOT}/config/defaults.json`); dispatch that many
**`ff-diagnostician`** agents (read-only), passing the model, to: reproduce the bug, isolate
the fault to the smallest responsible code region, and identify the **root cause** (not the
symptom) with `file:line` evidence and the failing path traced from trigger to fault.

> **Not reproduced → STOP (edge case).** If the bug cannot be reproduced, record
> "not reproduced" in `diagnosis.md` along with what was tried, and tell the user exactly:
>
> > Diagnosis cannot proceed: the bug was not reproduced. Provide <the specific missing
> > detail>, then re-run `/feature-flow:ff-diagnose`. Guessing a fix for an unconfirmed bug
> > is forbidden.
>
> Then STOP — do not proceed to a fix. End your turn here. This stop **ends the chain
> unconditionally in both modes** — autopilot does not retry an unreproduced bug.

## Decide the fix approach (hotfix-vs-proper — required, AC12)

From the root cause, name **both** a hotfix/band-aid option and a root-cause/proper option,
each with cost/risk, then give a **recommendation** (default to the proper fix unless a
stated reason makes the hotfix right). This solution-horizon decision is required even when
the answer is "proper fix only". If a hotfix is recommended, record what the proper fix
*would* be as a follow-up so it doesn't calcify.

## Set the tier

- **lite** — trivial/obvious bug (clear one-spot fix, low blast radius): a *confirmed*
  diagnosis is itself the gate; no separate sign-off. The Sign-off line reads `n/a (lite)`.
- **full** — non-trivial bug (ambiguous root cause, broad surface, risky change): escalates
  to a `plan.md` + sign-off, exactly like the feature track. The Sign-off line reads `no`
  until the user signs off.

Record `tier` in the manifest. **Full** → set `signOff.required = true` (the diagnosis is the
bug's signed contract and must be signed before a fix). **Lite** → `signOff.required = false`.
When in doubt between lite and full, choose **full**.

## Write the artifact + update manifest

**Use the Write tool** to write `diagnosis.md` from
`${CLAUDE_PLUGIN_ROOT}/templates/diagnosis.md`: bug report, reproduction, root cause,
fix approach (hotfix-vs-proper + recommendation), fix surface, regression-test plan, the
`Tier:` line, and the Sign-off line (`no` for full / `n/a (lite)` for lite). Record the
path in `artifacts.diagnosis`.

Update the manifest: set `track: "bugfix"`, `tier`, `artifacts.diagnosis`, bump `updatedAt`.
- **lite:** set `phases.diagnose = { status: "complete", artifact: "diagnosis.md" }` now.
- **full:** leave `phases.diagnose.status = "in_progress"` until sign-off (next section).

## Sign-off gate — full tier only (mirrors `/feature-flow:ff-clarify`)

A **full**-tier diagnosis is the bug's signed contract, exactly like a feature `spec.md`.
After writing `diagnosis.md`, **STOP: end your turn by explicitly asking the user to sign off
on the fix approach.** The sign-off ask presents the diagnosis's chosen fix approach and
contract items (root cause, fix surface, regression-test plan) **verbatim, as a grouped
checklist — never a blockquote wall** — see **Sign-off rendering** in
`${CLAUDE_PLUGIN_ROOT}/docs/manifest-schema.md`. This gate is a hard turn-end **in both
modes**: autopilot never bypasses it and never sets `signOff.signed` itself. Do **not**
plan, implement, or mark sign-off yourself. When the user
confirms (this or a later turn), set `signOff.signed = true` and `signOff.date`, update the
diagnosis `User signed off:` line to `yes (<date>)`, and set
`phases.diagnose = { status: "complete", artifact: "diagnosis.md" }` — then **re-read
`manifest.autopilot` from the manifest on disk** (the confirmation arrives in a fresh turn;
never assume the mode from memory) and route per the STOP section below. A **lite** diagnosis
needs no sign-off — its confirmed diagnosis is itself the gate.

## STOP — route by tier

- **lite:** if `manifest.autopilot` is `true`, emit the progress strip and proceed directly
  into the implement phase per `${CLAUDE_PLUGIN_ROOT}/commands/ff-implement.md` — see
  **Autopilot** in `${CLAUDE_PLUGIN_ROOT}/docs/manifest-schema.md`. If `false` or absent,
  tell the user to run `/feature-flow:ff-implement` next (the confirmed diagnosis
  is the gate; the fix is **test-first** — failing regression test → RED → fix → GREEN).
- **full:** **only once the diagnosis is signed off** (above): if the re-read
  `manifest.autopilot` is `true`, emit the progress strip and proceed directly into the
  plan phase per `${CLAUDE_PLUGIN_ROOT}/commands/ff-plan.md`; if `false` or absent, tell
  the user to run `/feature-flow:ff-plan` next, then `/feature-flow:ff-implement`. If it
  is not yet signed, STOP at the sign-off ask — do **not** route forward (in either mode).

End the message with the one-line progress strip in the run's actual phase order — **full**
tier includes plan: `diagnose[done] → plan[NEXT] → implement → verify → review`; **lite**
skips it: `diagnose[done] → implement[NEXT] → verify → review` — see **Progress strip** in
`${CLAUDE_PLUGIN_ROOT}/docs/manifest-schema.md`.

End your turn here. Do not plan, implement, or fix now.
