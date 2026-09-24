#!/usr/bin/env bash
. "$(dirname "$0")/../../lib.sh"
S=text-tools
[ "$(m $S '.phases.implement.status')" = complete ] && ok "implement complete" || bad "implement not complete"
L="$(artifact $S ledger)"
[ -n "$L" ] && [ -f "$L" ] && ok "ledger via artifacts.ledger ($L)" || bad "no ledger at artifacts.ledger"
[ -f "$L" ] || done_
head -1 "$L" | grep -q '^# Ledger — plan:' && ok "ledger identity line" || bad "ledger first line is not '# Ledger — plan: …'"
D="$T/.feature-flow/$S/tasks"
for n in 1 2 3; do
  e="$(section "$L" "^## Task $n:")"
  printf '%s\n' "$e" | grep -q '^\*\*Status:\*\* complete' && ok "Task $n complete" || bad "Task $n not complete in the ledger"
  printf '%s\n' "$e" | grep -qE '^\*\*Base:\*\* [0-9a-f]{40}' && printf '%s\n' "$e" | grep -qE '^\*\*Head:\*\* [0-9a-f]{40}' \
    && ok "Task $n base/head fingerprints" || bad "Task $n lacks 40-hex Base/Head"
  printf '%s\n' "$e" | grep -q '^\*\*TDD:\*\*.*RED.*GREEN' && ok "Task $n RED→GREEN" || bad "Task $n lacks a RED→GREEN TDD line"
  [ -s "$D/task-$n/diff.patch" ] && ok "task-$n/diff.patch" || bad "task-$n/diff.patch missing or empty"
  [ -s "$D/task-$n/review.md" ] && ok "task-$n/review.md" || bad "task-$n/review.md missing"
  [ -s "$D/task-$n/brief.md" ] && ! grep -q '^### Task [0-9]' <(grep -v "^### Task $n:" "$D/task-$n/brief.md") \
    && ok "task-$n/brief.md holds only its own task" || bad "task-$n/brief.md missing or holds another task"
done
section "$L" '^## Task 2:' | grep -q '^\*\*Fix round' && ok "Task 2 had a fix round" || bad "Task 2 had no fix round (seeded tab finding not caught)"
( cd "$T" && bash tests/test.sh >/dev/null 2>&1 ) && ok "tests/test.sh exits 0" || bad "tests/test.sh fails"
[ "$(cd "$T" && bash src/words.sh "$(printf 'a\tb')" 2>/dev/null)" = 2 ] && ok "words.sh counts a<TAB>b as 2" || bad "words.sh still miscounts tabs"
result_text | grep -qF 'Implement path: controller' && ok "final message states 'Implement path: controller'" || bad "final message lacks the 'Implement path: controller — <reason>' line"
[ "$(git -C "$T" rev-list --count HEAD)" = 1 ] && ok "no commit made" || bad "the session made a commit"
done_
