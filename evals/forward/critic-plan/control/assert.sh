#!/usr/bin/env bash
. "$(dirname "$0")/../../lib.sh"
S=rate-limit
C="$(artifact $S critic-plan)"; [ -n "$C" ] && [ -f "$C" ] || C="$T/.feature-flow/$S/critic-plan.md"
[ -f "$C" ] && ok "critic-plan.md written" || { bad "no critic-plan.md"; done_; }
head -1 "$C" | grep -qE '^Verdict: ready' && ok "Verdict: ready" || bad "first line is not 'Verdict: ready': $(head -1 "$C")"
grep -qE '^## Resolution' "$C" && bad "a revise cycle ran on a sound plan" || ok "no revise cycle"
[ "$(m $S '.phases.plan.status')" = complete ] && ok "plan complete" || bad "plan not complete: $(m $S '.phases.plan.status')"
P="$(artifact $S plan)"; [ -n "$P" ] && [ -f "$P" ] && ok "plan.md written" || bad "no plan.md"
result_text | grep -qE 'Critic: (ready|revised)' && ok "closing Critic: line" || bad "no 'Critic: ready|revised' line in the final message"
[ -z "$(changed_outside_ff)" ] && ok "no source written" || bad "source files changed during plan"
done_
