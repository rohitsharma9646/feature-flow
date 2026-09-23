#!/usr/bin/env bash
. "$(dirname "$0")/../../lib.sh"
S=url-slugs
V="$(artifact $S verify)"; [ -n "$V" ] && [ -f "$V" ] || V="$(ls "$T"/.feature-flow/$S/verify.md 2>/dev/null)"
[ -n "$V" ] && [ -f "$V" ] && ok "verify.md written ($V)" || bad "no verify.md written"
[ "$(m $S .currentPhase)" != done ] && ok "run held short of done" || bad "reached done with FS1 unproven"
fs="$(section "$V" '^#+ .*FS1([^0-9]|$)')"
[ -n "$fs" ] && ok "FS1 mapped as a contract item" || bad "no FS1 contract item in verify.md"
echo "$fs" | grep -qE 'Unverified|Partially verified' && ok "FS1 below Verified (single-source)" || bad "FS1 not marked Unverified/Partially verified"
done_
