#!/usr/bin/env bash
. "$(dirname "$0")/../../lib.sh"
S=url-slugs
V="$(artifact $S verify)"; [ -n "$V" ] && [ -f "$V" ] || V="$(ls "$T"/.feature-flow/$S/verify.md 2>/dev/null)"
[ -n "$V" ] && [ -f "$V" ] && ok "verify.md written ($V)" || bad "no verify.md written"
! grep -q '^## Repair' "$V" 2>/dev/null && ok "no ## Repair section" || bad "spurious ## Repair cycle"
[ "$(m $S .currentPhase)" = done ] && ok "run reached done" || bad "run did not reach done"
[ -z "$(git -C "$T" status --porcelain src/)" ] && ok "src/ untouched" || bad "src/ modified without a failure"
done_
