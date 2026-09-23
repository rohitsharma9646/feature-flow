#!/usr/bin/env bash
. "$(dirname "$0")/../../lib.sh"
S=rate-limit
[ -f "$T/src/limiter.sh" ] && ok "src/limiter.sh written" || bad "no limiter written (false-fired STOP?)"
[ "$(m $S .phases.implement.status)" = complete ] && ok "implement complete" || bad "implement not complete"
done_
