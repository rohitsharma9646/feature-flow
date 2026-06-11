---
description: "Entry point: classify the request (feature vs bugfix), set up a durable run, start the first phase, then hand off phase-by-phase."
argument-hint: "\"<feature request or bug report>\""
---

# /feature-flow:ff — classify, set up a run, and start it

`$ARGUMENTS` is the request. This command **classifies the request, initializes a durable
run, and starts only the first phase**, then STOPS and hands you to the next phase. It does
**not** chain the whole workflow — each later phase is its own command you invoke, so every
human gate is honored and a dropped session is recoverable.

> **Precedence — read before doing anything.** You are executing the feature-flow
> workflow. Its phases REPLACE any generic brainstorming / writing-plans / make-plan /
> docs-first planning in your environment: do **not** invoke those skills, and do **not**
> write to `~/.claude/plans/`, `docs/plans/`, or a separate brainstorm doc. Every artifact
> lives in the `.feature-flow/<slug>/` sandbox recorded by its `manifest.json`. Follow the
> steps below literally and in order, creating files with the Write tool. When you reach
> **STOP**, end your turn — do **not** run the next phase yourself.

## Step 1 — Classify the track (feature vs bugfix)

Judge `$ARGUMENTS` (soft judgment — no rigid keyword rule):

- **bugfix** — restore *intended* behavior in existing code: something is broken, throws,
  regressed, or misbehaves ("fix:", "crashes", "wrong result", "broke after…").
- **feature** — add *new* behavior or capability that doesn't exist yet.

- **Ambiguous?** Ask the user **once** which it is, then proceed. Don't guess silently.
- **Genuinely both** (e.g. "fix the parser and add CSV export")? Do **not** run a hybrid —
  tell the user you'll **split** it: handle the **bug fix first** (its own run), then the
  feature as a separate run. Set up only the first (bugfix) run now.

## Step 2 — Set up the run (do this now)

1. **Read config:** a repo-root `.feature-flow.json` overrides
   `${CLAUDE_PLUGIN_ROOT}/config/defaults.json`. Resolve `paths.base` (default
   `.feature-flow`), agent counts, models, `reviewThreshold`, and toggles.
2. **Create the run:** derive a short kebab `slug` from `$ARGUMENTS`. **Use the Write tool
   now** to create `<base>/<slug>/manifest.json` per the contract
   (`${CLAUDE_PLUGIN_ROOT}/docs/manifest-schema.md`):
   - **feature:** `track: "feature"`, `tier: "full"`, `currentPhase: "explore"`,
     `signOff: { required: true, signed: false }`.
   - **bugfix:** `track: "bugfix"`, `currentPhase: "diagnose"`, `signOff: { required:
     false, signed: false }` (tier is decided during diagnose).
   - Both: `createdAt`, empty `phases`. Confirm the file exists before continuing — if you
     have not written a manifest to disk, you have not started a run.

## Step 3 — Start the first phase, by track

### Feature → run the explore phase now (only this phase)

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
   `updatedAt`. Then **STOP and hand off:**

   > Explore complete — findings in `<run dir>/explore.md`. The next phase (**clarify**)
   > will ask a few clarifying questions and produce a `spec.md` for your **sign-off**. Run
   > `/feature-flow:ff-clarify` to continue.

### Bugfix → hand off to the diagnose phase (do NOT run it here)

The bugfix track's first phase is **diagnose**, which is a *gated* analysis phase (it can
STOP to ask for repro detail, and may require sign-off). It lives in its own command — do
not run it inline here. The manifest is set up; **STOP and hand off:**

> This is a **bug fix** — run set up (`<run dir>/manifest.json`, `track: bugfix`). The next
> phase (**diagnose**) will reproduce the bug, find the root cause, and decide the fix
> approach (writing `diagnosis.md`). Run `/feature-flow:ff-diagnose` to continue.

Then **end your turn.** The user drives the next phase.
