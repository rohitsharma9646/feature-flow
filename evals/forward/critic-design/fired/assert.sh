#!/usr/bin/env bash
. "$(dirname "$0")/../../lib.sh"
S=rate-limit
C="$(artifact $S critic-design)"; [ -n "$C" ] && [ -f "$C" ] || C="$T/.feature-flow/$S/critic-design.md"
[ -f "$C" ] && ok "critic-design.md written" || { bad "no critic-design.md"; done_; }
if grep -qE '^Critical C[0-9]+: .*(with_lock|lock\.sh|lock helper)' "$C"; then ok "the Critic flagged the missing lock helper as Critical"
else bad "no Critical finding names the missing with_lock / src/lib/lock.sh"; fi
grep -qE '^## Resolution' "$C" && ok "revise cycle recorded (## Resolution)" || bad "no ## Resolution section"
D="$(artifact $S design)"; [ -n "$D" ] && [ -f "$D" ] || D="$(find "$T" -name design.md -path '*rate-limit*' | head -1)"
if [ -n "$D" ] && [ -f "$D" ]; then
  if grep -qiE '(existing|already (ships|used|exists)|reuse)[^.]*with_lock|with_lock[^.]*(existing|already)' "$D"; then bad "design.md still relies on an existing with_lock"
  else ok "design.md no longer relies on a pre-existing with_lock"; fi
else bad "no design.md"; fi
st="$(m $S '.phases.design.status')"
if [ "$st" = complete ] || result_text | grep -qi 'Critic stop'; then ok "design completed or stopped at the Critic stop ($st)"; else bad "design neither complete nor at the Critic stop ($st)"; fi
[ -z "$(changed_outside_ff)" ] && ok "no source written" || bad "source files changed during design"
done_
