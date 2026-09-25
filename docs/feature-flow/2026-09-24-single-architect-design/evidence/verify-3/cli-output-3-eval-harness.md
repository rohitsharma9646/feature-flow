# cli-output-3-eval-harness.md

kind: cli-output
command: `bash scripts/eval.sh` (from /home/netzwelt/feature-flow)
exit status: 0 (PASS)
date: 2026-09-25 (third pass)

## Tail of output

```
  ok:   shipped plan template defines '## Dependency graph' (fixture not drifted)
  ok:   commands/ff-verify.md maps each Success-metrics row into its own SM<n> contract item
  ok:   commands/ff-plan.md carries the requirement-graph task-edge derivation instruction
PASS: discovery-gap (preconditions) — semantic catch is AC6/AC8/manual

fixture: task-controller
  ok:   hooks/lib/task.sh exists
  ok:   task_section '^### Task 2:' returns exactly the expected section (fences respected)
  ok:   task_section '^### Task 3:' returns exactly the expected section (fences respected)
  ok:   task_section '^## Global Constraints' returns exactly the expected section (fences respected)
  ok:   task_section '^## Dependency graph' returns exactly the expected section (fences respected)
  ok:   a heading that exists only inside a fence is not found (exit 1, no output)
  ok:   task_diff shows the tracked edit and the new untracked file
  ok:   task_diff starts with a --stat summary
  ok:   the real index is byte-identical before and after task_diff
  ok:   a non-hex tree id is refused (exit 1, no output)
  ok:   revision.sh head equals the fingerprint on a clean tree with committed bookkeeping
  ok:   whole-change diff from the head base shows code, not bookkeeping
PASS: task-controller (task_section fences, task_diff) — the controller loop firing is the forward test
EXIT_CODE=0
```

## Full output

