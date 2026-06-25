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

**Evidence authority — record, never paraphrase.** The test runner's returned per-command
`{command, exit status, excerpt}` is the evidence of record; transcribe it into `verify.md`
literally. A contract item may be marked `pass` **only** when it is backed by a captured
command with a success exit status — never on the runner's narration alone, never on your own
reasoning, and never inferred from "it looks right." If a returned result lacks an exit
status (the runner described a pass without a captured exit code), treat it as
`manual-unverified`, not `pass`, and say why. Do not re-author or upgrade the runner's
verdict; you only map its real output to the contract.

Build the contract mapping in `verify.md` from `${CLAUDE_PLUGIN_ROOT}/templates/verify.md`:

- **Feature track:** map **each acceptance criterion** from the spec (at `artifacts.spec`, as
  resolved in Cold-start) → `pass` / `fail` / `manual-unverified` (with a reason), each backed
  by evidence from the test runner.
- **Bugfix track:** confirm the bug no longer reproduces, and that the regression test
  shows RED (pre-fix) → GREEN (post-fix). Cite the `bugfix.red` / `bugfix.green` evidence
  captured by `/feature-flow:ff-implement` for the pre-fix failure, and the test runner's fresh run for
  the post-fix pass. If the manifest has no `bugfix.red` evidence, the fix was not done
  test-first — report it **incomplete** (the RED state can no longer be reconstructed).
- Assess **regression risk** (`Low | Medium | High` + reason) from the surface the change
  touched — shared / central code raises it, isolated new code lowers it — and record it in
  `verify.md` §Regression risk. No numeric score.

## Refuse premature "done"

Do **not** report the work as done unless **every** contract item has a `pass` or an
explicit `manual-unverified` line with a reason. If automated tests are absent, say so —
run build/lint/smoke instead and never call a no-tests run a pass. On the bugfix track, a
fix without a regression test (RED→GREEN evidence) is reported **incomplete**, not done.

## Update manifest + hand off (order differs by track)

**Use the Write tool** to write `verify.md`. Set
`phases.verify = { status: "complete", artifact: "verify.md" }`, bump `updatedAt`.

- **Feature track:** verify is the **terminal** phase. If all contract items pass, first run
  **KB capture** (see `## KB capture (when enabled)` below — a no-op unless the KB is active),
  then set `currentPhase = "done"`. **STOP** and report the run complete.
- **Bugfix track:** review is the terminal phase, so the two can be run in either order —
  converge on `done` only when **both** verify and review are complete:
  - If `phases.review.status == "complete"` (review already ran) and verify passed, both
    terminal phases are satisfied → this command is the one reaching the done-transition, so
    first run **KB capture** (see `## KB capture (when enabled)` below — a no-op unless the KB is
    active), then set `currentPhase = "done"` and report the run complete.
  - Otherwise review still has to run. If `manifest.autopilot` is `true`, emit the progress
    strip and proceed directly into the review phase per
    `${CLAUDE_PLUGIN_ROOT}/commands/ff-review.md` — see **Autopilot** in
    `${CLAUDE_PLUGIN_ROOT}/docs/manifest-schema.md`. If `false` or absent: leave
    `currentPhase = "verify"`, **STOP**, report the RED→GREEN result, and tell the user to
    run `/feature-flow:ff-review` next.

Report the verification result (pass/fail per contract item, with evidence), end the message
with the one-line progress strip — see **Progress strip** in
`${CLAUDE_PLUGIN_ROOT}/docs/manifest-schema.md` — and end your turn.

## KB capture (when enabled)

Runs whenever **this command transitions the run to `currentPhase = "done"`** — i.e. the
**feature-track terminal** (verify is always feature-terminal) **and** the **bugfix convergence**
branch above where review already completed and verify now passes. Sequenced **after** `verify.md` +
the manifest update but **before** `currentPhase = "done"`, so a dropped session re-runs verify and
re-fires the gate. **Skip** when this command is *not* the one reaching `done` — on the bugfix track
when review has not run yet (verify hands off to `/feature-flow:ff-review`, which fires capture at
its own done-transition). Capture fires at **exactly one** command — whichever sets `done` — so the
bugfix track never double-captures.

It is a **no-op unless the KB is active** (`toggles.kb === true` AND `paths.kb` non-null, read from
`.feature-flow.json` → `${CLAUDE_PLUGIN_ROOT}/config/defaults.json`). When inactive, do nothing and
proceed to `currentPhase = "done"` — behavior is byte-identical to today.

When active, follow the **Knowledge base** capture rule in
`${CLAUDE_PLUGIN_ROOT}/docs/manifest-schema.md` exactly:

1. Read this run's artifacts via `manifest.artifacts.<name>` pointers — **feature track:** the spec
   from `artifacts.spec`, the design from `artifacts.design` (if present); **bugfix track:** the
   diagnosis from `artifacts.diagnosis`, the plan from `artifacts.plan` (if escalated) — plus this
   `verify.md` and the review from `artifacts.review`. **Never** bare filenames (keeps
   `durable-paths-guard.sh` GREEN).
2. Capture `git rev-parse HEAD` inline → `captureCommitSha`, or `null` on failure (never blocks).
3. Distill **1–3 candidate entries**, biased to architectural decisions + project conventions,
   auto-proposing `tags` + `referencedFiles`.
4. **Confirm gate (cross-turn, mandatory in both modes):** present the candidates; the user accepts
   / edits / rejects each. Write **nothing** until the user confirms — in autopilot this is a
   mandatory pause (see **Autopilot** §KB capture confirm-gate row); the chain resumes to
   `currentPhase = "done"` on the user's answer or on `/feature-flow:ff-resume`.
5. For each accepted entry: `mkdir -p <paths.kb>` and **Write** it from
   `${CLAUDE_PLUGIN_ROOT}/templates/kb-entry.md` to
   `<paths.kb>/<captureDate>-<runSlug>-<short-title>.md`. Perform **no** `git add` / `git commit`.
6. Reject-all / none proposed → write nothing. Either way, proceed to `currentPhase = "done"`.
