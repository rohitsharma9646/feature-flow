#!/usr/bin/env bash
# Regression guard: the implement task controller + executable plans (v0.23.0,
# .feature-flow/implement-controller) must stay wired. On a full-tier run whose plan has
# `## Global Constraints`, ff-implement dispatches one ff-implementer per task from a fence-aware
# brief, reviews each task's diff, runs a capped escalating fix loop and keeps a resumable ledger.
#   AC1   both plan templates: Global Constraints before Tasks, No Placeholders list + self-check
#         line, per-task Interfaces, Run/Expected steps — pinned text elsewhere left to its guards.
#   AC2   ff-plan authors the fields and runs the No Placeholders self-check before the Outcome gate.
#   AC3/4 ff-implement: activation test, inline fallback with a reason, pre-flight Plan placeholder
#         stop — all placed after the Critical-path check and before the loop.
#   AC5   ledger at <run dir>/tasks/ledger.md via manifest.artifacts.ledger (schema + field note).
#   AC6-13 the loop: brief via task_section, ff-implementer on models.implementer, the four statuses,
#         NEEDS_CONTEXT cap, fingerprints + diff.patch, review by path with two verdicts, 3 rounds
#         (resume, resume, escalate), ADDRESSED/NOT ADDRESSED, rulings, TDD lines, bugfix anchors.
#   AC14  ff-resume / ff-status / the SessionStart re-anchor name the ledger and current task.
#   AC15  ff-review hands reviewers a diff FILE (the paste instruction is gone) plus ledger rulings.
#   AC16  agents/ff-implementer.md: Write/Edit/Bash, no subagents, no git index/history changes.
#   AC17  models.implementer / models.escalation in defaults.json and the Known-keys line.
#   AC18  codex-tools.md maps ff-implementer and states the inline fallback.
#   AC19  the three stop rows in autopilot.md, none "unconditional"; the task-controller topic.
#   FS2   "keep the recorded Base" on resume.  FS4  the escalation-unavailable fallback.
#   pkg   §Task packaging block == hooks/lib/task.sh byte-for-byte (+ one-character-drift self-test).
# Behaviour of the lib (fence-aware extraction, tree diffs) is scripts/eval.sh's task-controller
# fixture; the re-anchor is session-start-guard.sh S11. Whether the loop FIRES — a subagent per
# task, a fix round on a seeded finding — is the forward test evals/forward/implement-controller.
set -u
cd "$(dirname "$0")/../.." || exit 2
fail=0
err() { echo "FAIL: $1"; fail=1; }
ok()  { echo "ok:   $1"; }
flat() { tr '\n' ' ' | sed 's/ > / /g' | tr -s '[:space:]' ' '; }  # prose may reflow across lines / blockquotes
has()  { flat < "$1" | grep -qF -- "$2"; }
need() { if has "$1" "$3"; then ok "$2: $1 has '$3'"; else err "$2: $1 must contain '$3'"; fi; }
lineno() { grep -nF -- "$2" "$1" | head -1 | cut -d: -f1; }
section() { awk -v h="$2" 'index($0, h) == 1 {s=1; print; next} s && /^## / {exit} s' "$1"; }

IMP="commands/ff-implement.md"; PLAN_CMD="commands/ff-plan.md"; REV="commands/ff-review.md"
TOPIC="docs/schema/task-controller.md"; AP="docs/schema/autopilot.md"; CORE="docs/manifest-schema.md"
AGENT="agents/ff-implementer.md"; LIB="hooks/lib/task.sh"; CODEX="skills/feature-flow/references/codex-tools.md"

