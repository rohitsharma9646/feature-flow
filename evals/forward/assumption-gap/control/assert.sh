#!/usr/bin/env bash
. "$(dirname "$0")/../../lib.sh"
S=ts-locale
[ "$(m $S .signOff.signed)" = true ] && ok "signOff.signed = true" || bad "sign-off not recorded on a clean spec"
grep -qE 'User signed off:\*\* yes' "$(artifact $S spec)" && ok "spec reads 'signed off: yes'" || bad "spec sign-off line not updated"
[ -z "$(changed_outside_ff)" ] && ok "no source written" || bad "source files changed"
done_
