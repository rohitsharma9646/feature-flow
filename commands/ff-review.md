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
> `${CLAUDE_PLUGIN_ROOT}/docs/schema/autopilot.md`.

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
The reviewers have no shell and cannot run `git`, so hand each one the change under review **as a
file, by path — never pasted into the prompt**: write `<run dir>/review.diff` with `task_diff`
from the bookkeeping-free HEAD tree to the current working-tree fingerprint — it includes new
untracked files and leaves out Feature Flow's own bookkeeping (**Task packaging** in
`${CLAUDE_PLUGIN_ROOT}/docs/schema/task-controller.md`). Both tree ids come from **Revision
fingerprint** in `${CLAUDE_PLUGIN_ROOT}/docs/schema/enforcement.md`: the base from
`bash "${CLAUDE_PLUGIN_ROOT}/hooks/lib/revision.sh" "<project dir>" head`, the current tree without
`head`. Never diff against the raw `HEAD^{tree}` — it still holds the committed bookkeeping, which
would show up as deleted. If that fails, write `git diff HEAD` (staged +
unstaged) to the same file; on a greenfield / non-git project, write the list of files this run
touched instead.

**Rulings from implement.** When `manifest.artifacts.ledger` resolves (the run was implemented by
the task controller), give every reviewer the ledger's `**Ruling:**` lines as context: decisions the
controller took on Important findings after a task's fix loop ran out — judge each on its merits
(a ruling can still be a finding), but do not report the same issue again without saying it is a
ruled one.

**Over-engineering guard (every reviewer, including the spec-conformance one below).** Tell
each reviewer: report only gaps that affect correctness or the stated requirements; style
preferences, extra abstraction, and speculative hardening for cases that cannot occur are never
Critical (at most Important, and only when they clear the threshold). A reviewer asked to find
gaps will find some even in sound work — chasing every one of them is how a fix cycle grows
code the spec never asked for.

Dispatch the spec-conformance reviewer (next section) **in the same parallel batch**, then
consolidate once all of them have returned (§Consolidate).

## Spec conformance

The focus reviewers above judge the code on its own terms; none of them checks it against
**what this run promised**. Dispatch **one more `ff-code-reviewer`** (same `models.reviewer`,
same `reviewThreshold`), in parallel with the focus fan-out and **in addition to
`reviewerAgents`** — it is never counted against that setting, so `reviewerAgents: 1` still
gets a conformance check.

**Its input:** the same diff (or touched-file list) the focus reviewers get, plus the run's
**contract**, each resolved via its manifest pointer — never a bare filename:
- **Feature track:** the spec (`manifest.artifacts.spec`: acceptance criteria, `## Non-goals`,
  and `## Touchpoints` — the files / interfaces the change was expected to touch, its scope
  reference) and, on full tier, the plan (`manifest.artifacts.plan`: its tasks).
- **Bugfix track:** the diagnosis (`manifest.artifacts.diagnosis`: root cause + chosen fix
  approach) and, when the bug escalated, the plan (`manifest.artifacts.plan`).

No contract resolves (all pointers absent or missing on disk) → skip this dispatch and write
`Spec conformance: skipped — no contract artifact resolved` in `review.md`.

