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
exit "$fail"
