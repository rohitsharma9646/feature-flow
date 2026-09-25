#!/usr/bin/env bash
# Forward-test runner — proves feature-flow's SEMANTIC behaviors actually FIRE.
#
# Lives in scripts/ (NOT scripts/checks/, so the CI guard loop never runs it). LOCAL ONLY:
# every arm is a real, paid, headless Claude session, so it needs credentials and costs tokens.
# The structural half (every case has both arms and all parts) is pinned in CI by
# scripts/checks/forward-test-guard.sh; the firing half is only ever proven here.
#
# Each case is evals/forward/<behavior>/<arm>/ (arm = fired | control) holding:
#   sandbox/    planted repo root, copied into a fresh temp git repo per run
#   prompt.txt  the blind prompt (never states the expected outcome)
#   expected.md human-readable expected observable (not executed)
#   assert.sh   `assert.sh <tmpdir> <run.json>` — exit 0 behaved as expected, 1 did not,
#               anything else = ERROR
#   followup.txt  optional — the user's answer to a pause: the SAME session is resumed
#               (`--resume <session_id>`) with it as a second turn, and assert.sh then gets that
#               turn's run.json (`run-<i>.followup.json`); both turns' costs are summed
# Each run also leaves run-<i>.wall — its wall-clock seconds, both turns included — and, with
# FF_FORWARD_KEEP=1, run-<i>.feature-flow/ — a copy of the run's .feature-flow/ state.
# See evals/forward/README.md for the case shape.
#
# Each run is a FRESH process loading the WORKING-TREE plugin (--plugin-dir), which is the
# only way to prove an edited command fires — the session that wrote the edit cannot.
#
# Usage:
#   scripts/forward-test.sh [behavior...] [--repeat N] [--max-budget-usd X]
#                           [--timeout SECS] [--output-dir DIR] [--model M]
# Exit: 0 every selected arm PASS · 1 any FAIL/ERROR · 2 usage/precondition (nothing ran).
set -u
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CASES="$REPO_ROOT/evals/forward"

REPEAT=1
BUDGET="${FF_FORWARD_BUDGET_USD:-2.00}"
TIMEOUT=900
OUTPUT_DIR=""
MODEL=""
PLUGIN_DIR="${FF_FORWARD_PLUGIN_DIR:-$REPO_ROOT}"   # override only for mutation proofs
selected=()

usage() { sed -n '/^# Usage:/,/^# Exit:/p' "$0" | sed 's/^# \{0,1\}//' >&2; }
die2() { echo "forward-test: $1" >&2; exit 2; }

while [ $# -gt 0 ]; do
  case "$1" in
    --repeat)         [ $# -ge 2 ] || die2 "--repeat needs a value"; REPEAT="$2"; shift 2 ;;
    --max-budget-usd) [ $# -ge 2 ] || die2 "--max-budget-usd needs a value"; BUDGET="$2"; shift 2 ;;
    --timeout)        [ $# -ge 2 ] || die2 "--timeout needs a value"; TIMEOUT="$2"; shift 2 ;;
    --output-dir)     [ $# -ge 2 ] || die2 "--output-dir needs a value"; OUTPUT_DIR="$2"; shift 2 ;;
    --model)          [ $# -ge 2 ] || die2 "--model needs a value"; MODEL="$2"; shift 2 ;;
    -h|--help)        usage; exit 2 ;;
    --*)              usage; die2 "unknown option: $1" ;;
    *)                selected+=("$1"); shift ;;
  esac
done
case "$REPEAT" in ''|*[!0-9]*|0) die2 "--repeat must be a positive integer (got '$REPEAT')" ;; esac
case "$TIMEOUT" in ''|*[!0-9]*|0) die2 "--timeout must be a positive integer (got '$TIMEOUT')" ;; esac

# --- preconditions: nothing runs unless every one holds ---------------------------------
command -v claude >/dev/null 2>&1 || die2 "'claude' CLI not found on PATH — install Claude Code to run forward tests"
command -v python3 >/dev/null 2>&1 || die2 "python3 not found on PATH (needed to parse run JSON)"
command -v timeout >/dev/null 2>&1 || die2 "timeout (coreutils) not found on PATH"
[ -d "$CASES" ] || die2 "no cases directory at $CASES"

