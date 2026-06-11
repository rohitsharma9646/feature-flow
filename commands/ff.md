---
description: "Smart entry point: set up a feature-flow run and chain the phases, pausing at human gates."
argument-hint: "\"<feature request>\""
---

# /ff — orchestrator (feature track)

`$ARGUMENTS` is the request. This command sets up a durable run and chains the **feature**
track end to end, honoring every gate. (Track classification — feature vs bugfix — is
added in a later build step; for now this runs the feature track.)

## Setup

1. **Read config:** a repo-root `.feature-flow.json` overrides
   `${CLAUDE_PLUGIN_ROOT}/config/defaults.json`. Resolve `paths.base` (default
   `.feature-flow`), agent counts, models, `reviewThreshold`, and toggles.
2. **Create the run:** derive a short kebab `slug` from `$ARGUMENTS`. Create
   `<base>/<slug>/` and write `manifest.json` per the contract
   (`${CLAUDE_PLUGIN_ROOT}/docs/manifest-schema.md`): `track: "feature"`, `tier: "full"`,
   `createdAt`, empty `phases`, `signOff: { required: true, signed: false }`.

## Chain the phases

Run each phase command's logic in order, against this manifest, pausing for the user at
the human gates:

1. **explore** (`/ff-explore` logic) — fan out explorers, summarize.
2. **clarify** (`/ff-clarify` logic) — ask clarifying questions, write `spec.md`. **GATE:
   pause for sign-off.** Do not continue to design until the user signs off (or explicitly
   waives).
3. **design** (`/ff-design` logic) — fan out architects, present options. **GATE: pause
   for the user's choice.**
4. **plan** (`/ff-plan` logic) — write `plan.md` with the Outcome gate.
5. **implement** (`/ff-implement` logic) — **refuses** to write code unless sign-off is
   recorded.
6. **review** (`/ff-review` logic) — fan out reviewers, write `review.md`.
7. **verify** (`/ff-verify` logic) — `ff-test-runner` executes; map the contract to
   pass/fail with evidence in `verify.md`.

After each phase, update the manifest (phase status, artifact, `currentPhase`,
`updatedAt`). If the user steps away, `/ff-resume` re-enters at the first incomplete phase
and `/ff-status` prints where things stand.