# --- AC1: plan templates --------------------------------------------------------------------------
for t in templates/plan.md templates/plan-bugfix.md; do
  gc=$(lineno "$t" '## Global Constraints'); tk=$(lineno "$t" '## Tasks')
  if [ -n "$gc" ] && [ -n "$tk" ] && [ "$gc" -lt "$tk" ]; then ok "AC1: $t has ## Global Constraints ($gc) before ## Tasks ($tk)"
  else err "AC1: $t needs ## Global Constraints before ## Tasks"; fi
  for p in '**No Placeholders.**' 'TBD' 'add appropriate error handling' 'similar to Task N' \
           'unfilled `<…>` template placeholder' 'complete test code in a fenced block' \
           'does not name the exact change' '**Self-check ran:**' '**Interfaces:**' '- Consumes:' \
           '- Produces:' '**Run:**' '**Expected:**'; do
    need "$t" AC1 "$p"
  done
done
grep -q 'Verify RED' templates/plan-bugfix.md && grep -q 'Verify GREEN' templates/plan-bugfix.md \
  && ok "AC1/AC13: plan-bugfix.md keeps the Verify RED / Verify GREEN anchors" \
  || err "AC1/AC13: plan-bugfix.md must keep the Verify RED / Verify GREEN step labels"

# --- AC2: ff-plan -----------------------------------------------------------------------------------
need "$PLAN_CMD" AC2 '**Write an executable plan (full tier, both tracks):**'
need "$PLAN_CMD" AC2 '**No Placeholders self-check (full tier):**'
sc=$(lineno "$PLAN_CMD" '**No Placeholders self-check'); og=$(lineno "$PLAN_CMD" '**Populate the Outcome gate**')
[ -n "$sc" ] && [ -n "$og" ] && [ "$sc" -lt "$og" ] && ok "AC2: the self-check ($sc) runs before the Outcome gate ($og)" \
  || err "AC2: the No Placeholders self-check must come before 'Populate the Outcome gate'"

# --- AC3/AC4: activation + pre-flight, placed after the Critical-path check, before the loop --------
hline() { grep -nxF -- "$2" "$1" | head -1 | cut -d: -f1; }   # a heading line, not a mention in prose
cp=$(hline "$IMP" '## Critical-path check'); ca=$(hline "$IMP" '## Controller activation')
cl=$(hline "$IMP" '## Controller loop'); dw=$(hline "$IMP" '## Do the work — feature track')
if [ -n "$cp" ] && [ -n "$ca" ] && [ -n "$cl" ] && [ -n "$dw" ] && [ "$cp" -lt "$ca" ] && [ "$ca" -lt "$cl" ] && [ "$cl" -lt "$dw" ]; then
  ok "AC3: Critical-path check < Controller activation < Controller loop < inline Do the work"
else err "AC3: section order must be Critical-path check < Controller activation < Controller loop < Do the work"; fi
act="$(section "$IMP" '## Controller activation' | flat)"
for p in '**full tier**' '## Global Constraints' 'implement **inline**' '`Implement path: controller — <reason>`' '`Implement path: inline — <reason>`' \
         '**Plan placeholder stop**' 'in both modes' '/feature-flow:ff-plan' 'no task is dispatched'; do
  printf '%s' "$act" | grep -qF -- "$p" && ok "AC3/AC4: activation has '$p'" || err "AC3/AC4: activation must contain '$p'"
done
[ "$(grep -c '^\*\*Inline path\*\*' "$IMP")" -eq 2 ] && ok "AC3: both Do the work sections are marked as the inline path" \
  || err "AC3: both Do the work sections must open with **Inline path**"

# --- AC5: ledger ------------------------------------------------------------------------------------
grep -q '"ledger": ".feature-flow/add-oauth/tasks/ledger.md"' "$CORE" && has "$CORE" '**`artifacts.ledger`** (added v0.23.0)' \
  && ok "AC5: $CORE Schema + field note for artifacts.ledger" || err "AC5: $CORE lacks the artifacts.ledger schema line / field note"
has "$CORE" '`ledger` (with its `tasks/` directory)' && ok "AC5: ledger listed as ephemeral" \
  || err "AC5: $CORE must list the ledger among the ephemeral artifacts"
