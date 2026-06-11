---
description: "[shared] Run the project's tests/build/lint via ff-test-runner and map the contract to pass/fail with evidence."
argument-hint: "<run after /ff-implement (and /ff-review)>"
---

# /ff-verify — verification phase

Real, executed verification. Output: `verify.md` with evidence. This phase refuses to
declare "done" on reasoning alone.

> **Precedence — read first.** You are executing the feature-flow workflow. Its phases
> REPLACE any generic brainstorming / writing-plans / make-plan / docs-first planning: do
> **not** invoke those skills, and do **not** write to `~/.claude/plans/`, `docs/plans/`,
> or a separate brainstorm doc. All run state lives in the `.feature-flow/<slug>/` sandbox
> and its `manifest.json`. Follow this command's steps literally, create files with the
> Write tool, run only this one phase, then STOP.

## Manifest contract

1. Resolve config + manifest. Set `phases.verify.status = "in_progress"`, bump
   `currentPhase`.

## Cold-start

If there is no `spec.md` (feature) or `diagnosis.md` (bugfix), ask the user what contract
to verify against before running anything.

## Do the work

Dispatch the **`ff-test-runner`** agent. It detects and **actually runs** the project's
test / build / lint commands and returns real output (command, exit status, failing
excerpts). It never edits code.

Build the contract mapping in `verify.md` from `${CLAUDE_PLUGIN_ROOT}/templates/verify.md`:

- **Feature track:** map **each acceptance criterion** from `spec.md` → `pass` / `fail` /
  `manual-unverified` (with a reason), each backed by evidence from the test runner.
- **Bugfix track:** confirm the bug no longer reproduces, and that the regression test
  shows RED (pre-fix) → GREEN (post-fix) using the captured evidence.

## Refuse premature "done"

Do **not** report the work as done unless **every** contract item has a `pass` or an
explicit `manual-unverified` line with a reason. If automated tests are absent, say so —
run build/lint/smoke instead and never call a no-tests run a pass. On the bugfix track, a
fix without a regression test (RED→GREEN evidence) is reported **incomplete**, not done.

## Update manifest

**Use the Write tool** to write `verify.md`. Set
`phases.verify = { status: "complete", artifact: "verify.md" }`, bump `updatedAt`. If all
contract items pass, set `currentPhase = "done"`.

**STOP.** Report the verification result (pass/fail per contract item, with evidence) and
end your turn.
