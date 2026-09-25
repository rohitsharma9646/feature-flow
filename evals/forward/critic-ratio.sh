#!/usr/bin/env bash
# SM1/SM2 (v0.25.0): the control arm's cost and wall time vs the same arm run against v0.24.0 (no
# Critic). Baseline: git worktree add <dir> 488bc5d, then
# FF_FORWARD_PLUGIN_DIR=<dir> scripts/forward-test.sh --repeat 2 --output-dir <out> critic-design critic-plan
#   bash evals/forward/critic-ratio.sh <new control arm dir> <old control arm dir>
# Cost is run-<i>.json's total_cost_usd; wall time is run-<i>.wall (seconds, written by the runner).
# Cost per run = run-<i>.json + run-<i>.followup.json (two-turn arms); wall = run-<i>.wall (both turns).
# A measurement, run by hand — not an assertion. PASS when cost ratio <= 1.35 and wall delta <= 90s.
set -u
[ $# -eq 2 ] && [ -d "$1" ] && [ -d "$2" ] || { echo "usage: critic-ratio.sh <new control arm dir> <old control arm dir>" >&2; exit 2; }
mean() { # mean <dir> cost|wall
  local f v fu fv sum=0 n=0
  for f in "$1"/run-[0-9]*.json; do
    case "$f" in *.followup.json) continue ;; esac
    if [ "$2" = cost ]; then
      v="$(jq -r '.total_cost_usd // empty' "$f")"
      fu="${f%.json}.followup.json"
      if [ -f "$fu" ]; then
        fv="$(jq -r '.total_cost_usd // empty' "$fu")"
        [ -n "$fv" ] && v="$(awk -v a="${v:-0}" -v b="$fv" 'BEGIN { print a + b }')"
      fi
    else
      v="$(cat "${f%.json}.wall" 2>/dev/null)"
    fi
    [ -n "$v" ] || continue
    sum="$(awk -v a="$sum" -v b="$v" 'BEGIN { print a + b }')"; n=$((n + 1))
  done
  [ "$n" -gt 0 ] && awk -v s="$sum" -v n="$n" 'BEGIN { printf "%.4f %d", s / n, n }'
}
read -r nc nn <<<"$(mean "$1" cost)"; read -r oc on <<<"$(mean "$2" cost)"
read -r nw _ <<<"$(mean "$1" wall)"; read -r ow _ <<<"$(mean "$2" wall)"
[ -n "${nc:-}" ] && [ -n "${oc:-}" ] || { echo "no total_cost_usd in one of the arm dirs" >&2; exit 2; }
[ -n "${nw:-}" ] && [ -n "${ow:-}" ] || { echo "no run-<i>.wall in one of the arm dirs (older runner?)" >&2; exit 2; }
cr="$(awk -v n="$nc" -v o="$oc" 'BEGIN { printf "%.3f", n / o }')"
delta="$(awk -v n="$nw" -v o="$ow" 'BEGIN { printf "%.1f", n - o }')"
cost_ok="$(awk -v c="$cr" 'BEGIN { print (c <= 1.35 ? 1 : 0) }')"
wall_ok="$(awk -v d="$delta" 'BEGIN { print (d <= 90 ? 1 : 0) }')"
verdict="$([ "$cost_ok" = 1 ] && [ "$wall_ok" = 1 ] && echo PASS || echo FAIL)"
echo "cost new=\$$nc (n=$nn) old=\$$oc (n=$on) ratio=$cr (<= 1.35)"
echo "wall new=${nw}s old=${ow}s delta=${delta}s (<= 90)"
echo "$verdict"
[ "$verdict" = PASS ]
