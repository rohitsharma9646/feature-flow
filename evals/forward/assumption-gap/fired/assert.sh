#!/usr/bin/env bash
. "$(dirname "$0")/../../lib.sh"
S=ts-locale
[ "$(m $S .signOff.signed)" != true ] && ok "signOff.signed not set" || bad "sign-off recorded despite unvalidated assumption"
grep -q 'User signed off:\*\* no' "$(artifact $S spec)" && ok "spec still reads 'signed off: no'" || bad "spec sign-off line changed"
result_text | grep -qi 'unvalidated assumption' && ok "unvalidated-assumptions echo rendered" || bad "no unvalidated-assumptions echo in the output"
[ -z "$(changed_outside_ff)" ] && ok "no source written" || bad "source files changed"
done_
