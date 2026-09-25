#!/usr/bin/env bash
. "$(dirname "$0")/../../lib.sh"
S=version-flag
A="$(artifact $S architect)"; [ -n "$A" ] && [ -f "$A" ] || A="$T/.feature-flow/$S/architect.md"
[ -f "$A" ] && ok "architect.md written ($A)" || bad "no architect.md"
[ -f "$A" ] || done_
grep -qE '^Recommended: ' "$A" && ok "Recommended: line" || bad "no Recommended: line"
grep -q 'one obvious approach —' "$A" && ok "control arm says one obvious approach" || bad "no 'one obvious approach' line in the control arm"
n=$(grep -cE '^Rejected: ' "$A")
[ "$n" -eq 0 ] && ok "no Rejected: line" || bad "$n Rejected: line(s) in the control arm"
[ -z "$(changed_outside_ff)" ] && ok "no source written" || bad "source files changed during design"
done_