```
fixture: decision-conflict
  ok:   fixture decision record exists (evals/fixtures/decision-conflict/decision.md)
  ok:   fixture carries 'tags:'
  ok:   fixture carries '## Decision'
  ok:   fixture carries '## Chosen \+ rationale'
  ok:   shipped template still defines '## Decision' (fixture not drifted)
  ok:   shipped template still defines '## Chosen \+ rationale' (fixture not drifted)
  ok:   tag 'session-storage' tag-matches the contradicting request (decision would be recalled)
  ok:   commands/ff-implement.md carries the do-not-contradict STOP instruction
PASS: decision-conflict (preconditions) — semantic catch is AC13/manual

fixture: delivery-gap
  ok:   fixture plan exists (evals/fixtures/delivery-gap/plan.md)
  ok:   fixture plan carries a migration/schema task
  ok:   migration task has no recovery row in Rollback plan — the delivery gap is present and detectable
  ok:   shipped delivery template defines 'Rollback checklist' (fixture not drifted)
  ok:   shipped delivery template defines 'Known issues' (fixture not drifted)
  ok:   shipped delivery template defines 'Release validation steps' (fixture not drifted)
  ok:   commands/ff-deliver.md carries the DELIVERY GAP detection instruction
  ok:   commands/ff-deliver.md resolves upstream via artifacts.plan
  ok:   commands/ff-deliver.md resolves upstream via artifacts.verify
PASS: delivery-gap (preconditions) — semantic catch is AC5/manual

fixture: assumption-gap
  ok:   fixture spec exists (evals/fixtures/assumption-gap/spec.md)
  ok:   fixture carries the 5-column assumptions header
  ok:   fixture has an unvalidated 'validation-required: y' row — the gap is present
  ok:   shipped template still defines '## Assumptions (WHAT-changing)' (fixture not drifted)
  ok:   shipped template still carries the 5-column header (fixture not drifted)
  ok:   commands/ff-clarify.md carries the unvalidated-assumptions echo instruction
  ok:   commands/ff-clarify.md carries the verbatim waiver line
  ok:   commands/ff-diagnose.md carries the unvalidated-assumptions echo instruction
  ok:   commands/ff-diagnose.md carries the verbatim waiver line
PASS: assumption-gap (preconditions) — semantic catch is AC6/AC7/manual

fixture: planning-gap
  ok:   fixture plan exists (evals/fixtures/planning-gap/plan.md)
  ok:   fixture Dependency graph carries Task N rows
  ok:   fixture states a critical path (Task 1 → Task 3)
  ok:   graph proves Task 3 depends on the gating Task 2
  ok:   stated critical path drops the gating Task 2 — the planning gap is present and detectable
  ok:   shipped plan template defines 'Dependency graph' (fixture not drifted)
  ok:   shipped plan template defines 'Critical path' (fixture not drifted)
  ok:   shipped plan template states the critical path is derived, never hand-authored
  ok:   commands/ff-plan.md instructs deriving the path (never hand-author)
  ok:   commands/ff-implement.md §Critical-path check resolves the path via artifacts.plan
PASS: planning-gap (preconditions) — semantic catch is AC15/manual

fixture: design-gap
  ok:   fixture design exists (evals/fixtures/design-gap/design.md)
  ok:   fixture carries a labeled FS1 failure scenario — the gap is present and detectable
  ok:   shipped design template defines '## Trade-off matrix' (fixture not drifted)
  ok:   shipped design template defines '## Devil's advocate' (fixture not drifted)
  ok:   shipped design template defines '### Failure scenarios' (fixture not drifted)
  ok:   commands/ff-verify.md resolves upstream via artifacts.design
  ok:   commands/ff-verify.md carries the FS<n>-maps-like-an-AC instruction
PASS: design-gap (preconditions) — semantic catch is AC7/AC8/manual

fixture: repair-gap
  ok:   first-cycle fixture exists (evals/fixtures/repair-gap/verify.md)
  ok:   first-cycle fixture carries a captured non-success status — a genuine failure, not a pure gap
  ok:   first-cycle fixture has no '## Repair' yet — a first cycle is available
  ok:   capped fixture exists (evals/fixtures/repair-gap/verify-capped.md)
  ok:   capped fixture carries '## Repair' — the cap is detectable, no second cycle
  ok:   shipped verify template defines '## Contract mapping' (fixtures not drifted)
  ok:   shipped verify template defines '## Repair' (fixtures not drifted)
  ok:   commands/ff-verify.md carries the autopilot repair-and-re-verify branch
PASS: repair-gap (preconditions) — semantic catch is AC13/AC14/manual

fixture: discovery-gap
  ok:   fixture spec exists (evals/fixtures/discovery-gap/spec.md)
  ok:   fixture carries a labeled 'SM1:' success-metric row — the metric side is present and detectable
  ok:   fixture Requirement graph carries the 'AC2 depends-on AC1' edge
  ok:   fixture plan exists (evals/fixtures/discovery-gap/plan.md)
  ok:   fixture plan drops the AC-derived Task 2 → Task 1 edge — the requirement-graph gap is present and detectable
  ok:   shipped spec template defines 'Success metrics' (fixture not drifted)
  ok:   shipped spec template defines 'Requirement graph' (fixture not drifted)
  ok:   shipped plan template defines '## Dependency graph' (fixture not drifted)
  ok:   commands/ff-verify.md maps each Success-metrics row into its own SM<n> contract item
  ok:   commands/ff-plan.md carries the requirement-graph task-edge derivation instruction
PASS: discovery-gap (preconditions) — semantic catch is AC6/AC8/manual

fixture: task-controller
  ok:   hooks/lib/task.sh exists
  ok:   task_section '^### Task 2:' returns exactly the expected section (fences respected)
  ok:   task_section '^### Task 3:' returns exactly the expected section (fences respected)
  ok:   task_section '^## Global Constraints' returns exactly the expected section (fences respected)
  ok:   task_section '^## Dependency graph' returns exactly the expected section (fences respected)
  ok:   a heading that exists only inside a fence is not found (exit 1, no output)
  ok:   task_diff shows the tracked edit and the new untracked file
  ok:   task_diff starts with a --stat summary
  ok:   the real index is byte-identical before and after task_diff
  ok:   a non-hex tree id is refused (exit 1, no output)
  ok:   revision.sh head equals the fingerprint on a clean tree with committed bookkeeping
  ok:   whole-change diff from the head base shows code, not bookkeeping
PASS: task-controller (task_section fences, task_diff) — the controller loop firing is the forward test
EXIT_CODE=0
```
