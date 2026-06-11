---
description: "[feature] Fan out architects for design options, present trade-offs, record the chosen design in design.md."
argument-hint: "<run after /ff-clarify; or your choice among presented options>"
---

# /ff-design — feature design phase

You are running the **design** phase of the feature track. Output: `design.md` recording
the chosen approach and rejected alternatives.

## Manifest contract

1. Resolve config + manifest (as in `/ff-explore`).
2. **Cold-start:** if no `spec.md` exists (per `artifacts.spec`), tell the user to run
   `/ff-clarify` first to produce a spec — do not invent requirements. Stop unless they
   explicitly ask you to design against an inline description in `$ARGUMENTS`.
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

Write `design.md` from `${CLAUDE_PLUGIN_ROOT}/templates/design.md`: chosen approach,
rejected alternatives + why, component map, data flow, risks. Set
`phases.design = { status: "complete", artifact: "design.md" }`, bump `updatedAt`.
Next phase: `/ff-plan`.
