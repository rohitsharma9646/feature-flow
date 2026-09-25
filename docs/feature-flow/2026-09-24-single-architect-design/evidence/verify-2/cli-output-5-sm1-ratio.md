# cli-output-5-sm1-ratio.md

kind: cli-output
date: 2026-09-25

## SM1 baseline run 2 (paid) — v0.23.0 (three architects)

command:
```
FF_FORWARD_PLUGIN_DIR=/tmp/claude-1000/-home-netzwelt-feature-flow/45b08c56-16a9-4bf3-9eb2-ce2dc11d8741/scratchpad/ff-v0230 \
  bash scripts/forward-test.sh --max-budget-usd 5.00 \
  --output-dir /home/netzwelt/feature-flow/.feature-flow/single-architect-design/evidence/forward-v023 \
  single-architect
```
(tracked script — its sandbox-delete behavior is fine here since we do not need architect.md from
this run)

Confirmed plugin dir version before running:
```
$ jq -r .version /tmp/claude-1000/-home-netzwelt-feature-flow/45b08c56-16a9-4bf3-9eb2-ce2dc11d8741/scratchpad/ff-v0230/.claude-plugin/plugin.json
0.23.0
```

exit status of `scripts/forward-test.sh`: 1 (expected — the script exits 1 on any arm FAIL; both
arms FAIL here because the fixtures target the v0.24.0 single-architect report shape and v0.23.0
predates it. Per the dispatch: "its arms' assertions are expected to fail and are irrelevant —
only cost and duration matter.")

console output (verbatim):
```
  single-architect/fired run 1/1: FAIL — assertion failed (see assert-1.log) ($0.4601265)
FAIL single-architect/fired  ($0.4601)  — assertion failed (see assert-1.log)
  single-architect/control run 1/1: FAIL — assertion failed (see assert-1.log) ($0.4070261)
FAIL single-architect/control  ($0.407)  — assertion failed (see assert-1.log)
forward-test: 0/2 PASS, 2 FAIL, 0 ERROR · total $0.8671 · /home/netzwelt/feature-flow/.feature-flow/single-architect-design/evidence/forward-v023
```

summary.md:
```
# Forward-test run

**Date (UTC):** 2026-09-25T05:44:54Z
**Plugin:** `/tmp/claude-1000/-home-netzwelt-feature-flow/45b08c56-16a9-4bf3-9eb2-ce2dc11d8741/scratchpad/ff-v0230` @ e95c4de (+ uncommitted changes)
**Repeat:** 1 · **Budget/run:** $5.00 · **Timeout/run:** 900s

| Behavior | Arm | Result | Cost | Note |
|---|---|---|---|---|
| single-architect | fired | FAIL | $0.4601 | assertion failed (see assert-1.log) |
| single-architect | control | FAIL | $0.407 | assertion failed (see assert-1.log) |

**Summary:** 0/2 PASS, 2 FAIL, 0 ERROR · total $0.8671
```

The `@ e95c4de` commit matches the v0.23.0 merge commit (`e95c4de Merge branch
'feature/implement-controller': v0.23.0 ff-implement...`), confirming this is the correct baseline
plugin snapshot.

Artifacts: `forward-v023/summary.md`, `forward-v023/single-architect/fired/run-1.json`,
`assert-1.log`, `changes-1.txt`, `run-1.err`; same for `control/`.

## Baseline run 1 (reused, from a prior verify pass — not re-run here)

`evidence/verify-1/forward-v023/single-architect/fired/run-1.json` — `total_cost_usd=0.40267`,
`duration_ms=63518`, `duration_api_ms=102058`, `num_turns=8`.

## SM1 ratio script — all 4 combinations (new fired run × baseline fired run)

command (each): `bash evals/forward/single-architect/sm1-ratio.sh <new run.json> <old run.json>`

```
$ bash evals/forward/single-architect/sm1-ratio.sh forward-new/.../fired/run-1.json verify-1/forward-v023/.../fired/run-1.json
SM1 v0.24.0=0.3770788 v0.23.0=0.40267 ratio=0.936 FAIL (<= 0.60)
exit=1

$ bash evals/forward/single-architect/sm1-ratio.sh forward-new/.../fired/run-1.json forward-v023/.../fired/run-1.json
SM1 v0.24.0=0.3770788 v0.23.0=0.4601265 ratio=0.820 FAIL (<= 0.60)
exit=1

$ bash evals/forward/single-architect/sm1-ratio.sh forward-new/.../fired/run-2.json verify-1/forward-v023/.../fired/run-1.json
SM1 v0.24.0=0.33431040000000006 v0.23.0=0.40267 ratio=0.830 FAIL (<= 0.60)
exit=1

$ bash evals/forward/single-architect/sm1-ratio.sh forward-new/.../fired/run-2.json forward-v023/.../fired/run-1.json
SM1 v0.24.0=0.33431040000000006 v0.23.0=0.4601265 ratio=0.727 FAIL (<= 0.60)
exit=1
```

All 4 pairwise SM1 ratios are FAIL against the script's own <= 0.60 threshold (`sm1-ratio.sh` is
"a measurement, run by hand — not an assertion" per its own header comment). Ratios range 0.727–0.936.

## Mean ratios (mean of the 2 new fired runs / mean of the 2 baseline fired runs)

Per-run `total_cost_usd` (fired arm only):
- new (v0.24.0, single architect): run-1=0.3770788, run-2=0.33431040000000006 → mean=0.3556946
- baseline (v0.23.0, three architects): run-1 (verify-1)=0.40267, run-2 (this run)=0.4601265 → mean=0.43139825

**Cost ratio (mean new / mean old) = 0.3556946 / 0.43139825 = 0.8245**

Per-run `duration_ms` (fired arm only, as reported in each run.json's top-level `duration_ms` field):
- new: run-1=82426, run-2=92021 → mean=87223.5
- baseline: run-1=63518, run-2=11686 → mean=37602.0

**duration_ms ratio (mean new / mean old) = 87223.5 / 37602.0 = 2.3197**

Note on `duration_ms` anomaly (reported as-is, not interpreted): baseline run-2's `duration_ms`
(11686 ms) is far smaller than its own `duration_api_ms` (116503 ms) and than baseline run-1's
`duration_ms` (63518 ms), despite baseline run-2 costing more ($0.4601 vs $0.40267) and having a
higher `duration_api_ms`. Baseline run-2 also reports `num_turns=1` vs baseline run-1's
`num_turns=8`. This is consistent with v0.23.0's architecture (three architects fanned out as
parallel subagents) where the top-level session's own `duration_ms` may not include subagent wall
time, while `duration_api_ms` accumulates it. Because of this, the `duration_ms` mean ratio above
(2.3197, appearing WORSE for the new single-architect version) is likely not comparable
apples-to-apples across the architecture change. For completeness, the same computation using
`duration_api_ms` instead:

- new: run-1=82132, run-2=91667 → mean=86899.5
- baseline: run-1=102058, run-2=116503 → mean=109280.5
- **duration_api_ms ratio (mean new / mean old) = 86899.5 / 109280.5 = 0.7952**

## Total money spent in this verify pass

| Item | Spend |
|---|---|
| Item 4 — forward-new (single-architect, v0.24.0, 2 repeats × 2 arms) | $1.3115 |
| Item 5 — forward-v023 (single-architect, v0.23.0 baseline run 2, 1 repeat × 2 arms) | $0.8671 |
| **Total (this verify pass, items 4+5)** | **$2.1786** |

(Baseline run 1, reused from a prior verify pass, is not counted as new spend here.)
