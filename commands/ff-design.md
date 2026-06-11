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
2. **Cold-start + sign-off gate:** if no `spec.md` exists (per `artifacts.spec`), tell the
   user to run `/feature-flow:ff-clarify` first to produce a spec — do not invent requirements.
   **If `spec.md` exists but is not signed off** (`signOff.signed != true` / the spec's
   `User signed off:` line reads `no`), **STOP** and route to `/feature-flow:ff-clarify` for
   sign-off: on the feature track, design, plan, and implement all require a **signed** spec
   (the WHAT is locked before the HOW). Stop unless the user explicitly asks you to design
   against an inline description in `$ARGUMENTS`.
3. Read `spec.md`. Set `phases.design.status = "in_progress"`, bump `currentPhase`.

## Do the work

Dispatch `architectAgents` (default 3) **`ff-code-architect`** agents in parallel, each
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
then end your turn.
