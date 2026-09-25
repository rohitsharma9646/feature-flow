#!/usr/bin/env bash
. "$(dirname "$0")/../../lib.sh"
S=rate-limit
A="$(artifact $S architect)"; [ -n "$A" ] && [ -f "$A" ] || A="$T/.feature-flow/$S/architect.md"
[ -f "$A" ] && ok "architect.md written" || { bad "no architect.md"; done_; }
rec="$(grep -m1 -E '^Recommended: ' "$A" | sed 's/^Recommended: //')"
[ -n "$rec" ] && ok "Recommended: $rec" || bad "no Recommended: line"
grep -qE '^## Developed on request: ' "$A" && bad "re-dispatched although the recommendation was accepted" || ok "no re-dispatch"
D="$(artifact $S design)"; [ -n "$D" ] && [ -f "$D" ] || D="$(find "$T" -name design.md -path '*rate-limit*' | head -1)"
if [ -n "$D" ] && [ -f "$D" ]; then
  ok "design.md written"; CH="$(mktemp)"; RJ="$(mktemp)"; trap 'rm -f "$CH" "$RJ"' EXIT
  section "$D" '^## Chosen approach' > "$CH"
  mentions_any "$CH" $(keywords "$rec") && ok "Chosen approach names the recommendation" || bad "Chosen approach does not name '$rec'"
else bad "no design.md after accepting"; fi
[ -z "$(changed_outside_ff)" ] && ok "no source written" || bad "source files changed during design"
done_
