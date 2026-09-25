#!/usr/bin/env bash
. "$(dirname "$0")/../../lib.sh"
S=rate-limit
C="$(artifact $S critic-plan)"; [ -n "$C" ] && [ -f "$C" ] || C="$T/.feature-flow/$S/critic-plan.md"
[ -f "$C" ] && ok "critic-plan.md written" || { bad "no critic-plan.md"; done_; }
if grep -qE '^Critical C[0-9]+: .*(with_lock|lock\.sh|lock helper)' "$C"; then ok "the Critic flagged the missing lock helper as Critical"
else bad "no Critical finding names the missing with_lock / src/lib/lock.sh"; fi
P="$(artifact $S plan)"
if result_text | grep -q 'ff-design'; then ok "routed to ff-design for a design-level fix"
elif [ -n "$P" ] && [ -f "$P" ] && grep -qE '^## Resolution' "$C"; then
  ok "revise cycle recorded (## Resolution)"
  if grep -qE 'Consumes:.*with_lock' "$P" && ! grep -qE '(Create|Produces:)[^\n]*(src/lib/lock\.sh|with_lock)' "$P"; then bad "plan.md still consumes a with_lock no task creates"
  else ok "plan.md creates the helper or no longer consumes it"; fi
else bad "neither a revise cycle with plan.md nor a route to ff-design"; fi
[ -z "$(changed_outside_ff)" ] && ok "no source written" || bad "source files changed during plan"
done_
