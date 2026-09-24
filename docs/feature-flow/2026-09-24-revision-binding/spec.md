# Spec: Bind review and verify to the same code revision

**Created:** 2026-09-24
**Track:** feature
**Status:** signed-off

## Problem

Feature Flow can mark a run `done` on code that was never both reviewed **and** verified
(finding F01, `docs/feature-flow-architectural-review-2026-07-23.md`, rated Critical). On the
feature track review runs before verify, and verify's autopilot repair cycle — or any hand edit
between the phases — changes code after review has already passed. On the bugfix track verify can
run first and review's autopilot fix cycle changes code afterwards. Nothing records *which code*
each phase attested, so `done` cannot tell. This undermines the framework's central claim:
"verified" must mean "this exact code was reviewed and verified".

Recording `git HEAD` is not enough: Feature Flow never commits during a run, so HEAD is the same
at implement, review and verify while the working tree changes underneath.

## Expected outcome

Review and verify each record a **revision** — a fingerprint of the working tree's code — when
they complete. A run reaches `done` only when both recorded revisions are equal and equal the
tree as it is at that moment. On a mismatch the terminal command names the stale phase and which
paths changed; autopilot re-runs the stale phase once, then stops if the revisions still
disagree. On Claude Code the `enforce-gate` hook refuses a `done` write that violates this; on
Codex the same rule holds as prose. Runs from before this version, and projects that are not git
repositories, behave exactly as today apart from a one-line note.

## Solution approaches considered

- **Chosen — working-tree fingerprint.** A git tree id over the working tree: tracked files as
  they currently are, plus untracked non-ignored files, minus Feature Flow's own bookkeeping paths
  and nested repositories. It catches uncommitted edits (the normal case here). Prototyped during
  explore on this repo (603 files, ~35 ms): repeatable, unchanged by `.feature-flow/` writes,
  changed by tracked and untracked edits, restored by a revert, real index untouched.
- **Rejected — HEAD SHA only** (the request as first phrased). Cheapest, but HEAD does not move
  during a run, so a verify repair after review goes undetected; it would not close F01.
- **Rejected — commit at each phase end** (makes HEAD meaningful). Breaks Feature Flow's
  write-only / never-commit doctrine and writes commits into the user's history.
- **Rejected — route through the Go integrity kernel now** (`Converge()` already implements this).
  CI forbids commands and hooks from invoking the kernel, and the WP4 adapter branch is unmerged,
  ~50 days behind master, and observe-only. User decision: ship in bash now; WP4 must preserve it.

## Assumptions (WHAT-changing)

