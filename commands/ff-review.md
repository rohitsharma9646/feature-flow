---
description: "[shared] Fan out read-only reviewers at the configured threshold and consolidate into review.md."
argument-hint: "<run after /feature-flow:ff-implement>"
---

# /feature-flow:ff-review — review phase

Static review of the implemented change. Output: `review.md`.

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
   most-recently-updated run → ask if ambiguous), then read its `manifest.json`. Read
   `reviewThreshold` (default 80) and `reviewerAgents` (default 3).
2. **Re-run guard:** if `phases.review.status` is already `"complete"`, stop and ask for
   explicit confirmation before overwriting `review.md` — see **Re-run guard** in
   `${CLAUDE_PLUGIN_ROOT}/docs/manifest-schema.md`.
3. Set `phases.review.status = "in_progress"`, bump `currentPhase`.

## Cold-start

If nothing has been implemented yet, review whatever is in the working tree and note
explicitly that this is a pre-implementation / partial review.

## Do the work

Read `models.reviewer` from config (`.feature-flow.json` →
`${CLAUDE_PLUGIN_ROOT}/config/defaults.json`) and pass it as the `model` for each dispatched
agent. Dispatch `reviewerAgents` **`ff-code-reviewer`** agents in parallel with differentiated
focuses:
- **simplicity** — unneeded complexity, duplication, simpler equivalents.
- **bugs** — logic errors, null/edge handling, races, security.
- **conventions** — CLAUDE.md / project-guideline adherence.

Pass each the `reviewThreshold` from config; they report only issues scoring ≥ threshold.
On a greenfield / non-git project, point them at the working-tree files instead of a diff.

Consolidate findings (de-duplicate across agents) into `review.md` from
`${CLAUDE_PLUGIN_ROOT}/templates/review.md`: Critical vs Important, each with file:line,
issue, and a concrete fix. If nothing meets the threshold, record the "no high-confidence
issues" summary — do not invent findings to look thorough.

## Update manifest + hand off (order differs by track)

**Blocking findings block — both tracks.** If `review.md` contains ≥1 **Critical** finding,
do NOT mark the phase complete: leave `phases.review.status = "in_progress"` and
`currentPhase = "review"`, bump `updatedAt`.

- **Autopilot fix-and-re-review cycle (`manifest.autopilot: true` only).** First check
  `review.md` for an existing `## Resolution` section recording a prior autopilot fix cycle
  — the review artifact is the durable cycle record. **No prior cycle:** apply fixes for the
  Critical findings, append a `## Resolution` section to `review.md` (pre-fix findings,
  fixes applied, outcome), and re-run the reviewer dispatch **exactly once**; if the
  re-review is clear of Criticals, proceed below as a passing review. **A prior cycle
  exists, or Criticals remain after the re-review:** stop with the standard block message
  below — never a second cycle. Zero Critical findings → no cycle at all.
- **Step-by-step (or cycle exhausted): STOP**, telling the user to resolve the
  Critical findings (re-running `/feature-flow:ff-implement` or fixing directly) and then re-run
  `/feature-flow:ff-review` — do **not** route forward to verify or done (in either mode).

Otherwise set `phases.review = { status: "complete", artifact: "review.md" }`, bump
`updatedAt`, and hand off by track:

- **Feature track:** review runs **before** verify. If `manifest.autopilot` is `true`,
  emit the progress strip and proceed directly into the verify phase per
  `${CLAUDE_PLUGIN_ROOT}/commands/ff-verify.md` — see **Autopilot** in
  `${CLAUDE_PLUGIN_ROOT}/docs/manifest-schema.md`. If `false` or absent, leave
  `currentPhase = "review"` and **STOP**, telling the user to run `/feature-flow:ff-verify` next.
- **Bugfix track:** review is the **terminal** phase (it runs after verify). If verify has
  already passed (`phases.verify.status == "complete"`), first run **KB capture** (see
  `## KB capture (when enabled)` below — a no-op unless the KB is active), then set
  `currentPhase = "done"`, **STOP** and report the run complete (both modes — run completion is
  always a full report). If
  verify has **not** run yet (`phases.verify.status != "complete"`): if `manifest.autopilot`
  is `true`, emit the progress strip and proceed directly into the verify phase per
  `${CLAUDE_PLUGIN_ROOT}/commands/ff-verify.md`; if `false` or absent, leave
  `currentPhase = "review"` and **STOP**,
  telling the user to run `/feature-flow:ff-verify` to confirm RED→GREEN — the run is not done
  until both terminal phases are complete.

End the message with the one-line progress strip — see **Progress strip** in
`${CLAUDE_PLUGIN_ROOT}/docs/manifest-schema.md`. In step-by-step mode, end your turn (the
autopilot branches above continue instead).

## KB capture (when enabled)

Runs **only on the bugfix track** (review is the bugfix-terminal phase). **Feature-track guard:**
on the **feature track** review precedes verify, so capture happens at `/feature-flow:ff-verify` —
**skip this step entirely on the feature track** to avoid double-capture. It is also skipped while a
Critical-review block is unresolved (the run is not yet at terminal convergence).

Sequenced **after** `review.md` + the manifest update but **before** `currentPhase = "done"`, and a
**no-op unless the KB is active** (`toggles.kb === true` AND `paths.kb` non-null, read from
`.feature-flow.json` → `${CLAUDE_PLUGIN_ROOT}/config/defaults.json`). When inactive (or on the
feature track), do nothing — behavior is byte-identical to today.

When active on the bugfix terminal, follow the **Knowledge base** capture rule in
`${CLAUDE_PLUGIN_ROOT}/docs/manifest-schema.md` exactly:

1. Read this run's artifacts via `manifest.artifacts.<name>` pointers — the diagnosis from
   `artifacts.diagnosis`, the plan from `artifacts.plan` (if the bug escalated), plus this
   `review.md` and the verify from `artifacts.verify` — **never** bare filenames (keeps
   `durable-paths-guard.sh` GREEN).
2. Capture `git rev-parse HEAD` inline → `captureCommitSha`, or `null` on failure (never blocks).
3. Distill **1–3 candidate entries**, biased to architectural decisions + project conventions,
   auto-proposing `tags` + `referencedFiles`.
4. **Confirm gate (cross-turn, mandatory in both modes):** the user accepts / edits / rejects each;
   write **nothing** until confirmed — autopilot mandatory pause (see **Autopilot** §KB capture
   confirm-gate row); the chain resumes to `currentPhase = "done"` on the answer or
   `/feature-flow:ff-resume`.
5. For each accepted entry: `mkdir -p <paths.kb>` and **Write** it from
   `${CLAUDE_PLUGIN_ROOT}/templates/kb-entry.md` to
   `<paths.kb>/<captureDate>-<runSlug>-<short-title>.md`. Perform **no** `git add` / `git commit`.
6. Reject-all / none proposed → write nothing. Either way, proceed to `currentPhase = "done"`.
