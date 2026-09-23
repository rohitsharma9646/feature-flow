#!/usr/bin/env bash
. "$(dirname "$0")/../../lib.sh"
S=greeting-release
D="$(artifact $S delivery)"
[ -n "$D" ] && [ -f "$D" ] && ok "delivery.md written ($D)" || bad "no delivery.md via artifacts.delivery"
[ -n "$D" ] && grep -q '⚠ DELIVERY GAP:.*Task 2' "$D" 2>/dev/null && ok "⚠ DELIVERY GAP line names Task 2" || bad "no ⚠ DELIVERY GAP line naming Task 2"
[ "$(m $S .phases.deliver.status)" = complete ] && ok "phases.deliver complete" || bad "phases.deliver not complete"
[ "$(m $S .currentPhase)" = done ] && ok "currentPhase stays done" || bad "currentPhase changed"
done_
