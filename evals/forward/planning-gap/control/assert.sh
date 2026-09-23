#!/usr/bin/env bash
. "$(dirname "$0")/../../lib.sh"
S=csv-export
for f in rows csv export; do [ -f "$T/src/$f.sh" ] && ok "src/$f.sh written" || bad "src/$f.sh missing (false-fired STOP?)"; done
[ "$(m $S .phases.implement.status)" = complete ] && ok "implement complete" || bad "implement not complete"
done_