loop="$(section "$IMP" '## Controller loop' | flat)"
chk() { printf '%s' "$loop" | grep -qF -- "$2" && ok "$1: loop has '$2'" || err "$1: the Controller loop must contain '$2'"; }
chk AC5 '# Ledger — plan:'
chk AC5 'before the first dispatch'
chk AC5 'Rewrite the ledger after every step below, before the next dispatch'
need "$TOPIC" AC5 '**Two writes per step.**'
need "$TOPIC" AC5 '**Identity line.**'

# --- AC6-AC13: the loop -------------------------------------------------------------------------------
chk AC6 '^### Task <N>:'
chk AC6 '(never the whole plan)'
chk AC6 '**`ff-implementer`** with `model` = `models.implementer`'
for st in DONE DONE_WITH_CONCERNS NEEDS_CONTEXT BLOCKED; do chk AC7 "\`$st\`"; done
chk AC7 'at most twice per task'
chk AC7 '**Task blocked stop**'
chk AC8 'diff.patch'
chk AC8 'No step below runs `git add`'
chk AC9 '**paths only**'
chk AC9 'never paste the diff into the prompt'
chk AC9 'two verdicts — conformance'
chk AC9 'do not spawn subagents'
chk AC10 '**never more than 3 rounds**'
chk AC10 '**Rounds 1 and 2** resume the same implementer'
chk AC10 '**Round 3** dispatches a fresh `ff-implementer` on `models.escalation`'
chk AC10 '`ADDRESSED` or `NOT ADDRESSED`'
chk AC11 '**Critical-after-cap stop**'
chk AC11 '**Ruling:** <decision> — <why> — <cost if wrong>'
chk AC12 'TDD: exempt — <reason>'
chk AC12 'TDD: off (config)'
chk AC13 'manifest.bugfix.red'
chk AC13 'manifest.bugfix.green'
chk FS2 '**keep the recorded Base**'
chk FS4 'escalation unavailable — used <model>'
need "$TOPIC" AC7 'at most 15 lines'

# --- AC14: resume / status / re-anchor ----------------------------------------------------------------
need commands/ff-resume.md AC14 '**Resuming implement with a task ledger**'
need commands/ff-status.md AC14 '**task progress**'
grep -q 'current_task' hooks/session-start && ok "AC14: hooks/session-start names the current task" \
  || err "AC14: hooks/session-start must name the ledger's current task"

# --- AC15: ff-review -----------------------------------------------------------------------------------
has "$REV" 'run `git diff HEAD` yourself (staged + unstaged) and pass its output' \
  && err "AC15: $REV still tells the orchestrator to paste git diff output" || ok "AC15: the paste instruction is gone"
need "$REV" AC15 'never pasted into the prompt'
need "$REV" AC15 '<run dir>/review.diff'
need "$REV" AC15 '**Rulings from implement.**'
need "$REV" AC15 'hooks/lib/revision.sh" "<project dir>" head'
need "$REV" AC15 'Never diff against the raw `HEAD^{tree}`'
grep -q '^revision_head_tree()' hooks/lib/revision.sh && ok "AC15: revision.sh defines revision_head_tree (the review base)" \
  || err "AC15: hooks/lib/revision.sh must define revision_head_tree"

# --- AC16: the implementer agent ----------------------------------------------------------------------
if [ -f "$AGENT" ]; then
  tools="$(sed -n 's/^tools: //p' "$AGENT")"
  for tl in Write Edit Bash; do
    printf '%s' "$tools" | grep -qw "$tl" && ok "AC16: ff-implementer has $tl" || err "AC16: ff-implementer must have $tl"
  done
  printf '%s' "$tools" | grep -qwE 'Task|Agent' && err "AC16: ff-implementer must not have an agent-dispatch tool" \
    || ok "AC16: ff-implementer has no agent-dispatch tool"
  for p in 'Do **not** spawn subagents' '`git add`, `git commit`, `git stash`, `git reset`' 'except your own report file' \
           'at most 15 lines'; do need "$AGENT" AC16 "$p"; done
else err "AC16: $AGENT missing"; fi

