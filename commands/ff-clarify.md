---
description: "[feature] Ask organized clarifying questions, then write spec.md with acceptance criteria and a sign-off gate."
argument-hint: "<answers to clarifying questions, or run after /ff-explore>"
---

# /ff-clarify — feature clarify phase

You are running the **clarify** phase of the feature track. Output: a `spec.md` with
acceptance criteria and a sign-off block.

## Manifest contract

1. Resolve config + manifest as in `/ff-explore` (read `.feature-flow.json` →
   `${CLAUDE_PLUGIN_ROOT}/config/defaults.json`; locate `<base>/<slug>/manifest.json`).
2. **Cold-start:** if no manifest exists, create one (`track: "feature"`); if no
   `explore.md` exists, tell the user `/ff-explore` usually runs first — offer to
   proceed using `$ARGUMENTS` as the request, or stop so they can explore.
3. Read `explore.md` (if present) for context.
4. Set `phases.clarify.status = "in_progress"`, bump `currentPhase`.

## Do the work

Ask the user a small, **organized** set of clarifying questions (group them: scope,
behavior, edge cases, non-goals, constraints). Wait for answers. Don't over-ask — only
what genuinely shapes the spec.

When you have answers, write `spec.md` from `${CLAUDE_PLUGIN_ROOT}/templates/spec.md`,
filling Problem, Expected outcome, Assumptions, Constraints, Edge cases, Non-goals, and
binary **Acceptance criteria**. Resolve the spec path: if `paths.spec` is set in config,
write there; otherwise `<run dir>/spec.md`. Record the resolved path in the manifest's
`artifacts.spec`.

## Sign-off gate (required)

The spec must end with `User signed off: no`. **End your turn by explicitly asking the
user to sign off.** When they confirm, set `signOff.signed = true` and `signOff.date`,
and update the spec's Sign-off line to `yes (<date>)`. Do not mark sign-off yourself.

## Update manifest

Set `phases.clarify = { status: "complete", artifact: "<resolved spec path>" }`,
`signOff.required = true`, bump `updatedAt`. Next phase: `/ff-design`.
