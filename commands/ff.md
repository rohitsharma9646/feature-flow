---
description: "Entry point: set up a durable feature-flow run, run the explore phase, then hand off phase-by-phase."
argument-hint: "\"<feature request>\""
---

# /ff — set up a run and start it (feature track)

`$ARGUMENTS` is the request. This command **initializes a durable run and runs only the
first phase (explore)**, then STOPS and hands you to the next phase. It does **not** chain
the whole workflow — each later phase is its own command you invoke, so every human gate is
honored and a dropped session is recoverable. (Track classification — feature vs bugfix —
is added in a later build step; for now this runs the feature track.)

> **Precedence — read before doing anything.** You are executing the feature-flow
> workflow. Its phases REPLACE any generic brainstorming / writing-plans / make-plan /
> docs-first planning in your environment: do **not** invoke those skills, and do **not**
> write to `~/.claude/plans/`, `docs/plans/`, or a separate brainstorm doc. Every artifact
> lives in the `.feature-flow/<slug>/` sandbox recorded by its `manifest.json`. Follow the
> steps below literally and in order, creating files with the Write tool. When you reach
> **STOP**, end your turn — do **not** run the next phase yourself.

## Step 1 — Set up the run (do this now)

1. **Read config:** a repo-root `.feature-flow.json` overrides
   `${CLAUDE_PLUGIN_ROOT}/config/defaults.json`. Resolve `paths.base` (default
   `.feature-flow`), agent counts, models, `reviewThreshold`, and toggles.
2. **Create the run:** derive a short kebab `slug` from `$ARGUMENTS`. **Use the Write tool
   now** to create `<base>/<slug>/manifest.json` per the contract
   (`${CLAUDE_PLUGIN_ROOT}/docs/manifest-schema.md`): `track: "feature"`, `tier: "full"`,
   `createdAt`, `currentPhase: "explore"`, empty `phases`,
   `signOff: { required: true, signed: false }`. Confirm the file exists before continuing —
   if you have not written a manifest to disk, you have not started a run.

## Step 2 — Run the explore phase (only this phase)

1. Set `phases.explore.status = "in_progress"` in the manifest.
2. Dispatch `explorerAgents` (default 3) **`ff-code-explorer`** agents in parallel, each
   with a distinct focus so coverage is genuinely different:
   - **similar features** — existing features closest to the request and how they're built.
   - **architecture** — the layers, entry points, and conventions the feature must fit.
   - **patterns/abstractions** — reusable patterns, utilities, and extension points.
3. Read the files the agents flag as essential. Synthesize: where the feature will live,
   what to reuse, constraints discovered, and open questions for clarify.
4. **Write the artifact:** use the Write tool to create `<run dir>/explore.md` with that
   summary. Set `phases.explore = { status: "complete", artifact: "explore.md" }`, bump
   `updatedAt`.

## Step 3 — STOP and hand off

Do **not** ask clarifying questions, write a spec, or plan now. Tell the user explicitly:

> Explore complete — findings in `<run dir>/explore.md`. The next phase (**clarify**) will
> ask you a few clarifying questions and produce a `spec.md` for your **sign-off**. Run
> `/feature-flow:ff-clarify` to continue.

Then **end your turn.** The user drives the next phase.
