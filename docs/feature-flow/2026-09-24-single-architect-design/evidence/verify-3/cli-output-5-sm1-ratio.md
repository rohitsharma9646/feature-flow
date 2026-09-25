# cli-output-5-sm1-ratio.md

kind: cli-output
date: 2026-09-25 (third pass)

## SM1 baseline forward-test (v0.23.0 plugin dir)

command: `FF_FORWARD_PLUGIN_DIR=/tmp/claude-1000/-home-netzwelt-feature-flow/45b08c56-16a9-4bf3-9eb2-ce2dc11d8741/scratchpad/ff-v0230 scripts/forward-test.sh --repeat 2 --max-budget-usd 5.00 --output-dir <evidence>/forward-v023 single-architect`
exit status: 1 (FAIL both arms — expected/irrelevant per dispatch instructions; only cost/wall are used)

Confirmed the baseline dir's plugin.json version:
```
$ grep -h version /tmp/.../ff-v0230/.claude-plugin/plugin.json
  "version": "0.23.0",
```

Full runner output:
```
  single-architect/fired run 1/2: FAIL — assertion failed (see assert-1.log) ($0.48974550000000006)
  single-architect/fired run 2/2: FAIL — assertion failed (see assert-2.log) ($0.45219850000000006)
FAIL single-architect/fired  ($0.9419)  — assertion failed (see assert-2.log)
  single-architect/control run 1/2: FAIL — assertion failed (see assert-1.log) ($0.3851837)
  single-architect/control run 2/2: FAIL — assertion failed (see assert-2.log) ($0.4099678)
FAIL single-architect/control  ($0.7952)  — assertion failed (see assert-2.log)
forward-test: 0/2 PASS, 2 FAIL, 0 ERROR · total $1.7371 · /home/netzwelt/feature-flow/.feature-flow/single-architect-design/evidence/verify-3/forward-v023
EXIT_CODE=1
```

## sm1-ratio.sh

command: `bash evals/forward/single-architect/sm1-ratio.sh <evidence>/forward-new/single-architect/fired <evidence>/forward-v023/single-architect/fired` (from /home/netzwelt/feature-flow)
exit status: 1 (FAIL)

Full output:
```
SM1 cost v0.24.0=$0.3388 (n=2) v0.23.0=$0.4710 (n=2) ratio=0.719 (<= 0.90)
SM1 wall v0.24.0=96.0000s v0.23.0=69.5000s ratio=1.381 (<= 1.10)
SM1 FAIL
EXIT_CODE=1
```

**Result: SM1 FAIL.** Cost ratio 0.719 <= 0.90 threshold (PASS on cost — v0.24.0's single-architect
flow IS cheaper than v0.23.0's three-architect flow), but wall-clock ratio 1.381 > 1.10 threshold
(FAIL on wall — v0.24.0 took longer in wall-clock time across these 2 fired runs vs the 2 v0.23.0
fired runs: 96.0s mean vs 69.5s mean). sm1-ratio.sh requires BOTH thresholds to pass; since wall
failed, the overall verdict is FAIL. Reported as observed evidence only — not interpreted further.

Underlying per-run numbers (n=2 each side):
- v0.24.0 fired: run-1 $0.3806671 / 113s, run-2 $0.29685009999999995 / 79s -> mean $0.3388 / 96.0s
- v0.23.0 fired: run-1 $0.48974550000000006 / 75s, run-2 $0.45219850000000006 / 64s -> mean $0.4710 / 69.5s
