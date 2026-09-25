# e2e-2-ac5-pick-decline.md

kind: e2e/browser (forward-test — real, paid, headless Claude Code sessions, two-turn via followup.txt)
command: `FF_FORWARD_KEEP=1 scripts/forward-test.sh --max-budget-usd 3.00 --output-dir <evidence>/forward-ac5 architect-pick architect-decline` (from /home/netzwelt/feature-flow)
exit status: 1 (FAIL — architect-pick/fired failed; the other 3 arms PASS)
date: 2026-09-25 (third pass)
artifact dir: /home/netzwelt/feature-flow/.feature-flow/single-architect-design/evidence/verify-3/forward-ac5

## Overall runner output

```
  architect-pick/fired run 1/1: FAIL — assertion failed (see assert-1.log) ($0.6257)
FAIL architect-pick/fired  ($0.6257)  — assertion failed (see assert-1.log)
  architect-pick/control run 1/1: PASS ($0.8343)
PASS architect-pick/control  ($0.8343)
  architect-decline/fired run 1/1: PASS ($0.7435)
PASS architect-decline/fired  ($0.7435)
  architect-decline/control run 1/1: PASS ($0.7123)
PASS architect-decline/control  ($0.7123)
forward-test: 3/4 PASS, 1 FAIL, 0 ERROR · total $2.9158 · /home/netzwelt/feature-flow/.feature-flow/single-architect-design/evidence/verify-3/forward-ac5
EXIT_CODE=1
```

**Expected: all four arms PASS. Actual: 3/4 PASS, architect-pick/fired FAIL.**

## Per-arm table (turn 1 + turn 2 summed)

| Behavior | Arm | Result | Turn-1 cost | Turn-2 cost | Summed cost | Wall (s, both turns) |
|---|---|---|---|---|---|---|
| architect-pick | fired | FAIL | $0.29700009999999993 | $0.32869389999999993 | $0.6257 | 99 |
| architect-pick | control | PASS | $0.29114760000000006 | $0.5431644 | $0.8343 | 153 |
| architect-decline | fired | PASS | $0.24724010000000002 | $0.49625739999999996 | $0.7435 | 190 |
| architect-decline | control | PASS | $0.2487415 | $0.4635263 | $0.7123 | 97 |

Sum for this item: $2.9158 (matches runner total).

## architect-pick/fired — assertion failure

```
  ok:   architect.md written
  ok:   Recommended: Per-caller sliding-window log file, guarded by an mkdir-based spinlock
  ok:   first Rejected: fixed-window counter (single `window_start,count` field per caller instead of a
  FAIL: 0 '## Developed on request:' sections (want 1)
  ok:   first report kept on top
  FAIL: no design.md after the pick
  ok:   no source written
```

Fails two checks: no `## Developed on request:` section (want 1) and no `design.md` after the pick.

### What happened (observed, not fixed): the architect declined the pick as a spec conflict, and asked a clarifying question instead of completing the AC5 re-dispatch flow

The followup turn's result text (`run-1.followup.json`, `.result`), verbatim:
```
I haven't started on the fixed-window counter yet, because it conflicts with your signed-off spec.

The spec's Problem section asks to reject requests once a caller exceeds the limit "within a **rolling** window." A fixed-window counter resets at set times, so it isn't a rolling window. For example, with the defaults (5 requests per 10 seconds), a caller could make 5 calls at second 9.9 and 5 more at second 10.1. That's 10 requests in under a second, and the design would still print `ok` for all of them.

Design can only decide *how* to build what the spec says. If I built this anyway, the spec would require one thing and the design would do another, and the verify phase would be checking against a requirement the build ignores. There are two ways to resolve it:

1. **Change the spec, then design the fixed-window counter.** Run `/feature-flow:ff-clarify rate-limit` to replace "rolling window" with "fixed window" and accept the burst at window boundaries, then sign the spec off again. Then re-run `/feature-flow:ff-design rate-limit`. The architect's current report stays on disk, so I'll go straight to developing the fixed-window design.
2. **Keep the rolling window.** Pick the recommended per-caller log file, or the shared-lock option (which is also a rolling window). I'll finish the design phase right away.

Which do you want? If option 1, is the burst at window boundaries acceptable to you?

`rate-limit` · explore ✓ · clarify ✓ · **design ⏸ (fixed-window pick conflicts with spec)** · plan · implement · review · verify
```

The user's followup instruction was to pick the *first rejected* option; in this run that option was
the 'fixed-window counter', which the sandbox's spec explicitly rules out (spec requires a **rolling**
window). Rather than silently re-dispatching the architect to develop a spec-contradicting option, the
session stopped and asked the user to choose between amending the spec (via ff-clarify) or picking a
different (rolling-window) alternative. No `## Developed on request:` section was appended and no
design.md was written, because design never proceeded past this clarifying question — hence both
assert.sh checks fail. This is reported as observed evidence only; not interpreted or fixed here.

## architect-pick/control — PASS
```
  ok:   architect.md written
  ok:   Recommended: File-backed sliding-window log with mkdir-based mutex
  ok:   no re-dispatch
  ok:   design.md written
  ok:   Chosen approach names the recommendation
  ok:   no source written
```

## architect-decline/fired — PASS
```
  ok:   architect.md written
  ok:   first report: one obvious approach
  ok:   exactly one '## Developed on request:' section after the decline
  ok:   first report kept on top
  ok:   no source written
```

## architect-decline/control — PASS
```
  ok:   architect.md written
  ok:   one obvious approach
  ok:   no re-dispatch
  ok:   design.md written
  ok:   no source written
```

## Kept run-1.feature-flow artifact paths (FF_FORWARD_KEEP=1)

```
/home/netzwelt/feature-flow/.feature-flow/single-architect-design/evidence/verify-3/forward-ac5/architect-decline/control/run-1.feature-flow/version-flag/architect.md
/home/netzwelt/feature-flow/.feature-flow/single-architect-design/evidence/verify-3/forward-ac5/architect-decline/control/run-1.feature-flow/version-flag/design.md
/home/netzwelt/feature-flow/.feature-flow/single-architect-design/evidence/verify-3/forward-ac5/architect-decline/fired/run-1.feature-flow/version-flag/architect.md
/home/netzwelt/feature-flow/.feature-flow/single-architect-design/evidence/verify-3/forward-ac5/architect-pick/control/run-1.feature-flow/rate-limit/architect.md
/home/netzwelt/feature-flow/.feature-flow/single-architect-design/evidence/verify-3/forward-ac5/architect-pick/control/run-1.feature-flow/rate-limit/design.md
/home/netzwelt/feature-flow/.feature-flow/single-architect-design/evidence/verify-3/forward-ac5/architect-pick/fired/run-1.feature-flow/rate-limit/architect.md
```

Note: architect-pick/fired's run-1.feature-flow has no design.md (confirms the assert failure above —
design never completed after the followup turn's clarifying question). architect-decline/fired's
run-1.feature-flow also has no design.md, but that arm's assert.sh does not check for one (only checks
the architect.md '## Developed on request:' section), so this is expected, not a gap.
