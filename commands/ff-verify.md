---
description: "[shared] Run the project's tests/build/lint via ff-test-runner and map the contract to pass/fail with evidence."
argument-hint: "<run after /feature-flow:ff-implement (and /feature-flow:ff-review)>"
---

# /feature-flow:ff-verify — verification phase

Real, executed verification. Output: `verify.md` with evidence. This phase refuses to
declare "done" on reasoning alone.

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
2. **Re-run guard:** if `phases.verify.status` is already `"complete"`, stop and ask for
   explicit confirmation before overwriting `verify.md` — see **Re-run guard** in
   `${CLAUDE_PLUGIN_ROOT}/docs/manifest-schema.md`.
3. Set `phases.verify.status = "in_progress"`, bump `currentPhase`.

## Cold-start

**Resolve the contract artifact through the manifest pointer first:** take the spec from
`manifest.artifacts.spec` (feature) or the diagnosis from `manifest.artifacts.diagnosis`
(bugfix) — manifest-first, sandbox fallback `<base>/<slug>/<name>.md` only when the manifest
is absent. There is no contract to verify against without an upstream artifact — route, don't
ask open-endedly: if the resolved spec is missing on the feature track, **STOP** and tell the
user to run `/feature-flow:ff-clarify` first; if the resolved diagnosis is missing on the
bugfix track, **STOP** and tell the user to run `/feature-flow:ff-diagnose` first.

## Do the work

Read `models.testRunner` from config (`.feature-flow.json` →
`${CLAUDE_PLUGIN_ROOT}/config/defaults.json`) and pass it as the `model` for the dispatched
agent. Dispatch the **`ff-test-runner`** agent. It detects and **actually runs** the project's
test / build / lint commands and returns real output (command, exit status, failing
excerpts). It never edits code.

Build the contract mapping in `verify.md` from `${CLAUDE_PLUGIN_ROOT}/templates/verify.md`:

- **Feature track:** map **each acceptance criterion** from the spec (at `artifacts.spec`, as
  resolved in Cold-start) → `pass` / `fail` / `manual-unverified` (with a reason), each backed
  by evidence from the test runner.
- **Bugfix track:** confirm the bug no longer reproduces, and that the regression test
  shows RED (pre-fix) → GREEN (post-fix). Cite the `bugfix.red` / `bugfix.green` evidence
  captured by `/feature-flow:ff-implement` for the pre-fix failure, and the test runner's fresh run for
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
  - Otherwise review still has to run. If `manifest.autopilot` is `true`, emit the progress
    strip and proceed directly into the review phase per
    `${CLAUDE_PLUGIN_ROOT}/commands/ff-review.md` — see **Autopilot** in
    `${CLAUDE_PLUGIN_ROOT}/docs/manifest-schema.md`. If `false` or absent: leave
    `currentPhase = "verify"`, **STOP**, report the RED→GREEN result, and tell the user to
    run `/feature-flow:ff-review` next.

Report the verification result (pass/fail per contract item, with evidence), end the message
with the one-line progress strip — see **Progress strip** in
`${CLAUDE_PLUGIN_ROOT}/docs/manifest-schema.md` — and end your turn.
