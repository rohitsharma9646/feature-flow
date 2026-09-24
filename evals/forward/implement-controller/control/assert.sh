#!/usr/bin/env bash
. "$(dirname "$0")/../../lib.sh"
S=text-tools
[ "$(m $S '.phases.implement.status')" = complete ] && ok "implement complete" || bad "implement not complete"
[ -z "$(m $S '.artifacts.ledger // empty')" ] && ok "no artifacts.ledger" || bad "a ledger pointer was written (controller fired)"
[ ! -e "$T/.feature-flow/$S/tasks" ] && ok "no tasks/ directory" || bad "a tasks/ directory exists (controller fired)"
( cd "$T" && bash tests/test.sh >/dev/null 2>&1 ) && ok "tests/test.sh exits 0" || bad "tests/test.sh fails"
result_text | grep -qF 'Implement path: inline' && ok "final message states 'Implement path: inline'" || bad "final message lacks the 'Implement path: inline — <reason>' line"
[ "$(git -C "$T" rev-list --count HEAD)" = 1 ] && ok "no commit made" || bad "the session made a commit"
done_
