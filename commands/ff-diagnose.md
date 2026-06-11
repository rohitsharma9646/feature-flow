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
> Write tool, run only this one phase, then STOP.

## Manifest contract

1. Resolve config + manifest (read `.feature-flow.json` →
   `${CLAUDE_PLUGIN_ROOT}/config/defaults.json`; locate `<base>/<slug>/manifest.json`).
2. **Cold-start:** if no manifest exists, create one with `track: "bugfix"` (slug from the
   bug report). If a manifest exists with `track: "feature"`, this is the wrong track —
   tell the user and stop.
3. Set `phases.diagnose.status = "in_progress"`, bump `currentPhase = "diagnose"`.

## Do the work — reproduce + root-cause

Dispatch a **`ff-diagnostician`** agent (read-only) to: reproduce the bug, isolate the
fault to the smallest responsible code region, and identify the **root cause** (not the
symptom) with `file:line` evidence and the failing path traced from trigger to fault.

> **Not reproduced → STOP (edge case).** If the bug cannot be reproduced, record
> "not reproduced" in `diagnosis.md` along with what was tried and the specific detail
> still needed, **ask the user for that detail, and STOP — do not proceed to a fix.**
> Guessing a fix for an unconfirmed bug is forbidden. End your turn here.

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

Record `tier` in the manifest. When in doubt between lite and full, choose **full**.

## Write the artifact + update manifest

**Use the Write tool** to write `diagnosis.md` from
`${CLAUDE_PLUGIN_ROOT}/templates/diagnosis.md`: bug report, reproduction, root cause,
fix approach (hotfix-vs-proper + recommendation), fix surface, regression-test plan, the
`Tier:` line, and the Sign-off line (`no` for full / `n/a (lite)` for lite). Record the
path in `artifacts.diagnosis`.

Update the manifest: set `phases.diagnose = { status: "complete", artifact: "diagnosis.md" }`,
`track: "bugfix"`, `tier`, bump `updatedAt`.

## STOP — route by tier

- **lite:** tell the user to run `/feature-flow:ff-implement` next (the confirmed diagnosis
  is the gate; the fix is **test-first** — failing regression test → RED → fix → GREEN).
- **full:** tell the user to run `/feature-flow:ff-plan`, then sign off, then
  `/feature-flow:ff-implement`. Do **not** mark sign-off yourself.

End your turn here. Do not plan, implement, or fix now.