valid=()
for d in "$CASES"/*/; do
  [ -d "$d" ] || continue
  valid+=("$(basename "$d")")
done
[ ${#valid[@]} -gt 0 ] || die2 "no behaviors under $CASES"
if [ ${#selected[@]} -eq 0 ]; then
  selected=("${valid[@]}")
else
  for b in "${selected[@]}"; do
    found=0
    for v in "${valid[@]}"; do [ "$b" = "$v" ] && found=1; done
    [ $found -eq 1 ] || die2 "unknown behavior '$b' — valid: ${valid[*]}"
  done
fi

[ -n "$OUTPUT_DIR" ] || OUTPUT_DIR="$REPO_ROOT/.feature-flow/forward-test-runs/$(date -u +%Y%m%dT%H%M%SZ)"
mkdir -p "$OUTPUT_DIR" || die2 "cannot create output dir $OUTPUT_DIR"

# json_field <file> <key> — prints the top-level value, or nothing if unparseable
json_field() {
  python3 - "$1" "$2" <<'PY' 2>/dev/null
import json, sys
try:
    d = json.load(open(sys.argv[1]))
except Exception:
    sys.exit(3)
v = d.get(sys.argv[2])
print("" if v is None else (str(v).lower() if isinstance(v, bool) else v))
PY
}

model_args=()
[ -n "$MODEL" ] && model_args=(--model "$MODEL")

total_cost=0
n_pass=0; n_fail=0; n_err=0
summary_rows=()

for b in "${selected[@]}"; do
  for arm in fired control; do
    case_dir="$CASES/$b/$arm"
    arm_out="$OUTPUT_DIR/$b/$arm"
    mkdir -p "$arm_out"
    arm_result="PASS"; arm_cost=0; arm_note=""
    if [ ! -d "$case_dir/sandbox" ] || [ ! -f "$case_dir/prompt.txt" ] || [ ! -f "$case_dir/assert.sh" ]; then
      arm_result="ERROR"; arm_note="case incomplete (needs sandbox/, prompt.txt, assert.sh)"
    else
      for i in $(seq 1 "$REPEAT"); do
        tmp="$(mktemp -d "${TMPDIR:-/tmp}/ff-forward-XXXXXX")"
        cp -R "$case_dir/sandbox/." "$tmp/"
        # a fresh repo whose planted files are the committed baseline, so assert.sh can use
        # `git status` to see exactly what the session changed
        ( cd "$tmp" && git init -q && git -c user.name=ff -c user.email=ff@local add -A \
            && git -c user.name=ff -c user.email=ff@local commit -q -m baseline --allow-empty ) >/dev/null 2>&1
        run_json="$arm_out/run-$i.json"
        t_start=$(date +%s)
        ( cd "$tmp" && timeout "$TIMEOUT" claude -p \
            --plugin-dir "$PLUGIN_DIR" \
            --setting-sources project,local \
            --strict-mcp-config \
            --permission-mode bypassPermissions \
            --max-budget-usd "$BUDGET" \
            --output-format json \
            ${model_args[@]+"${model_args[@]}"} \
            "$(cat "$case_dir/prompt.txt")" ) >"$run_json" 2>"$arm_out/run-$i.err"
        rc=$?
        cost="$(json_field "$run_json" total_cost_usd)"; [ -n "$cost" ] || cost=0
        # optional second turn: answer the session's pause by resuming the same session
        sid="$(json_field "$run_json" session_id)"
        if [ $rc -eq 0 ] && [ -s "$case_dir/followup.txt" ] && [ -n "$sid" ]; then
          fu_json="$arm_out/run-$i.followup.json"
          ( cd "$tmp" && timeout "$TIMEOUT" claude -p \
              --resume "$sid" \
              --plugin-dir "$PLUGIN_DIR" \
              --setting-sources project,local \
              --strict-mcp-config \
              --permission-mode bypassPermissions \
              --max-budget-usd "$BUDGET" \
              --output-format json \
              ${model_args[@]+"${model_args[@]}"} \
              "$(cat "$case_dir/followup.txt")" ) >"$fu_json" 2>"$arm_out/run-$i.followup.err"
          rc=$?
          fcost="$(json_field "$fu_json" total_cost_usd)"; [ -n "$fcost" ] || fcost=0
          cost="$(python3 -c "print(round($cost + $fcost, 4))")"
          run_json="$fu_json"
        fi
        # wall-clock seconds for the whole run (both turns): duration_ms under-reports a session
        # whose subagents ran in the background, so SM1's wall-time ratio reads this instead
        echo $(( $(date +%s) - t_start )) >"$arm_out/run-$i.wall"
        arm_cost="$(python3 -c "print(round($arm_cost + $cost, 4))")"
        rep="PASS"; note=""
        if [ $rc -eq 124 ]; then
          rep="ERROR"; note="timeout after ${TIMEOUT}s"
        elif [ $rc -ne 0 ]; then
          rep="ERROR"; note="claude exited $rc"
        elif ! json_field "$run_json" type >/dev/null; then
          rep="ERROR"; note="unparseable run output"
        elif [ "$(json_field "$run_json" is_error)" = "true" ]; then
          rep="ERROR"; note="session error ($(json_field "$run_json" subtype))"
        else
          bash "$case_dir/assert.sh" "$tmp" "$run_json" >"$arm_out/assert-$i.log" 2>&1
          arc=$?
          if [ $arc -eq 0 ]; then rep="PASS"
          elif [ $arc -eq 1 ]; then rep="FAIL"; note="assertion failed (see assert-$i.log)"
          else rep="ERROR"; note="assert.sh crashed (exit $arc)"
          fi
        fi
        ( cd "$tmp" && git status --porcelain ) >"$arm_out/changes-$i.txt" 2>/dev/null
        # FF_FORWARD_KEEP=1 keeps the run's .feature-flow/ state (artifacts, manifest) as evidence
        if [ "${FF_FORWARD_KEEP:-0}" = 1 ] && [ -d "$tmp/.feature-flow" ]; then
          rm -rf "$arm_out/run-$i.feature-flow" && cp -R "$tmp/.feature-flow" "$arm_out/run-$i.feature-flow"
        fi
        rm -rf "$tmp"
        echo "  $b/$arm run $i/$REPEAT: $rep${note:+ — $note} (\$$cost)"
        # rollup: any ERROR -> ERROR; else any FAIL -> FAIL (flaky is not green)
        if [ "$rep" = "ERROR" ]; then arm_result="ERROR"; arm_note="$note"
        elif [ "$rep" = "FAIL" ] && [ "$arm_result" != "ERROR" ]; then arm_result="FAIL"; arm_note="$note"
        fi
      done
    fi
    total_cost="$(python3 -c "print(round($total_cost + $arm_cost, 4))")"
    case "$arm_result" in PASS) n_pass=$((n_pass+1)) ;; FAIL) n_fail=$((n_fail+1)) ;; *) n_err=$((n_err+1)) ;; esac
    echo "$arm_result $b/$arm  (\$$arm_cost)${arm_note:+  — $arm_note}"
    summary_rows+=("| $b | $arm | $arm_result | \$$arm_cost | ${arm_note:-} |")
  done
done

n_total=$((n_pass + n_fail + n_err))
{
  echo "# Forward-test run"
  echo
  echo "**Date (UTC):** $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "**Plugin:** \`$PLUGIN_DIR\` @ $(git -C "$REPO_ROOT" rev-parse --short HEAD 2>/dev/null || echo unknown)$(git -C "$REPO_ROOT" diff --quiet 2>/dev/null || echo ' (+ uncommitted changes)')"
  echo "**Repeat:** $REPEAT · **Budget/run:** \$$BUDGET · **Timeout/run:** ${TIMEOUT}s${MODEL:+ · **Model:** $MODEL}"
  echo
  echo "| Behavior | Arm | Result | Cost | Note |"
  echo "|---|---|---|---|---|"
  printf '%s\n' "${summary_rows[@]}"
  echo
  echo "**Summary:** $n_pass/$n_total PASS, $n_fail FAIL, $n_err ERROR · total \$$total_cost"
} >"$OUTPUT_DIR/summary.md"

echo "forward-test: $n_pass/$n_total PASS, $n_fail FAIL, $n_err ERROR · total \$$total_cost · $OUTPUT_DIR"
[ $n_fail -eq 0 ] && [ $n_err -eq 0 ]
