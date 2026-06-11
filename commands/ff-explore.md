---
description: "[feature] Explore the codebase to inform a feature: fan out read-only explorers, summarize findings into the run."
argument-hint: "<feature request, or run after /feature-flow:ff sets up the manifest>"
---

# /feature-flow:ff-explore — feature exploration phase

You are running the **explore** phase of the feature track. This is the entry phase;
no upstream artifact is required (cold-start safe).

> **Precedence — read first.** You are executing the feature-flow workflow. Its phases
> REPLACE any generic brainstorming / writing-plans / make-plan / docs-first planning: do
> **not** invoke those skills, and do **not** write to `~/.claude/plans/`, `docs/plans/`,
> or a separate brainstorm doc. All run state lives in the `.feature-flow/<slug>/` sandbox
> and its `manifest.json`. Follow this command's steps literally, create files with the
> Write tool, run only this one phase, then STOP.

## Manifest contract (follow exactly)

1. **Resolve the run** per **Run resolution** in
   `${CLAUDE_PLUGIN_ROOT}/docs/manifest-schema.md` (named slug → else the single /
   most-recently-updated run → ask if ambiguous; cold-start derives a new slug from
   `$ARGUMENTS`).
2. **Read or create the manifest** at `<base>/<slug>/manifest.json` (schema:
   `${CLAUDE_PLUGIN_ROOT}/docs/manifest-schema.md`). If `$ARGUMENTS` starts a new run,
   derive a short kebab `slug` from it, create the run dir, and write a manifest with
   `track: "feature"`, `tier: "full"`, empty `phases`, `signOff.required: true`.
   If a manifest already exists (e.g. `/feature-flow:ff` created it), use it.
3. Set `phases.explore.status = "in_progress"`, bump `currentPhase = "explore"`.

## Do the work

Dispatch `explorerAgents` (default 3) **`ff-code-explorer`** agents in parallel, each
with a differentiated focus so the coverage is genuinely distinct:
- **similar features** — find existing features closest to the request and how they're built.
- **architecture** — map the layers, entry points, and conventions the feature must fit.
- **patterns/abstractions** — the reusable patterns, utilities, and extension points available.

Read the files the agents flag as essential. Synthesize a findings summary: where the
feature will live, what to reuse, constraints discovered, and open questions for clarify.

## Write the artifact + update manifest

**Use the Write tool** to write the findings summary to `<run dir>/explore.md`. Set
`phases.explore = { status: "complete", artifact: "explore.md" }`, bump `updatedAt`.

**STOP.** Explore is the only phase you run here. Tell the user: *"Explore complete —
findings in `explore.md`. Run `/feature-flow:ff-clarify` next."* Then end your turn — do
not begin clarify yourself.
