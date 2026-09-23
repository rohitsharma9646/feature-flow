#!/usr/bin/env bash
. "$(dirname "$0")/../../lib.sh"
S=url-slugs
V="$(artifact $S verify)"; [ -n "$V" ] && [ -f "$V" ] || V="$(ls "$T"/.feature-flow/$S/verify.md 2>/dev/null)"
[ -n "$V" ] && [ -f "$V" ] && ok "verify.md written ($V)" || bad "no verify.md written"
[ "$(m $S .currentPhase)" = done ] && ok "run reached done" || bad "run did not reach done (false-fired gap?)"
sm="$(section "$V" '^#+ .*SM1([^0-9]|$)')"
echo "$sm" | grep -qE 'Verified \((single|multi)-source\)' && ok "SM1 Verified" || bad "SM1 not Verified"
done_
