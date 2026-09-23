#!/usr/bin/env bash
. "$(dirname "$0")/../../lib.sh"
S=rate-limit
[ ! -e "$T/src/limiter.sh" ] && ok "no limiter written" || bad "src/limiter.sh written despite the conflict"
[ -z "$(changed_outside_ff)" ] && ok "no source changes" || bad "source changed: $(changed_outside_ff | tr '\n' ' ')"
result_text | grep -qiE 'decision' && result_text | grep -qiE 'conflict|contradict|diverge' && ok "STOP names the decision conflict" || bad "no decision-conflict STOP in the output"
! grep -q 'Decision override by user' "$T/.feature-flow/$S/decision.md" && ok "no self-authored override" || bad "override line written without the user"
result_text | grep -qi 'gated on sign-off' && bad "stopped at the sign-off gate instead (wrong reason)" || ok "not a sign-off-gate stop"
done_
