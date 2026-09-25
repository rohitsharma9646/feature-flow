# E2E re-verify — single-architect forward test (scoped repair re-verify)

## Command

Ran via the untracked capture copy (identical to `scripts/forward-test.sh` except for one
added line: `find "$tmp" -name architect.md -exec cp {} "$arm_out/architect.md" \;`), confirmed
by `diff scripts/forward-test.sh <capture-copy>` showing only that one added line.

The capture copy was found at:
`/tmp/claude-1000/-home-netzwelt-feature-flow/26aa1176-a742-4f36-a57a-478450aeb348/scratchpad/forward-test-capture.sh`
(not present under the `45b08c56-...` session named in the dispatch; located by searching all
sessions' scratchpad dirs, per the dispatch's fallback instruction).

That session had also staged a `repo-mirror/` dir (`scripts/forward-test-capture.sh` +
`evals -> /home/netzwelt/feature-flow/evals` symlink) so the script's own
`REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"` resolves correctly when run from outside
`/home/netzwelt/feature-flow`. Command actually run:

```
FF_FORWARD_PLUGIN_DIR="/home/netzwelt/feature-flow" \
  /tmp/claude-1000/.../26aa1176.../scratchpad/repo-mirror/scripts/forward-test-capture.sh \
  --max-budget-usd 3.00 \
  --output-dir /home/netzwelt/feature-flow/.feature-flow/single-architect-design/evidence/forward-repair \
  single-architect
```

One process only; no nohup/disown; run via Bash tool (auto-moved to background by the harness
twice, at 120s and 600s, due to real Claude session latency — not a second invocation).

## Exit code

`1` (fired arm PASS, control arm FAIL — script exit is 1 whenever any arm is not PASS).

## Per-arm results

### fired — PASS

`evidence/forward-repair/single-architect/fired/assert-1.log`:
```
  ok:   architect.md written (/tmp/ff-forward-eNLjMj/.feature-flow/rate-limit/architect.md)
  ok:   Recommended: line
  ok:   3 Rejected: line(s)
  ok:   every Rejected: line carries the three scores
  ok:   no 'one obvious approach' in the fired arm
  ok:   no source written
```
run-1.json: `total_cost_usd=0.602462`, `num_turns=7`, `duration_ms=213169`, `is_error=false`, `subtype=success`.

### control — FAIL

`evidence/forward-repair/single-architect/control/assert-1.log`:
```
  ok:   architect.md written (/tmp/ff-forward-TWXxnO/.feature-flow/version-flag/architect.md)
  ok:   Recommended: line
  FAIL: no 'one obvious approach' line in the control arm
  FAIL: 3 Rejected: line(s) in the control arm
  ok:   no source written
```
run-1.json: `total_cost_usd=0.5004515`, `num_turns=7`, `duration_ms=125611`, `is_error=false`, `subtype=success`.

Control's `architect.md` contains a `Recommended:` line and 3 scored `Rejected:` lines, and does
not contain the `one obvious approach —` phrase — i.e. it does not match either of the two
expected-PASS shapes from the dispatch (fired shape: `Recommended:` + >=1 scored `Rejected:`;
control shape: `one obvious approach —`, no `Rejected:` line).

## Total cost

$1.103 (fired $0.6025 + control $0.5005), from `evidence/forward-repair/summary.md`.

## Evidence paths

- `.feature-flow/single-architect-design/evidence/forward-repair/summary.md`
- `.feature-flow/single-architect-design/evidence/forward-repair/single-architect/fired/{run-1.json,run-1.err,assert-1.log,changes-1.txt,architect.md}`
- `.feature-flow/single-architect-design/evidence/forward-repair/single-architect/control/{run-1.json,run-1.err,assert-1.log,changes-1.txt,architect.md}`
- This file: `.feature-flow/single-architect-design/evidence/e2e-2-repair-reverify.md`
