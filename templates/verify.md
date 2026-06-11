# Verify: <feature title or bug>

**Track:** feature | bugfix
**Date:** <date>
**Verified by:** `ff-test-runner` (executed) — evidence below is real command output.

## Commands run

| Command | Status | Evidence |
|---------|--------|----------|
| `<test command>` | pass / fail | <exit status + key output excerpt> |
| `<build command>` | pass / fail | <…> |
| `<lint command>` | pass / fail | <…> |

> If no automated tests exist, that is stated here explicitly and build/lint/smoke is
> run instead — a "no tests" run is never reported as a pass.

## Contract mapping

**Feature track** — every acceptance criterion from `spec.md`:

| Contract item | Result | Evidence |
|---------------|--------|----------|
| AC1: <…> | pass / fail / manual-unverified | <evidence or reason it can't be auto-checked> |
| AC2: <…> | pass / fail / manual-unverified | <…> |

**Bugfix track** — the bug + the regression test:

| Contract item | Result | Evidence |
|---------------|--------|----------|
| Bug no longer reproduces | pass / fail | <repro attempt output> |
| Regression test: RED before fix | observed / missing | <pre-fix failing output> |
| Regression test: GREEN after fix | observed / missing | <post-fix passing output> |

## Verdict

> Not "done" unless every contract item has a `pass` or an explicit
> `manual-unverified` line with a reason. On the bugfix track, a fix without a
> regression test (RED→GREEN evidence) is **incomplete**, not done.
