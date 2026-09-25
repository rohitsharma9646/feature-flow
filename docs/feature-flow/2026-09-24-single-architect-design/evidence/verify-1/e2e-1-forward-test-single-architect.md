# E2E forward-test (paid, headless claude sessions) — 2026-09-25T05:04:59Z

## Preflight: scripts/forward-test.sh --help
Usage:
  scripts/forward-test.sh [behavior...] [--repeat N] [--max-budget-usd X]
                          [--timeout SECS] [--output-dir DIR] [--model M]
Exit: 0 every selected arm PASS · 1 any FAIL/ERROR · 2 usage/precondition (nothing ran).

## Incident: stray background process race (self-corrected)
A first attempt used 'nohup ... & disown' inside a run_in_background Bash call;
the Bash tool's process-group teardown did not actually stop the detached child (PID 79848),
so a second, independent forward-test.sh invocation was launched into the SAME --output-dir
and raced with the still-running first one, corrupting run-1.json/assert-1.log for one cycle.
The stray process tree (79848, 94753, 94755) was found via 'ps aux' and killed with 'kill -9';
the contaminated output dir was deleted and the test re-run once, cleanly, with a single process.
All results below are from the clean, uncontaminated re-run.

## command: bash scripts/forward-test.sh --max-budget-usd 3.00 --output-dir .feature-flow/single-architect-design/evidence/forward-new single-architect
# Forward-test run

**Date (UTC):** 2026-09-25T04:50:35Z
**Plugin:** `/home/netzwelt/feature-flow` @ e95c4de (+ uncommitted changes)
**Repeat:** 1 · **Budget/run:** $3.00 · **Timeout/run:** 900s

| Behavior | Arm | Result | Cost | Note |
|---|---|---|---|---|
| single-architect | fired | PASS | $0.5952 |  |
| single-architect | control | FAIL | $0.4646 | assertion failed (see assert-1.log) |

**Summary:** 1/2 PASS, 1 FAIL, 0 ERROR · total $1.0598

### fired arm assert-1.log (exit maps to PASS)
  ok:   architect.md written (/tmp/ff-forward-xgvgYs/.feature-flow/rate-limit/architect.md)
  ok:   Recommended: line
  ok:   3 Rejected: line(s)
  ok:   every Rejected: line carries the three scores
  ok:   no 'one obvious approach' in the fired arm
  ok:   no source written

### control arm assert-1.log (exit maps to FAIL)
  ok:   architect.md written (/tmp/ff-forward-X7qEBa/.feature-flow/version-flag/architect.md)
  ok:   Recommended: line
  FAIL: no 'one obvious approach' line in the control arm
  FAIL: 3 Rejected: line(s) in the control arm
  ok:   no source written

## Note on architect.md capture
forward-test.sh deletes its per-run tmp sandbox (rm -rf "$tmp") right after asserting, so
architect.md does not survive the official run. To capture it as evidence without editing the
tracked script, an UNTRACKED copy (scripts/forward-test.sh with one inserted 'cp' line before the
rm -rf) was made in the session scratchpad and run a second time, same behaviors/budget/plugin-dir,
producing forward-new-capture/. Both runs agree: fired PASS, control FAIL, same assertion failures.
architect.md for each arm is at forward-new/single-architect/<arm>/architect.md (copied from the
capture run) and forward-new-capture/single-architect/<arm>/architect.md (original capture output).

### capture-run summary (second paid run, for architect.md capture only)
# Forward-test run

**Date (UTC):** 2026-09-25T05:02:06Z
**Plugin:** `/home/netzwelt/feature-flow` @ unknown (+ uncommitted changes)
**Repeat:** 1 · **Budget/run:** $3.00 · **Timeout/run:** 900s

| Behavior | Arm | Result | Cost | Note |
|---|---|---|---|---|
| single-architect | fired | PASS | $0.5722 |  |
| single-architect | control | FAIL | $0.496 | assertion failed (see assert-1.log) |

**Summary:** 1/2 PASS, 1 FAIL, 0 ERROR · total $1.0682
