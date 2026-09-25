#!/usr/bin/env bash
. "$(dirname "$0")/../../lib.sh"
S=rate-limit
A="$(artifact $S architect)"; [ -n "$A" ] && [ -f "$A" ] || A="$T/.feature-flow/$S/architect.md"
[ -f "$A" ] && ok "architect.md written" || { bad "no architect.md"; done_; }
rec="$(grep -m1 -E '^Recommended: ' "$A" | sed 's/^Recommended: //')"
first_rej="$(grep -m1 -E '^Rejected: ' "$A" | sed 's/^Rejected: //; s/ — .*//')"
[ -n "$rec" ] && ok "Recommended: $rec" || bad "no Recommended: line"
[ -n "$first_rej" ] && ok "first Rejected: $first_rej" || bad "no Rejected: line to pick"
spec_cited=$(grep -E '^Rejected: ' "$A" | grep -ciE "\\bspec\\b|spec's|violat|breaks? (a|the) (constraint|requirement|non-goal)|contradict")
[ "$spec_cited" -eq 0 ] && ok "no Rejected: line loses to the spec" || bad "$spec_cited Rejected: line(s) cite the spec/a constraint — not an option (FS1)"
n=$(grep -cE '^## Developed on request: ' "$A")
[ "$n" -eq 1 ] && ok "exactly one '## Developed on request:' section (one re-dispatch)" || bad "$n '## Developed on request:' sections (want 1)"
[ "$(grep -nE '^Recommended: ' "$A" | head -1 | cut -d: -f1)" = 1 ] && ok "first report kept on top" || bad "first report overwritten"
D="$(artifact $S design)"; [ -n "$D" ] && [ -f "$D" ] || D="$(find "$T" -name design.md -path '*rate-limit*' | head -1)"
if [ -n "$D" ] && [ -f "$D" ]; then
  ok "design.md written"; CH="$(mktemp)"; RJ="$(mktemp)"; trap 'rm -f "$CH" "$RJ"' EXIT
  section "$D" '^## Chosen approach' > "$CH"; section "$D" '^## Rejected alternatives' > "$RJ"
  pk=$(distinct "$first_rej" "$rec"); rk=$(distinct "$rec" "$first_rej")
  [ -n "$pk" ] && [ -n "$rk" ] || bad "cannot tell the picked approach from the recommendation by name"
  mentions_any "$CH" $pk && ok "Chosen approach names the picked approach ($(echo $pk))" \
    || bad "Chosen approach does not name the picked approach '$first_rej'"
  mentions_any "$RJ" $rk && ok "the original recommendation is under Rejected alternatives" \
    || bad "original recommendation '$rec' missing from Rejected alternatives"
else bad "no design.md after the pick"; fi
[ -z "$(changed_outside_ff)" ] && ok "no source written" || bad "source files changed during design"
done_
