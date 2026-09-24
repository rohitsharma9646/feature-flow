#!/usr/bin/env bash
# SM1 (v0.23.0): the controller's own context vs the inline implement's, on the same plan.
#   bash evals/forward/implement-controller/sm1-ratio.sh <fired run.json> <control run.json>
# Main-session input tokens = usage.input_tokens + cache_creation + cache_read of the headless
# session's own conversation; subagents' tokens are not in that block. PASS when fired/control <= 0.60.
# A measurement, run by hand after `scripts/forward-test.sh implement-controller` — not an assertion.
set -u
[ $# -eq 2 ] || { echo "usage: sm1-ratio.sh <fired run.json> <control run.json>" >&2; exit 2; }
tok() { jq -r '(.usage.input_tokens // 0) + (.usage.cache_creation_input_tokens // 0) + (.usage.cache_read_input_tokens // 0)' "$1"; }
f="$(tok "$1")" || exit 2; c="$(tok "$2")" || exit 2
[ "${c:-0}" -gt 0 ] || { echo "control run has no usage block" >&2; exit 2; }
ratio="$(awk -v f="$f" -v c="$c" 'BEGIN { printf "%.3f", f / c }')"
verdict="$(awk -v r="$ratio" 'BEGIN { print (r <= 0.60 ? "PASS" : "FAIL") }')"
echo "SM1 fired=$f control=$c ratio=$ratio $verdict (<= 0.60)"
[ "$verdict" = PASS ]
