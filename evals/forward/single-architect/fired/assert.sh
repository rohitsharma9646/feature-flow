#!/usr/bin/env bash
. "$(dirname "$0")/../../lib.sh"
S=rate-limit
A="$(artifact $S architect)"; [ -n "$A" ] && [ -f "$A" ] || A="$T/.feature-flow/$S/architect.md"
[ -f "$A" ] && ok "architect.md written ($A)" || bad "no architect.md"
[ -f "$A" ] || done_
grep -qE '^Recommended: ' "$A" && ok "Recommended: line" || bad "no Recommended: line"
n=$(grep -cE '^Rejected: ' "$A")
[ "$n" -ge 1 ] && ok "$n Rejected: line(s)" || bad "no Rejected: line"
bad_scores=$(grep -E '^Rejected: ' "$A" | grep -cvE 'complexity: (low|med|high), risk: (low|med|high), test effort: (low|med|high)')
[ "$bad_scores" -eq 0 ] && ok "every Rejected: line carries the three scores" || bad "$bad_scores Rejected: line(s) lack a score"
spec_cited=$(grep -E '^Rejected: ' "$A" | grep -ciE "\\bspec\\b|spec's|violat|breaks? (a|the) (constraint|requirement|non-goal)|contradict")
[ "$spec_cited" -eq 0 ] && ok "no Rejected: line loses to the spec" || bad "$spec_cited Rejected: line(s) cite the spec/a constraint — not an option (FS1)"
grep -q 'one obvious approach —' "$A" && bad "fired arm claimed one obvious approach" || ok "no 'one obvious approach' in the fired arm"
[ -z "$(changed_outside_ff)" ] && ok "no source written" || bad "source files changed during design"
done_
