#!/usr/bin/env bash
. "$(dirname "$0")/../../lib.sh"
S=version-flag
A="$(artifact $S architect)"; [ -n "$A" ] && [ -f "$A" ] || A="$T/.feature-flow/$S/architect.md"
[ -f "$A" ] && ok "architect.md written" || { bad "no architect.md"; done_; }
grep -q 'one obvious approach —' "$A" && ok "one obvious approach" || bad "no one obvious approach line"
grep -qE '^## Developed on request: ' "$A" && bad "re-dispatched although the approach was confirmed" || ok "no re-dispatch"
D="$(artifact $S design)"; [ -n "$D" ] && [ -f "$D" ] || D="$(find "$T" -name design.md -path '*version-flag*' | head -1)"
[ -n "$D" ] && [ -f "$D" ] && ok "design.md written" || bad "no design.md after confirming"
[ -z "$(changed_outside_ff)" ] && ok "no source written" || bad "source files changed during design"
done_