| Statement | Confidence | Basis / evidence | If-wrong impact | Validation-required |
|---|---|---|---|---|
| During a run, Feature Flow's own writes outside code land only under `paths.base`, `paths.durable` and `paths.kb` | high | explore: no `git add`/`commit` in commands/hooks; promotion, evidence copy and KB capture all target those three roots | Bookkeeping writes change the revision → spurious mismatches at `done`; the exclusion set would need widening | n |
| `git` is on PATH wherever the project is a git repository and Claude Code runs the hook | high | the hook already runs under bash with `jq`; git repos imply a git client | Every strict run would hit the fail-open warning path instead of being checked | n |
| Running the project's tests/build during verify does not create untracked, non-ignored files outside the bookkeeping paths (they are gitignored in a well-configured repo) | med | common practice; unverified across projects; this repo's guards write only to temp dirs | Verify's revision would include build output that review's does not → a false mismatch on every run; the WHAT would have to become "tracked files + untracked files that existed at review" or similar | y |
| Computing the fingerprint at the done-transition is fast enough on large repositories (it reuses the real index's stat cache) | med | ~35 ms on 603 files here; one computation per `done` write | Slow `done` writes on monorepos; would need a size cap or an opt-out toggle | y |

## Constraints

- **No Go kernel calls** from `commands/`, `hooks/`, `templates/`, `config/` —
  `scripts/checks/integrity-boundary-guard.sh` must stay green. The fingerprint is plain bash + git.
- **Fail-open doctrine** of `hooks/enforce-gate`: deny only a determinate-illegal transition;
  anything indeterminate allows — but a computation failure inside a git repo on a strict run must
  be **loud** (a `systemMessage`), like the missing-`jq` path, never silent.
- The hook's hot path stays cheap: any git work runs only when a write proposes `currentPhase: "done"`.
- **Codex parity:** Codex ships no hooks, so the rule must be stated in `ff-review`, `ff-verify` and
  the contract so it is followed as prose there.
- Template placeholders stay **digit-free** — the `b-template` fixture must keep denying.
- **Never-commit doctrine unchanged:** Feature Flow still never runs `git add`/`commit` on the
  user's index or history (the fingerprint uses a throwaway index).
- **WP4 constraint:** the CHANGELOG and `docs/schema/enforcement.md` state that any future WP4 merge
  must preserve Gates A/B and revision binding (or supersede them in kernel enforce mode) — never
  regress to observe-only.
- Release as **0.22.0** (`version-sync-guard.sh` green).

## Touchpoints

- `hooks/enforce-gate` — revision fingerprint + Gate B revision check (done-writes only).
- `commands/ff-review.md` — stamp the reviewed revision at completion (after any fix cycle);
  terminal-convergence check on bugfix.
- `commands/ff-verify.md` — stamp the verified revision at completion (after any repair cycle);
  terminal-convergence check + bounded re-run routing on both tracks.
- `commands/ff.md` (and cold-start paths in `ff-explore` / `ff-clarify` / `ff-diagnose`) — mark new
  runs as revision-bound at manifest creation.
- `docs/manifest-schema.md` — Schema block + Field notes for the new fields; back-compat rule.
- `docs/schema/enforcement.md` — Gate B revision condition, fail-open cases, WP4 constraint.
- `docs/schema/terminal-convergence.md` — `done` requires both phases on the current revision.
- `docs/schema/autopilot.md` — fix / repair cycles re-stamp; the one bounded stale-phase re-run.
- `templates/review.md`, `templates/verify.md` — a revision header line (digit-free placeholder).
- `scripts/checks/enforce-gate-guard.sh` — git-repo fixtures; PATH-shim case updated for `git`.
- `scripts/checks/` — a structural guard for the prose wiring (new file or extension of an existing one).
- `dist/codex/feature-flow/**` — repackaged; `.claude-plugin/plugin.json`, `.codex-plugin/plugin.json`,
  `.claude-plugin/marketplace.json`, `README.md`, `CHANGELOG.md` — version 0.22.0.

## Edge cases

- **Clean tree** (no changes since HEAD): the revision still computes (equals HEAD's tree) and the
  check applies normally.
- **Only bookkeeping paths changed** between review and verify (manifest, `verify.md`, evidence,
  KB entries, promoted durable docs): no mismatch.
- **The feature's own writes at done:** KB capture and durable promotion happen before the `done`
  write and must not invalidate the stamps (they are bookkeeping paths).
- **Re-running a phase** (review twice, verify twice): each completion overwrites that phase's stamp.
- **Revert to the reviewed state** after an edit: the revision returns to the stamped value and the
  check passes.
- **Nested git repositories / worktrees inside the project** (e.g. `.claude/worktrees/*`): ignored.
- **Error path:** fingerprint computation fails inside a git repo on a strict run → hook allows with a
  loud warning; the terminal command reports the check as not performed.
- **Deleted file** after review: counts as a change.

## Non-goals

- Changing the never-commit doctrine, or committing on the user's behalf.
- Wiring the Go integrity kernel, merging WP4, or adding a Codex hook adapter.
- Gating manifest rewrites done through `Bash` (still prose-gated, as today).
- Retro-stamping or migrating runs created before 0.22.0.
- Per-evidence-record revision stamps inside `verify.md` (one stamp per phase only).
- More than one automatic stale-phase re-run (no open-ended convergence loop).
- Changing which command is the done-transition.

## Acceptance criteria

- [ ] AC1: When `ff-review` completes on a revision-bound run in a git repo — including after an
  autopilot fix-and-re-review cycle — the manifest records the working-tree revision the review
  covered, and `review.md` states that revision in its header.
- [ ] AC2: When `ff-verify` completes on a revision-bound run in a git repo — including after an
  autopilot repair-and-re-verify cycle — the manifest records the revision of the tree as verified
  (post-repair), and `verify.md` states it in its header.
- [ ] AC3: The revision is unchanged by writes confined to `paths.base`, `paths.durable` and
  `paths.kb`, and by changes inside nested git repositories.
- [ ] AC4: The revision changes when a tracked file is modified or deleted, or an untracked
  non-ignored file is added, outside those paths; reverting the change restores the original value.
- [ ] AC5: On a revision-bound run in a git repo, `hooks/enforce-gate` **denies** a manifest write
  that sets `currentPhase: "done"` when the review revision is missing, the verify revision is
  missing, the two differ, or either differs from the current working-tree revision — with a
  `Gate B` reason naming which condition failed.
- [ ] AC6: The same write is **allowed** when both recorded revisions equal the current revision and
  the existing Gate B conditions hold.
- [ ] AC7: A mismatch reason lists the paths that differ between the stale revision and the current
  tree (capped, with a count of the rest), so a spurious mismatch is diagnosable.
- [ ] AC8: A run created before this version (not revision-bound), a project that is not a git
  repository, and `toggles.enforce: false` all leave Gate B's behaviour exactly as in 0.21.0; the
  terminal command's report says revision binding was skipped and why.
- [ ] AC9: If the fingerprint cannot be computed inside a git repo on a revision-bound run, the hook
  allows the write and emits a `systemMessage` warning; it never allows silently.
- [ ] AC10: Feature track: when verify's done-transition finds the review revision stale, autopilot
  re-runs the full review dispatch (focus + spec-conformance reviewers) exactly once and re-stamps;
  if review is then clean and all revisions agree, the run reaches `done`; otherwise it stops with a
  report naming the stale phase. Step-by-step stops and tells the user to re-run
  `/feature-flow:ff-review` then `/feature-flow:ff-verify`.
- [ ] AC11: Bugfix track: when the done-transition (whichever of verify/review runs second) finds the
  other phase's revision stale, autopilot re-runs that phase exactly once and re-stamps, then
  reaches `done` only if all revisions agree; otherwise it stops with a report. Step-by-step stops and
  names the phase to re-run.
- [ ] AC12: New runs are marked revision-bound at manifest creation (by `/feature-flow:ff` and by
  every cold-start path that creates a manifest).
- [ ] AC13: The rule is stated in prose in `ff-review`, `ff-verify`, `docs/schema/enforcement.md` and
  `docs/schema/terminal-convergence.md`, so Codex follows it without the hook; the WP4 constraint is
  stated in `docs/schema/enforcement.md` and the CHANGELOG.
- [ ] AC14: `scripts/checks/enforce-gate-guard.sh` exercises AC3–AC9 against real temporary git
  repositories, the verbatim `templates/verify.md` still denies (b-template), every existing fixture
  passes unchanged, and every `scripts/checks/*.sh` plus `scripts/eval.sh` exits 0.
- [ ] AC15: Version is 0.22.0 across the synced manifests, README badge and CHANGELOG head, and
  `dist/codex` is repackaged (dist-parity green).

## End-to-end check

- [ ] E2E: in a scratch git repo with a revision-bound feature manifest, pipe a `done` write through
  `hooks/run-hook.cmd enforce-gate` after (1) stamping review, editing a source file, then stamping
  verify → **denied**, reason names the stale review and the edited path; then (2) re-stamping review
  on the current tree → **allowed**.

## Success metrics

- [ ] SM1: The Gate B revision check adds ≤ 1 s to a `done` write on a repository of ≥ 20,000 tracked
  files, measured by timing the hook on a `done` payload with and without the check
  (`time bash hooks/enforce-gate < payload`).

## Requirement graph

| AC | Depends on |
|----|------------|
| AC5 | AC4 |
| AC6 | AC5 |
| AC7 | AC5 |
| AC10 | AC5 |
| AC11 | AC5 |
| AC14 | AC9 |

## Sign-off

**User signed off:** yes (2026-09-24)

Assumptions 3 and 4 acknowledged by user as staying open (2026-09-24) — carried to the plan as `**Validates:**` tasks.

> A spec without sign-off does not proceed to **design, planning, or implementation** —
> `/feature-flow:ff-design`, `/feature-flow:ff-plan`, and `/feature-flow:ff-implement` each stop and
> route back to `/feature-flow:ff-clarify` if this reads `no` (implement is the hard backstop). A
> waived review is recorded explicitly: "sign-off waived by user (date)" — never assumed.
