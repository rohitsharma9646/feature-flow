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
> Write tool, run only this one phase, then STOP. In autopilot mode, ceremonial phase-end
> STOPs become continuations — see **Autopilot** in
> `${CLAUDE_PLUGIN_ROOT}/docs/manifest-schema.md`.

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
4. Read the spec at the path from `artifacts.spec` (the same path the step-2 gate resolved),
   **and the explore findings** (`explore.md` in the run dir — resolve via
   `phases.explore.artifact`, else `<run dir>/explore.md`; it is ephemeral, always in the
   sandbox). Set `phases.design.status = "in_progress"`, bump `currentPhase`.

## KB recall (when enabled)

Run this **after the sign-off gate, before the architect fan-out**. It is a **no-op unless the KB is
active** (`toggles.kb === true` AND `paths.kb` non-null, read from `.feature-flow.json` →
`${CLAUDE_PLUGIN_ROOT}/config/defaults.json`); when inactive, skip it and dispatch the architects
exactly as today (byte-identical behavior).

When active, follow the **Knowledge base** recall rule in
`${CLAUDE_PLUGIN_ROOT}/docs/manifest-schema.md` exactly:

1. `Glob <paths.kb>/*.md`. **Empty store** → print a one-line note ("KB empty — no recall") and
   proceed to the fan-out (no error).
2. Extract topic keywords from `$ARGUMENTS` **and the spec's `## Problem`** (read the spec via
   `manifest.artifacts.spec` — pointer form, never a bare filename), then **tag-match** them against
   each entry's `tags` frontmatter.
3. For each match, run the staleness check: **stale** if any `referencedFiles` path is missing/moved
   OR the entry is older than `kb.freshnessWindowDays` (default 90, from `captureDate`).
4. Surface up to `kb.maxRecallEntries` (default 5) matches (recency-ordered) to the architect agents
   as appended context — fresh entries plain, **stale** entries decorated `[STALE — <reason>]` and
   **never dropped**. **No match** → one-line note, proceed.

## Do the work

First run **KB recall** (see `## KB recall (when enabled)` above) — a no-op unless the KB is active.

> **Boundary with clarify.** `ff-clarify` already locked the *what* — the underlying need, the
> chosen problem-level approach, and the acceptance criteria. Your job is the *how*: the
> architecture that builds that chosen approach, plus technical risk / pre-mortem (the HOW lane).
> Do **not** re-open the solution choice; if the chosen approach itself looks wrong, STOP and send
> the user back to `/feature-flow:ff-clarify` rather than silently substituting a different *what*.

Read `models.architect` from config (`.feature-flow.json` →
`${CLAUDE_PLUGIN_ROOT}/config/defaults.json`) and pass it as the `model` for each dispatched
agent. **Pass each architect the explore findings (step 4) as context** — the explore phase
already mapped the codebase (where the feature lives, what to reuse, the conventions in play),
so the architects build on that instead of cold re-scanning the repo three times over. Dispatch
`architectAgents` (default 3) **`ff-code-architect`** agents in parallel, each committed to a
distinct focus so the options are genuinely different:
- **minimal** — smallest change that satisfies the spec.
- **clean** — best long-term structure, even if more work.
- **pragmatic** — the balance the codebase's conventions actually favor.

Present the trade-offs side by side with a clear **recommendation**. Ask the user to
choose (or confirm your recommendation). Do not pick silently. This choice is an
**in-session pause in both modes** — in autopilot, ask (AskUserQuestion), then continue
the phase and the chain in the same turn once the user answers.

## Write the artifact + update manifest

Resolve the design's path per the **Durable artifact resolution** rule in
`${CLAUDE_PLUGIN_ROOT}/docs/manifest-schema.md` (`paths.durable` → sandbox `<run
dir>/design.md`; **create the target directory if absent**). **Use the Write tool** to write
the design from `${CLAUDE_PLUGIN_ROOT}/templates/design.md`: chosen approach, rejected
alternatives + why, component map, data flow, risks. Record the resolved path in **both**
`artifacts.design` and `phases.design.artifact`: set `phases.design = { status: "complete",
artifact: "<resolved design path>" }`, bump `updatedAt`.

**STOP (step-by-step) / continue (autopilot).** If `manifest.autopilot` is `true`, emit
the progress strip and proceed directly into the plan phase per
`${CLAUDE_PLUGIN_ROOT}/commands/ff-plan.md` — see **Autopilot** in
`${CLAUDE_PLUGIN_ROOT}/docs/manifest-schema.md`. If `false` or absent: do not plan or
implement now. Tell the user to run `/feature-flow:ff-plan` next, ending the message with
the one-line progress strip — see **Progress strip** in
`${CLAUDE_PLUGIN_ROOT}/docs/manifest-schema.md` — then end your turn.
