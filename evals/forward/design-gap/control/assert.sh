#!/usr/bin/env bash
. "$(dirname "$0")/../../lib.sh"
S=url-slugs
V="$(artifact $S verify)"; [ -n "$V" ] && [ -f "$V" ] || V="$(ls "$T"/.feature-flow/$S/verify.md 2>/dev/null)"
[ -n "$V" ] && [ -f "$V" ] && ok "verify.md written ($V)" || bad "no verify.md written"
[ "$(m $S .currentPhase)" = done ] && ok "run reached done" || bad "run did not reach done (false-fired gap?)"
fs="$(section "$V" '^#+ .*FS1([^0-9]|$)')"
echo "$fs" | grep -qE 'Verified \((single|multi)-source\)' && ok "FS1 Verified" || bad "FS1 not Verified"
done_
