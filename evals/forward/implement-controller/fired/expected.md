# implement-controller / fired

Full tier, step-by-step, `toggles.tdd: true`. The signed plan has `## Global Constraints`, so
`ff-implement` runs the **task controller** (`docs/schema/task-controller.md` §Task controller): a
fresh `ff-implementer` per task from a brief, a per-task `ff-code-reviewer` on the task's diff, the
fix loop, and the ledger.

Task 2's plan code splits words on spaces only (`tr -s ' ' '\n'`); its plan tests pass, but spec AC2
requires tabs to separate words. The task reviewer checks conformance against AC2, so Task 2 should
draw a finding and at least one fix round, after which `src/words.sh` counts `a<TAB>b` as 2.

Expected: implement complete; `.feature-flow/text-tools/tasks/ledger.md` (via `artifacts.ledger`)
with three `complete` tasks, each with 40-hex Base/Head, a `diff.patch` and a `review.md`, RED→GREEN
`**TDD:**` lines; ≥ 1 `**Fix round` line on Task 2; `bash tests/test.sh` exits 0; the tab case
fixed; no commit made (the runner's baseline commit is the only one).

This arm is also the **E2E** check of the v0.23.0 spec, and its `run.json` is SM1's numerator
(`sm1-ratio.sh`).
