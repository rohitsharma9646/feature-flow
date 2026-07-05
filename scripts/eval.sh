#!/usr/bin/env bash
# Eval harness (WS-8) — NON-BLOCKING by design.
#
# Lives in scripts/ (NOT scripts/checks/) and is deliberately NOT wired into
# .github/workflows/ci.yml, so it never gates a release. Run it manually:
#     bash scripts/eval.sh
#
# It asserts the MECHANICAL PRECONDITIONS of the decision-records actuation — that a
# recorded decision is well-formed and tag-matchable, and that the do-not-contradict STOP
# wiring exists in the command that must fire it. It does NOT (and cannot in bash) assert
# the SEMANTIC catch — "the agent actually STOPs when an approach contradicts a decision"
# is an LLM judgment, verified by a live self-run (AC13, manual), NOT here. The 0.10.0
# CHANGELOG names that as a known coverage gap. Each fixture prints a pass/fail line.
set -u
cd "$(dirname "$0")/.." || exit 2
fail=0
err() { echo "  FAIL: $1"; fail=1; }
ok()  { echo "  ok:   $1"; }

TPL="templates/decision.md"

# --- fixture: decision-conflict ---------------------------------------------
# A recorded decision (stateless JWT sessions) + a request that contradicts it. Proves the
# preconditions the do-not-contradict STOP relies on; the STOP firing is AC13 (manual).
echo "fixture: decision-conflict"
FX="evals/fixtures/decision-conflict/decision.md"
REQ="Switch the chosen session-storage approach to server-side Redis sessions instead of stateless JWTs."

# (1) the decision record parses and carries the fields recall/tag-match reads
if [ -f "$FX" ]; then
  ok "fixture decision record exists ($FX)"
else
  err "fixture decision record missing ($FX)"
fi
for anchor in '^tags:' '^## Decision' '^## Chosen \+ rationale'; do
  grep -qE "$anchor" "$FX" 2>/dev/null \
    && ok "fixture carries '${anchor#^}'" \
    || err "fixture must carry '${anchor#^}' (a well-formed decision record)"
done
# drift guard: the fixture's section anchors must still exist in the SHIPPED template, so a
# template restructure that the fixture no longer matches is caught (not a silent stale pass).
for anchor in '^## Decision' '^## Chosen \+ rationale'; do
  grep -qE "$anchor" "$TPL" 2>/dev/null \
    && ok "shipped template still defines '${anchor#^}' (fixture not drifted)" \
    || err "shipped template no longer has '${anchor#^}' — regenerate the fixture from $TPL"
done

# (2) deterministic tag-match: the decision's own tags surface it against the contradicting
# request. Split the `tags: [..]` frontmatter on commas and match each token, case-insensitive.
tags="$(sed -n 's/^tags:[[:space:]]*\[\(.*\)\].*/\1/p' "$FX" | head -1)"
matched=0
IFS=',' read -ra toks <<< "$tags"
for t in "${toks[@]}"; do
  tok="$(echo "$t" | tr -d '[:space:]')"
  [ -z "$tok" ] && continue
  if echo "$REQ" | grep -qiF "$tok"; then
    matched=1
    ok "tag '$tok' tag-matches the contradicting request (decision would be recalled)"
  fi
done
[ "$matched" -eq 1 ] \
  || err "no tag of the decision matched the contradicting request — recall would not surface it"

# (3) the STOP wiring the catch depends on exists in the command that must fire it
grep -qiF 'do-not-contradict' commands/ff-implement.md \
  && ok "commands/ff-implement.md carries the do-not-contradict STOP instruction" \
  || err "commands/ff-implement.md is missing the do-not-contradict STOP instruction"

if [ "$fail" -eq 0 ]; then
  echo "PASS: decision-conflict (preconditions) — semantic catch is AC13/manual"
else
  echo "RED:  decision-conflict — a precondition failed"
fi

# --- fixture: delivery-gap (WS-3) -------------------------------------------
# A done run whose plan has a migration task with NO rollback line — the exact hole
# ff-deliver must surface as a non-blocking ⚠ DELIVERY GAP. Asserts the MECHANICAL
# preconditions of the delivery-gap actuation; the SEMANTIC catch (ff-deliver actually
# writing the gap line on a live run) is AC5 — manual, NOT assertable in bash.
echo ""
echo "fixture: delivery-gap"
gap_start=$fail
FXP="evals/fixtures/delivery-gap/plan.md"
TPL_D="templates/delivery.md"

# (1) fixture plan exists and carries a migration/schema task (the thing needing a rollback)
if [ -f "$FXP" ]; then ok "fixture plan exists ($FXP)"; else err "fixture plan missing ($FXP)"; fi
grep -qiE 'migrat|schema' "$FXP" 2>/dev/null \
  && ok "fixture plan carries a migration/schema task" \
  || err "fixture plan must carry a migration/schema task"

# (2) the deliberate hole: the migration task (Task 2) has NO recovery ROW in ## Rollback plan.
# Match table rows only ('| Task 2 …'), not prose that merely names the task — a recovery line is
# a table row, exactly what ff-deliver checks for.
roll="$(awk '/^## Rollback plan/{s=1;next} /^## /{s=0} s' "$FXP" 2>/dev/null)"
printf '%s\n' "$roll" | grep -qE '^\| *Task 2' \
  && err "fixture Rollback plan must OMIT the migration task's recovery row (| Task 2 …) — that omission IS the gap" \
  || ok "migration task has no recovery row in Rollback plan — the delivery gap is present and detectable"

# (3) drift guard: the shipped template still defines the sections the gap/known-issues/validation
# are written into, so a template restructure the fixture no longer matches is caught (not silently passed).
for h in '^## Rollback checklist' '^## Known issues' '^## Release validation steps'; do
  grep -qE "$h" "$TPL_D" 2>/dev/null \
    && ok "shipped delivery template defines '${h#^## }' (fixture not drifted)" \
    || err "shipped delivery template must define '${h#^## }' — regenerate the fixture from $TPL_D"
done

# (4) the gap-detection + pointer wiring the catch depends on exists in ff-deliver
grep -qiF 'DELIVERY GAP' commands/ff-deliver.md \
  && ok "commands/ff-deliver.md carries the DELIVERY GAP detection instruction" \
  || err "commands/ff-deliver.md is missing the DELIVERY GAP detection instruction"
for ptr in 'artifacts.plan' 'artifacts.verify'; do
  grep -qF "$ptr" commands/ff-deliver.md \
    && ok "commands/ff-deliver.md resolves upstream via $ptr" \
    || err "commands/ff-deliver.md must resolve upstream via $ptr"
done

if [ "$fail" -eq "$gap_start" ]; then
  echo "PASS: delivery-gap (preconditions) — semantic catch is AC5/manual"
else
  echo "RED:  delivery-gap — a precondition failed"
fi

exit "$fail"
