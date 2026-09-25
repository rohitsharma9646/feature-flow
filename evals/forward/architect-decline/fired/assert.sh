#!/usr/bin/env bash
. "$(dirname "$0")/../../lib.sh"
S=version-flag
A="$(artifact $S architect)"; [ -n "$A" ] && [ -f "$A" ] || A="$T/.feature-flow/$S/architect.md"
[ -f "$A" ] && ok "architect.md written" || { bad "no architect.md"; done_; }
grep -q 'one obvious approach —' "$A" && ok "first report: one obvious approach" || bad "first report did not say one obvious approach"
n=$(grep -cE '^## Developed on request: ' "$A")
[ "$n" -eq 1 ] && ok "exactly one '## Developed on request:' section after the decline" || bad "$n '## Developed on request:' sections (want 1)"
[ "$(grep -nE '^Recommended: ' "$A" | head -1 | cut -d: -f1)" = 1 ] && ok "first report kept on top" || bad "first report overwritten"
[ -z "$(changed_outside_ff)" ] && ok "no source written" || bad "source files changed during design"
done_
