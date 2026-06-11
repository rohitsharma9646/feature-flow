# Diagnosis: <bug title>

**Created:** <date>
**Track:** bugfix
**Tier:** lite | full
**Status:** draft | confirmed | signed-off

## Bug report

<The reported symptom, verbatim where possible: what the user did, what happened, what
they expected. Include error text / stack trace / failing input.>

## Reproduction

Pick ONE:

- **Reproduced:** exact steps / inputs that trigger it, and the observed failure.
  - Step 1 …
  - Step 2 …
  - Observed: <the failure, with real output / error / stack>
- **NOT reproduced:** what was tried and what is still needed to reproduce.
  - Tried: …
  - Need from user: <specific missing detail — env, version, exact input, repro repo>

> A bug that is **not reproduced does not proceed to a fix.** Record "not reproduced",
> ask for the missing detail, and STOP. Guessing a fix for an unconfirmed bug is forbidden.

## Root cause

<The underlying defect — not the symptom — with `file:line` evidence and the failing
path traced from trigger to fault. Explain *why* this code produces the observed behavior.>

## Fix approach (hotfix-vs-proper — required)

Name **both** options, then recommend. (Solution-horizon framing — required even when the
recommendation is "proper fix only".)

- **Hotfix / band-aid:** <smallest change that stops the symptom today> — Cost / risk if it
  calcifies: <…>
- **Root-cause / proper:** <the fix that removes the underlying defect> — Cost / why it's
  right: <…>
- **Recommendation:** <which, and why> — default to the proper fix unless a stated reason
  (incident pressure, explicit "quick fix" request, documented out-of-scope) makes the
  hotfix right. If a hotfix is chosen, the proper fix is recorded as a follow-up below.

## Fix surface

- Files / functions the fix must touch: `<path:symbol>` …
- Follow-up (if a hotfix was chosen): <what the proper fix would be — so the band-aid
  doesn't calcify>.

## Regression-test plan

<The test that will be written **test-first**: it must fail against the current (pre-fix)
code and pass after the fix. Name the test file/path and the assertion that pins the bug.>

## Sign-off

**User signed off:** no | yes (<date>) | n/a (lite)

> **Tier gate.** On the **full** tier (non-trivial bug) this must read `yes (<date>)` before
> `/ff-implement` writes a fix — same gate as a feature `spec.md`. On the **lite** tier
> (trivial/obvious bug) this reads `n/a (lite)`: a *confirmed* diagnosis (reproduced + root
> cause + chosen approach) is itself the gate; no separate sign-off is required.
