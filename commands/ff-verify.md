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
  shows RED (pre-fix) → GREEN (post-fix). Cite the `bugfix.red` / `bugfix.green` evidence
  captured by `/ff-implement` for the pre-fix failure, and the test runner's fresh run for
  the post-fix pass. If the manifest has no `bugfix.red` evidence, the fix was not done
  test-first — report it **incomplete** (the RED state can no longer be reconstructed).

## Refuse premature "done"

Do **not** report the work as done unless **every** contract item has a `pass` or an
explicit `manual-unverified` line with a reason. If automated tests are absent, say so —
run build/lint/smoke instead and never call a no-tests run a pass. On the bugfix track, a
fix without a regression test (RED→GREEN evidence) is reported **incomplete**, not done.

## Update manifest + hand off (order differs by track)

**Use the Write tool** to write `verify.md`. Set
`phases.verify = { status: "complete", artifact: "verify.md" }`, bump `updatedAt`.

- **Feature track:** verify is the **terminal** phase. If all contract items pass, set
  `currentPhase = "done"`. **STOP** and report the run complete.
- **Bugfix track:** review is the terminal phase, so the two can be run in either order —
  converge on `done` only when **both** verify and review are complete:
  - If `phases.review.status == "complete"` (review already ran) and verify passed, both
    terminal phases are satisfied → set `currentPhase = "done"` and report the run complete.
  - Otherwise review still has to run: leave `currentPhase = "verify"`, **STOP**, report the
    RED→GREEN result, and tell the user to run `/feature-flow:ff-review` next.

Report the verification result (pass/fail per contract item, with evidence) and end your turn.