# --- AC17: config -------------------------------------------------------------------------------------
if command -v jq >/dev/null 2>&1; then
  [ "$(jq -r '.models.implementer' config/defaults.json)" = sonnet ] && [ "$(jq -r '.models.escalation' config/defaults.json)" = opus ] \
    && ok "AC17: defaults.json models.implementer=sonnet, models.escalation=opus" || err "AC17: defaults.json needs models.implementer/escalation"
else err "AC17: needs jq"; fi
need "$CORE" AC17 'models.{explorer,architect,reviewer,diagnostician,testRunner,implementer,escalation}'

# --- AC18: Codex ----------------------------------------------------------------------------------------
need "$CODEX" AC18 '`ff-implementer`: the one editing role'
need "$CODEX" AC18 'the same loop runs inline, with the same files, in the same order, preserving role boundaries'

# --- AC19: contract topic + stop rows --------------------------------------------------------------------
for h in '## Task controller' '### Executable plans' '### Controller activation' '### Task packaging' '### Ledger' \
         '### Status contract' '### Task review' '### Fix loop' '### Rulings' '### Bugfix under the controller' '### Inline fallback (Codex)'; do
  grep -qxF -- "$h" "$TOPIC" && ok "AC19: $TOPIC defines '$h'" || err "AC19: $TOPIC must define '$h'"
done
for r in 'Plan placeholder stop' 'Task blocked stop' 'Critical-after-cap stop'; do
  row="$(grep -F "| $r (" "$AP")"
  if [ -z "$row" ]; then err "AC19: $AP needs a '$r' mandatory-pause row"
  elif printf '%s' "$row" | grep -qi 'unconditional'; then err "AC19: the '$r' row must not say unconditional (it is not a do-not-contradict STOP)"
  else ok "AC19: '$r' row present, not unconditional"; fi
done
for r in 'Task blocked stop' 'Critical-after-cap stop'; do
  grep -F "| $r (" "$AP" | grep -q '| cross-turn | capped' && ok "AC19: '$r' is capped-then-stop" \
    || err "AC19: the '$r' row must be the capped shape ('| cross-turn | capped')"
done
need "$AP" AC19 '**Per-task fix loop (`ff-implement` controller, both modes).**'

# --- pkg: §Task packaging block == hooks/lib/task.sh, byte for byte -----------------------------------
extract() { awk '/^### Task packaging/{s=1} s && /^```bash$/{c=1; next} c && /^```$/{exit} c' "$1"; }
TMPD="$(mktemp -d)"; trap 'rm -rf "$TMPD"' EXIT
extract "$TOPIC" > "$TMPD/block.sh"
if [ -s "$TMPD/block.sh" ] && cmp -s "$TMPD/block.sh" "$LIB"; then
  ok "pkg: $TOPIC §Task packaging block is $LIB byte-for-byte"
else err "pkg: $TOPIC §Task packaging block differs from $LIB — edit both together"; fi
sed 's/run(t, c) >= 3/run(t, c) >= 2/' "$TOPIC" > "$TMPD/drift.md"      # one-character drift
extract "$TMPD/drift.md" > "$TMPD/drift.sh"
cmp -s "$TMPD/drift.sh" "$LIB" && err "pkg self-test: a one-character drift must be caught" \
  || ok "pkg self-test: a one-character drift is caught"

# --- dist parity -------------------------------------------------------------------------------------------
DIST="dist/codex/feature-flow"
for rel in "$IMP" "$PLAN_CMD" "$REV" commands/ff-resume.md commands/ff-status.md templates/plan.md \
           templates/plan-bugfix.md "$TOPIC" "$AP" "$CORE" "$AGENT" "$CODEX" skills/feature-flow/SKILL.md config/defaults.json; do
  cmp -s "$rel" "$DIST/$rel" && ok "dist parity: $rel" \
    || err "dist parity: $rel differs from or is missing in $DIST/$rel (re-run scripts/package-codex-plugin.sh)"
done

if [ "$fail" -eq 0 ]; then echo "PASS: implement-controller guard"; else echo "RED: implement-controller guard failed"; fi
exit "$fail"
