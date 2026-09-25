#!/usr/bin/env bash
. "$(dirname "$0")/../../lib.sh"
S=rate-limit
C="$(artifact $S critic-design)"; [ -n "$C" ] && [ -f "$C" ] || C="$T/.feature-flow/$S/critic-design.md"
[ -f "$C" ] && ok "critic-design.md written" || { bad "no critic-design.md"; done_; }
head -1 "$C" | grep -qE '^Verdict: ready' && ok "Verdict: ready" || bad "first line is not 'Verdict: ready': $(head -1 "$C")"
grep -qE '^## Resolution' "$C" && bad "a revise cycle ran on a sound design" || ok "no revise cycle"
[ "$(m $S '.phases.design.status')" = complete ] && ok "design complete" || bad "design not complete: $(m $S '.phases.design.status')"
D="$(artifact $S decision)"; [ -n "$D" ] && [ -f "$D" ] && ok "decision.md written" || bad "no decision.md"
result_text | grep -qE 'Critic: (ready|revised)' && ok "closing Critic: line" || bad "no 'Critic: ready|revised' line in the final message"
[ -z "$(changed_outside_ff)" ] && ok "no source written" || bad "source files changed during design"
done_
