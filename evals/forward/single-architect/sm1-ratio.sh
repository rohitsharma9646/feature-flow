#!/usr/bin/env bash
# SM1 (v0.24.0): the fired arm's cost and wall time vs the same arm run against v0.23.0 (three
# architects), each as a ratio of means over every run in the two arm directories.
#   bash evals/forward/single-architect/sm1-ratio.sh <new out>/single-architect/fired <old out>/single-architect/fired
# Baseline: git worktree add <dir> e95c4de, then
#   FF_FORWARD_PLUGIN_DIR=<dir> scripts/forward-test.sh --repeat 2 --output-dir <out> single-architect
# Cost is run-<i>.json's total_cost_usd; wall time is run-<i>.wall (seconds, written by the runner).
# A measurement, run by hand — not an assertion. PASS when cost <= 0.90; wall time is reported, not
# gated (SM1 as amended 2026-09-25: the fan-out's architects ran in parallel, one architect cannot).
set -u
[ $# -eq 2 ] && [ -d "$1" ] && [ -d "$2" ] || { echo "usage: sm1-ratio.sh <new fired arm dir> <old fired arm dir>" >&2; exit 2; }
mean() { # mean <dir> cost|wall
  local f v sum=0 n=0
  for f in "$1"/run-[0-9]*.json; do
    case "$f" in *.followup.json) continue ;; esac
    if [ "$2" = cost ]; then v="$(jq -r '.total_cost_usd // empty' "$f")"; else v="$(cat "${f%.json}.wall" 2>/dev/null)"; fi
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
wr="$(awk -v n="$nw" -v o="$ow" 'BEGIN { printf "%.3f", n / o }')"
verdict="$(awk -v c="$cr" 'BEGIN { print (c <= 0.90 ? "PASS" : "FAIL") }')"
echo "SM1 cost v0.24.0=\$$nc (n=$nn) v0.23.0=\$$oc (n=$on) ratio=$cr (<= 0.90)"
echo "SM1 wall v0.24.0=${nw}s v0.23.0=${ow}s ratio=$wr (recorded, not gated)"
echo "SM1 $verdict"
[ "$verdict" = PASS ]
