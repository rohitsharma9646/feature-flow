#!/usr/bin/env bash
. "$(dirname "$0")/../../lib.sh"
S=url-slugs
V="$(artifact $S verify)"; [ -n "$V" ] && [ -f "$V" ] || V="$(ls "$T"/.feature-flow/$S/verify.md 2>/dev/null)"
[ -n "$V" ] && [ -f "$V" ] && ok "verify.md written ($V)" || bad "no verify.md written"
n="$(grep -c '^## Repair' "$V" 2>/dev/null)"
[ "$n" = 1 ] && ok "exactly one ## Repair section" || bad "expected one ## Repair section, found ${n:-0}"
done_
