# SM1 baseline (paid) — v0.24.0 single-architect vs v0.23.0 three-architect fan-out — 2026-09-25T05:05:09Z

v0.23.0 plugin dir: /tmp/claude-1000/-home-netzwelt-feature-flow/45b08c56-16a9-4bf3-9eb2-ce2dc11d8741/scratchpad/ff-v0230
(version confirmed 0.23.0 via jq -r .version .claude-plugin/plugin.json; config/defaults.json contains 'architectAgents' — three-architect fan-out.)

## command: FF_FORWARD_PLUGIN_DIR=<v0.23.0 dir> scripts/forward-test.sh --max-budget-usd 5.00 --output-dir .feature-flow/single-architect-design/evidence/forward-v023 single-architect
Note: forward-test.sh has no per-arm selection flag, so both arms ran (as the task instructions anticipated).
# Forward-test run

**Date (UTC):** 2026-09-25T05:04:30Z
**Plugin:** `/tmp/claude-1000/-home-netzwelt-feature-flow/45b08c56-16a9-4bf3-9eb2-ce2dc11d8741/scratchpad/ff-v0230` @ e95c4de (+ uncommitted changes)
**Repeat:** 1 · **Budget/run:** $5.00 · **Timeout/run:** 900s

| Behavior | Arm | Result | Cost | Note |
|---|---|---|---|---|
| single-architect | fired | FAIL | $0.4027 | assertion failed (see assert-1.log) |
| single-architect | control | FAIL | $0.3754 | assertion failed (see assert-1.log) |

**Summary:** 0/2 PASS, 2 FAIL, 0 ERROR · total $0.7781

### fired arm assert-1.log (against v0.23.0 — FAIL expected/irrelevant, only cost matters)
  FAIL: no architect.md

### control arm assert-1.log (against v0.23.0 — FAIL expected/irrelevant, only cost matters)
  FAIL: no architect.md

## Per-arm total_cost_usd (from run-1.json)
- v0.24.0 (new) fired:   $0.5952392999999999
- v0.24.0 (new) control: $0.4645637
- v0.23.0 (old) fired:   $0.40267
- v0.23.0 (old) control: $0.37544900000000003

## command: bash evals/forward/single-architect/sm1-ratio.sh <v0.24.0 fired run.json> <v0.23.0 fired run.json>
SM1 v0.24.0=0.5952392999999999 v0.23.0=0.40267 ratio=1.478 FAIL (<= 0.60)
exit: 1
