# E2E (paid): single-architect forward test

Command:
```
FF_FORWARD_KEEP=1 scripts/forward-test.sh --repeat 2 --max-budget-usd 3.00 \
  --output-dir .feature-flow/single-architect-design/evidence/verify-5/forward-new single-architect
```
Exit: 0
Runner summary line: `forward-test: 2/2 PASS, 0 FAIL, 0 ERROR · total $1.3957 · .feature-flow/single-architect-design/evidence/verify-5/forward-new`

Runner's own summary.md (`forward-new/summary.md`):
```
| Behavior | Arm | Result | Cost | Note |
|---|---|---|---|---|
| single-architect | fired | PASS | $0.8253 |  |
| single-architect | control | PASS | $0.5704 |  |
```

Both arms PASS x2 runs each, as expected (fired PASS x2, control PASS x2).

## Per-run table

| Arm | Run | Result | total_cost_usd | wall (s) | architect.md word count | Rejected/Dropped lines | 'one obvious approach' |
|---|---|---|---|---|---|---|---|
| fired | 1 | PASS | 0.4027399 | 131 | 565 | 2 Rejected, 0 Dropped | none |
| fired | 2 | PASS | 0.4226295 | 135 | 619 | 2 Rejected, 0 Dropped | none |
| control | 1 | PASS | 0.2637218 | 50 | 399 | 0 Rejected, 0 Dropped | 1 line present |
| control | 2 | PASS | 0.30668090000000003 | 53 | 510 | 0 Rejected, 0 Dropped | 1 line present |

Fired total: $0.8253649 (runner-rounded: $0.8253). Control total: $0.5704027 (runner-rounded: $0.5704). Combined: $1.3957676 (runner: $1.3957).

## Per-run assert logs (full)

### fired/assert-1.log
```
  ok:   architect.md written (/tmp/ff-forward-RwRp0z/.feature-flow/rate-limit/architect.md)
  ok:   Recommended: line
  ok:   2 Rejected: line(s)
  ok:   every Rejected: line carries the three scores
  ok:   no Rejected: line loses to the spec
  ok:   no 'one obvious approach' in the fired arm
  ok:   no source written
```

### fired/assert-2.log
```
  ok:   architect.md written (/tmp/ff-forward-0onjxQ/.feature-flow/rate-limit/architect.md)
  ok:   Recommended: line
  ok:   2 Rejected: line(s)
  ok:   every Rejected: line carries the three scores
  ok:   no Rejected: line loses to the spec
  ok:   no 'one obvious approach' in the fired arm
  ok:   no source written
```

### control/assert-1.log
```
  ok:   architect.md written (/tmp/ff-forward-nP0055/.feature-flow/version-flag/architect.md)
  ok:   Recommended: line
  ok:   control arm says one obvious approach
  ok:   no Rejected: line
  ok:   no source written
```

### control/assert-2.log
```
  ok:   architect.md written (/tmp/ff-forward-ht38UM/.feature-flow/version-flag/architect.md)
  ok:   Recommended: line
  ok:   control arm says one obvious approach
  ok:   no Rejected: line
  ok:   no source written
```

## Architect.md `^Rejected:` / `^Dropped` / 'one obvious approach' lines, per run

### fired run-1 (`forward-new/single-architect/fired/run-1.feature-flow/rate-limit/architect.md`)
```
Recommended: lock-free per-caller marker-directory (insert-then-count)
Rejected: flock-based single lock file per caller — flock is an extra external binary, not guaranteed present everywhere, and adds fd-management code the marker-directory approach avoids entirely — complexity: low, risk: med, test effort: low
Rejected: single global state file for all callers under one lock — serializes unrelated callers on one lock, adding contention that per-caller marker directories avoid, while giving no benefit over per-caller storage — complexity: low, risk: med, test effort: low
```
No `^Dropped` line. No 'one obvious approach' line (expected — fired arm).

### fired run-2 (`forward-new/single-architect/fired/run-2.feature-flow/rate-limit/architect.md`)
```
Recommended: mkdir-lock + per-caller timestamp-log file under a state directory
Rejected: single global lock (one `flock`/mkdir mutex shared by all callers, guarding one counter-per-caller table file) — mechanically similar locking idea but serializes every caller's request behind one lock instead of letting independent caller-ids proceed in parallel, adding contention with no benefit over per-caller locks — complexity: low, risk: low, test effort: low
Rejected: atomic per-request marker files (empty file per request, named by timestamp+pid, under a per-caller directory, no mutex at all) — relies on atomic file creation instead of locking, but every call must list/stat a growing set of small files, inode usage climbs unboundedly under bursty callers, and two creations racing at the exact threshold can over-deny — complexity: med, risk: med, test effort: med
```
No `^Dropped` line. No 'one obvious approach' line (expected — fired arm).

### control run-1 (`forward-new/single-architect/control/run-1.feature-flow/version-flag/architect.md`)
```
Recommended: inline --version case branch reading VERSION relative to script location
```
No `^Rejected` / `^Dropped` lines. 'one obvious approach' line present (line 33):
```
one obvious approach — spec states no alternatives worth weighing, and the only structural choice (resolving VERSION via script directory vs. cwd) is a detail folded into the design above, not a competing architecture.
```

### control run-2 (`forward-new/single-architect/control/run-2.feature-flow/version-flag/architect.md`)
```
Recommended: inline --version branch in cli.sh's existing dispatch, reading VERSION via script-relative path
```
No `^Rejected` / `^Dropped` lines. 'one obvious approach' line present (line 58):
```
one obvious approach — spec names the only approach ("read VERSION and print it... no alternatives worth weighing") and the repo is four files with no structure to choose between.
```

## Evidence paths
- `forward-new/summary.md`
- `forward-new/single-architect/fired/{run-1,run-2}.json`, `{run-1,run-2}.wall`, `assert-{1,2}.log`, `changes-{1,2}.txt`, `run-{1,2}.err`
- `forward-new/single-architect/fired/run-{1,2}.feature-flow/rate-limit/architect.md`
- `forward-new/single-architect/control/{run-1,run-2}.json`, `{run-1,run-2}.wall`, `assert-{1,2}.log`, `changes-{1,2}.txt`, `run-{1,2}.err`
- `forward-new/single-architect/control/run-{1,2}.feature-flow/version-flag/architect.md`
