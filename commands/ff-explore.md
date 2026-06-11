---
description: "[feature] Explore the codebase to inform a feature: fan out read-only explorers, summarize findings into the run."
argument-hint: "<feature request, or run after /ff sets up the manifest>"
---

# /ff-explore — feature exploration phase

You are running the **explore** phase of the feature track. This is the entry phase;
no upstream artifact is required (cold-start safe).

## Manifest contract (follow exactly)

1. **Resolve the run.** Read config: a repo-root `.feature-flow.json` (if present)
   overrides `${CLAUDE_PLUGIN_ROOT}/config/defaults.json`. Use `paths.base` (default
   `.feature-flow`) as the sandbox root.
2. **Read or create the manifest** at `<base>/<slug>/manifest.json` (schema:
   `${CLAUDE_PLUGIN_ROOT}/docs/manifest-schema.md`). If `$ARGUMENTS` starts a new run,
   derive a short kebab `slug` from it, create the run dir, and write a manifest with
   `track: "feature"`, `tier: "full"`, empty `phases`, `signOff.required: true`.
   If a manifest already exists (e.g. `/ff` created it), use it.
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

Write the findings summary to `<run dir>/explore.md`. Set
`phases.explore = { status: "complete", artifact: "explore.md" }`, bump `updatedAt`.
Tell the user the next phase is `/ff-clarify`.
