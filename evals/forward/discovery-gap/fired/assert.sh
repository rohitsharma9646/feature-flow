#!/usr/bin/env bash
. "$(dirname "$0")/../../lib.sh"
S=url-slugs
V="$(artifact $S verify)"; [ -n "$V" ] && [ -f "$V" ] || V="$(ls "$T"/.feature-flow/$S/verify.md 2>/dev/null)"
[ -n "$V" ] && [ -f "$V" ] && ok "verify.md written ($V)" || bad "no verify.md written"
[ "$(m $S .currentPhase)" != done ] && ok "run held short of done" || bad "reached done with SM1 unproven"
sm="$(section "$V" '^#+ .*SM1([^0-9]|$)')"
[ -n "$sm" ] && ok "SM1 mapped as a contract item" || bad "no SM1 contract item in verify.md"
echo "$sm" | grep -qE 'Unverified|Partially verified' && ok "SM1 below Verified (single-source)" || bad "SM1 not marked Unverified/Partially verified"
done_