**Its brief:** for each contract item, is it realized in the change? Report:
- an acceptance criterion (or the diagnosis's chosen fix) that is not implemented or only
  partially implemented → **Critical** (the change does not do what the run promised);
- a change outside the stated scope (a file far outside `## Touchpoints` is the usual signal — a
  necessary neighbour of a touchpoint is not), or touching something the spec lists under
  `## Non-goals` →
  **Important**;
- a plan task with no corresponding change in the diff → **Important**.

It does **not** re-review bugs, style, or conventions (the focus reviewers own those), and the
over-engineering guard above applies to it too. Record its per-item verdict in `review.md`'s
`## Spec conformance` section, and list each Critical / Important gap under the matching
findings section as well, so the Critical-block rule below reads one place.

**Partial review (§Cold-start).** When this is a pre-implementation / partial review
(`phases.implement.status != "complete"`), a not-yet-implemented item is expected: record it
as `pending (partial review)` in the table and do **not** raise it as Critical. Out-of-scope
changes are still reported.

## Consolidate

Consolidate findings (de-duplicate across agents) into `review.md` from
`${CLAUDE_PLUGIN_ROOT}/templates/review.md`: Critical vs Important, each with file:line,
issue, and a concrete fix. If nothing meets the threshold, record the "no high-confidence
issues" summary — do not invent findings to look thorough.

## Stamp the revision (revision-bound runs)

Only when `manifest.revisionBound` is `true` (absent → skip this section entirely; a pre-v0.22.0
run records no revision), and only once the review is clear to complete — no Critical block remains,
after any fix-and-re-review cycle, because that cycle changes code. Compute the working-tree
fingerprint of the project directory exactly as **Revision fingerprint** in
`${CLAUDE_PLUGIN_ROOT}/docs/schema/enforcement.md` specifies — on Claude Code run
`bash "${CLAUDE_PLUGIN_ROOT}/hooks/lib/revision.sh" "<project dir>"`; where `hooks/` is not shipped,
pipe that section's block unchanged. Never re-type or paraphrase it: a variant yields a different id
and `done` is then denied. Record the printed id in `phases.review.revision` (written with the
manifest update below) **and** in `review.md`'s `**Revision:**` line. Empty output or a non-zero exit
(not a git repository, `git` missing) → record `null` and `not recorded — <reason>`. Stamping never
blocks the phase; a re-run of this command overwrites the stamp.

## Update manifest + hand off (order differs by track)

**Blocking findings block — both tracks.** If `review.md` contains ≥1 **Critical** finding,
do NOT mark the phase complete: leave `phases.review.status = "in_progress"` and
`currentPhase = "review"`, bump `updatedAt`.

- **Autopilot fix-and-re-review cycle (`manifest.autopilot: true` only).** First check
  `review.md` for an existing `## Resolution` section recording a prior autopilot fix cycle
  — the review artifact is the durable cycle record. **No prior cycle:** apply fixes for the
  Critical findings, append a `## Resolution` section to `review.md` (pre-fix findings,
  fixes applied, outcome), and re-run the reviewer dispatch — focus reviewers **and** the
  spec-conformance reviewer — **exactly once**; if the
  re-review is clear of Criticals, proceed below as a passing review. **A prior cycle
  exists, or Criticals remain after the re-review:** stop with the standard block message
  below — never a second cycle. Zero Critical findings → no cycle at all.
- **Step-by-step (or cycle exhausted): STOP**, telling the user to resolve the
  Critical findings (re-running `/feature-flow:ff-implement` or fixing directly) and then re-run
  `/feature-flow:ff-review` — do **not** route forward to verify or done (in either mode).

Otherwise set `phases.review = { status: "complete", artifact: "review.md" }`, bump
`updatedAt`, and hand off by track. (Which command marks the run `done` is the canonical
**Terminal convergence** rule in `${CLAUDE_PLUGIN_ROOT}/docs/schema/terminal-convergence.md`; the routing
below implements it.)

- **Feature track:** review runs **before** verify. If `manifest.autopilot` is `true`,
  emit the progress strip and proceed directly into the verify phase per
  `${CLAUDE_PLUGIN_ROOT}/commands/ff-verify.md` — see **Autopilot** in
  `${CLAUDE_PLUGIN_ROOT}/docs/schema/autopilot.md`. If `false` or absent, leave
  `currentPhase = "review"` and **STOP**, telling the user to run `/feature-flow:ff-verify` next.
- **Bugfix track:** review is the **terminal** phase (it runs after verify). If verify has
  already passed (`phases.verify.status == "complete"`), first check **Revision agreement** in
  `${CLAUDE_PLUGIN_ROOT}/docs/schema/terminal-convergence.md` (revision-bound runs): compare
  `phases.verify.revision` to the review revision just stamped. Stale or missing → the
  **Stale-phase re-run cycle** in `${CLAUDE_PLUGIN_ROOT}/docs/schema/autopilot.md` re-runs verify
  (autopilot), or **STOP** telling the user verify is stale — which paths changed — and to re-run
  `/feature-flow:ff-verify` (step-by-step); never set `done` on a stale revision. Not checked → say
  why in the completion report: `revision binding skipped — run predates v0.22.0` (no
  `revisionBound`) or `revision binding skipped — <not a git repository | fingerprint not computable>`. Then run **KB capture** (see
  `## KB capture (when enabled)` below — a no-op unless the KB is active), then set
  `currentPhase = "done"`, **STOP** and report the run complete (both modes — run completion is
  always a full report). In the completion report, name `/feature-flow:ff-deliver` (delivery notes) and `/feature-flow:ff-retro` (retrospective on the workflow's safeguards) as **optional next steps** — neither is ever chained (§Autopilot). If
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
feature track), do nothing.

When active on the bugfix terminal, follow the **Knowledge base** capture rule in
`${CLAUDE_PLUGIN_ROOT}/docs/schema/knowledge-base.md` exactly — that is the canonical procedure (git SHA
→ provenance, distill 1–3 candidates, the cross-turn confirm gate, write accepted entries from
`${CLAUDE_PLUGIN_ROOT}/templates/kb-entry.md`, **no** `git add`/`commit`, reject-all writes
nothing); **do not restate its steps here.** The only command-specific input: read this run's
artifacts **only** via `manifest.artifacts.<name>` pointers (never bare filenames) — the diagnosis
(`artifacts.diagnosis`), the plan (`artifacts.plan`, if the bug escalated), plus this `review.md`
and the verify (`artifacts.verify`).
