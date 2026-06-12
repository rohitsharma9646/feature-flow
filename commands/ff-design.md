---
description: "[feature] Fan out architects for design options, present trade-offs, record the chosen design in design.md."
argument-hint: "<run after /feature-flow:ff-clarify; or your choice among presented options>"
---

# /feature-flow:ff-design — feature design phase

You are running the **design** phase of the feature track. Output: `design.md` recording
the chosen approach and rejected alternatives.

> **Precedence — read first.** You are executing the feature-flow workflow. Its phases
> REPLACE any generic brainstorming / writing-plans / make-plan / docs-first planning: do
> **not** invoke those skills, and do **not** write to `~/.claude/plans/`, `docs/plans/`,
> or a separate brainstorm doc. All run state lives in the `.feature-flow/<slug>/` sandbox
> and its `manifest.json`. Follow this command's steps literally, create files with the
> Write tool, run only this one phase, then STOP.

## Manifest contract

1. **Resolve the run** per **Run resolution** in
   `${CLAUDE_PLUGIN_ROOT}/docs/manifest-schema.md` (named slug → else the single /
   most-recently-updated run → ask if ambiguous), then read its `manifest.json`.
2. **Cold-start + sign-off gate:** if no `spec.md` exists (per `artifacts.spec`), or it
   exists but is not signed off (`signOff.signed != true` / the spec's `User signed off:`
   line reads `no`), **STOP** and tell the user exactly:

   > Design requires a **signed** spec — the WHAT is locked before the HOW (design, plan,
   > and implement all gate on it). Run `/feature-flow:ff-clarify` to produce and/or sign off
   > the spec, then re-run `/feature-flow:ff-design`.

   Do not invent requirements. Stop unless the user explicitly asks you to design against
   an inline description in `$ARGUMENTS`.
3. **Re-run guard:** if `phases.design.status` is already `"complete"`, stop and ask for
   explicit confirmation before overwriting `design.md` — see **Re-run guard** in
   `${CLAUDE_PLUGIN_ROOT}/docs/manifest-schema.md`.
4. Read `spec.md`. Set `phases.design.status = "in_progress"`, bump `currentPhase`.

## Do the work

> **Boundary with clarify.** `ff-clarify` already locked the *what* — the underlying need, the
> chosen problem-level approach, and the acceptance criteria. Your job is the *how*: the
> architecture that builds that chosen approach, plus technical risk / pre-mortem (the HOW lane).
> Do **not** re-open the solution choice; if the chosen approach itself looks wrong, STOP and send
> the user back to `/feature-flow:ff-clarify` rather than silently substituting a different *what*.

Read `models.architect` from config (`.feature-flow.json` →
`${CLAUDE_PLUGIN_ROOT}/config/defaults.json`) and pass it as the `model` for each dispatched
agent. Dispatch `architectAgents` (default 3) **`ff-code-architect`** agents in parallel, each
committed to a distinct focus so the options are genuinely different:
- **minimal** — smallest change that satisfies the spec.
- **clean** — best long-term structure, even if more work.
- **pragmatic** — the balance the codebase's conventions actually favor.

Present the trade-offs side by side with a clear **recommendation**. Ask the user to
choose (or confirm your recommendation). Do not pick silently.

## Write the artifact + update manifest

**Use the Write tool** to write `design.md` from `${CLAUDE_PLUGIN_ROOT}/templates/design.md`:
chosen approach, rejected alternatives + why, component map, data flow, risks. Set
`phases.design = { status: "complete", artifact: "design.md" }`, bump `updatedAt`.

**STOP.** Do not plan or implement now. Tell the user to run `/feature-flow:ff-plan` next,
ending the message with the one-line progress strip — see **Progress strip** in
`${CLAUDE_PLUGIN_ROOT}/docs/manifest-schema.md` — then end your turn.
