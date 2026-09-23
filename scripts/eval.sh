#!/usr/bin/env bash
# Eval harness (WS-8) — a BLOCKING CI gate since v2.3.
#
# Lives in scripts/ (NOT scripts/checks/, so the guard loop does not run it twice). It is wired
# into .github/workflows/ci.yml as its own blocking step — a RED fixture fails the build. Run it
# manually too:
#     bash scripts/eval.sh
#
# Scope: fixtures prove PRECONDITIONS only. Whether a behavior actually FIRES in a live session
# is proven by the local forward-test runner (scripts/forward-test.sh + evals/forward/), which
# needs Claude credentials and is never run in CI.
#
# It asserts the MECHANICAL PRECONDITIONS of the decision-records actuation — that a
# recorded decision is well-formed and tag-matchable, and that the do-not-contradict STOP
# wiring exists in the command that must fire it. It does NOT (and cannot in bash) assert
# the SEMANTIC catch — "the agent actually STOPs when an approach contradicts a decision"
# is an LLM judgment, verified by the local forward-test runner (evals/forward/decision-conflict),
# NOT here. Each fixture prints a pass/fail line.
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

# --- fixture: assumption-gap (WS-4) -----------------------------------------
# A spec whose §Assumptions table carries ONE unvalidated `validation-required: y` row — the
# exact hole ff-clarify's sign-off echo must surface as a `### Unvalidated assumptions` block
# that blocks a clean sign-off. Asserts the MECHANICAL preconditions of the sign-off-echo
# actuation; the SEMANTIC catch (the echo actually rendering + blocking on a live sign-off) is
# AC6/AC7 — a manual STOP-vs-control self-run, NOT assertable in bash. The 0.13.0 CHANGELOG
# names that as a known coverage gap.
echo ""
echo "fixture: assumption-gap"
ag_start=$fail
FXA="evals/fixtures/assumption-gap/spec.md"
TPL_S="templates/spec.md"
HDR='| Statement | Confidence | Basis / evidence | If-wrong impact | Validation-required |'

# (1) fixture spec exists and is a well-formed 5-column assumptions table
if [ -f "$FXA" ]; then ok "fixture spec exists ($FXA)"; else err "fixture spec missing ($FXA)"; fi
grep -qF "$HDR" "$FXA" 2>/dev/null \
  && ok "fixture carries the 5-column assumptions header" \
  || err "fixture must carry the 5-column assumptions header"

# (2) the deliberate hole: at least one assumption row is flagged Validation-required = y
#     (a still-unvalidated required assumption — what the sign-off echo must surface).
asec="$(awk '/^## Assumptions/{s=1;next} /^## /{s=0} s' "$FXA" 2>/dev/null)"
printf '%s\n' "$asec" | grep -qE '\|[[:space:]]*y[[:space:]]*\|[[:space:]]*$' \
  && ok "fixture has an unvalidated 'validation-required: y' row — the gap is present" \
  || err "fixture §Assumptions must carry a row whose Validation-required is 'y' (the gap)"

# (3) drift guard: the SHIPPED spec template still defines the section + header the fixture
#     mirrors, so a template restructure the fixture no longer matches is caught (not a stale pass).
grep -qE '^## Assumptions \(WHAT-changing\)' "$TPL_S" 2>/dev/null \
  && ok "shipped template still defines '## Assumptions (WHAT-changing)' (fixture not drifted)" \
  || err "shipped template no longer has '## Assumptions (WHAT-changing)' — regenerate from $TPL_S"
grep -qF "$HDR" "$TPL_S" 2>/dev/null \
  && ok "shipped template still carries the 5-column header (fixture not drifted)" \
  || err "shipped template no longer carries the 5-column assumptions header — regenerate from $TPL_S"

# (4) the sign-off-echo + waiver wiring the catch depends on exists in both producers
for cmd in commands/ff-clarify.md commands/ff-diagnose.md; do
  tr '\n' ' ' < "$cmd" | grep -qiF 'Unvalidated-assumptions echo' \
    && ok "$cmd carries the unvalidated-assumptions echo instruction" \
    || err "$cmd is missing the unvalidated-assumptions echo instruction"
  grep -qF 'Assumption validation waived by user (<date>): <reason>' "$cmd" \
    && ok "$cmd carries the verbatim waiver line" \
    || err "$cmd is missing the verbatim waiver line"
done

if [ "$fail" -eq "$ag_start" ]; then
  echo "PASS: assumption-gap (preconditions) — semantic catch is AC6/AC7/manual"
else
  echo "RED:  assumption-gap — a precondition failed"
fi

# --- fixture: planning-gap (WS-2) -------------------------------------------
# A plan whose stated ## Critical path was HAND-AUTHORED and drops a gating task its own
# ## Dependency graph proves is on the longest chain — the exact hole WS-2's "Derived — never
# hand-authored" rule exists to prevent. Asserts the MECHANICAL preconditions; the SEMANTIC
# catch (ff-plan deriving the path / ff-implement STOPping on a skip) is AC15 — a manual live
# self-run, NOT assertable in bash. The 0.11.0 CHANGELOG names that as a known coverage gap.
echo ""
echo "fixture: planning-gap"
pg_start=$fail
FXPG="evals/fixtures/planning-gap/plan.md"
TPL_P="templates/plan.md"

# (1) fixture exists and carries the two sections the critical-path derivation reads
if [ -f "$FXPG" ]; then ok "fixture plan exists ($FXPG)"; else err "fixture plan missing ($FXPG)"; fi
dep="$(awk '/^## Dependency graph/{s=1;next} /^## /{s=0} s' "$FXPG" 2>/dev/null)"
cps="$(awk '/^## Critical path/{s=1;next} /^## /{s=0} s' "$FXPG" 2>/dev/null)"
printf '%s\n' "$dep" | grep -qE '^\| *Task [0-9]' \
  && ok "fixture Dependency graph carries Task N rows" \
  || err "fixture must carry a Dependency graph with Task N rows"
path="$(printf '%s\n' "$cps" | sed -n 's/^\*\*Path:\*\*[[:space:]]*//p' | head -1)"
[ -n "$path" ] \
  && ok "fixture states a critical path ($path)" \
  || err "fixture §Critical path must carry a '**Path:**' line"

# (2) the deliberate hole: a gating task the graph proves is on the chain is DROPPED from the
# stated path. The graph makes Task 3 depend on Task 2, yet Task 2 is absent from the stated
# path — a hand-authored path skipping a gating task, exactly what the derived path would keep.
printf '%s\n' "$dep" | grep -qE '^\| *Task 3 *\|.*Task 2' \
  && ok "graph proves Task 3 depends on the gating Task 2" \
  || err "fixture graph must make Task 3 depend on Task 2 (the gating task the path drops)"
echo "$path" | grep -qw 'Task 2' \
  && err "stated critical path must OMIT the gating Task 2 — that omission IS the planning gap" \
  || ok "stated critical path drops the gating Task 2 — the planning gap is present and detectable"

# (3) drift guard: the shipped plan template still defines the two sections + the derived
# doctrine the fixture mirrors, so a template restructure the fixture no longer matches is caught.
for h in '^## Dependency graph' '^## Critical path'; do
  grep -qE "$h" "$TPL_P" 2>/dev/null \
    && ok "shipped plan template defines '${h#^## }' (fixture not drifted)" \
    || err "shipped plan template must define '${h#^## }' — regenerate the fixture from $TPL_P"
done
grep -qiF 'never hand-author' "$TPL_P" 2>/dev/null \
  && ok "shipped plan template states the critical path is derived, never hand-authored" \
  || err "shipped plan template must state the critical path is derived (never hand-authored)"

# (4) the derive + STOP wiring the catch depends on exists in the commands that must fire it
grep -qiF 'never hand-author' commands/ff-plan.md \
  && ok "commands/ff-plan.md instructs deriving the path (never hand-author)" \
  || err "commands/ff-plan.md is missing the derive-never-hand-author instruction"
awk '/^## Critical-path check/{s=1;next} /^## /{s=0} s' commands/ff-implement.md | grep -qF 'artifacts.plan' \
  && ok "commands/ff-implement.md §Critical-path check resolves the path via artifacts.plan" \
  || err "commands/ff-implement.md §Critical-path check must resolve via artifacts.plan"

if [ "$fail" -eq "$pg_start" ]; then
  echo "PASS: planning-gap (preconditions) — semantic catch is AC15/manual"
else
  echo "RED:  planning-gap — a precondition failed"
fi

# --- fixture: design-gap (WS-5) ---------------------------------------------
# A design.md whose Devil's-advocate FS1 names a failure scenario with no mechanical way to
# capture evidence in-sandbox — the exact hole ff-verify's FS<n> mapping must surface as an
# evidence gap that blocks `done`. Asserts the MECHANICAL preconditions of the FS<n> actuation;
# the SEMANTIC catch (ff-verify actually mapping it + the gap actually blocking done, AC7, and a
# covered scenario NOT false-firing, AC8) is a manual self-run, NOT assertable in bash. The 0.15.0
# CHANGELOG names that as a known coverage gap.
echo ""
echo "fixture: design-gap"
dg_start=$fail
FXDG="evals/fixtures/design-gap/design.md"
TPL_DG="templates/design.md"

# (1) fixture exists and carries a well-formed, labeled failure scenario
if [ -f "$FXDG" ]; then ok "fixture design exists ($FXDG)"; else err "fixture design missing ($FXDG)"; fi
grep -qE '^\- \*\*FS1:\*\*' "$FXDG" 2>/dev/null \
  && ok "fixture carries a labeled FS1 failure scenario — the gap is present and detectable" \
  || err "fixture must carry a '- **FS1:**' failure scenario row"

# (2) drift guard: the shipped design template still defines the sections the fixture mirrors
for h in '^## Trade-off matrix' "^## Devil's advocate" '^### Failure scenarios'; do
  grep -qE "$h" "$TPL_DG" 2>/dev/null \
    && ok "shipped design template defines '${h#^}' (fixture not drifted)" \
    || err "shipped design template must define '${h#^}' — regenerate the fixture from $TPL_DG"
done

# (3) the FS<n>-mapping + artifacts.design wiring the catch depends on exists in ff-verify
grep -qF 'artifacts.design' commands/ff-verify.md \
  && ok "commands/ff-verify.md resolves upstream via artifacts.design" \
  || err "commands/ff-verify.md is missing the artifacts.design resolution"
grep -qiF 'exactly as an acceptance criterion' commands/ff-verify.md \
  && ok "commands/ff-verify.md carries the FS<n>-maps-like-an-AC instruction" \
  || err "commands/ff-verify.md is missing the FS<n> contract-mapping instruction"

if [ "$fail" -eq "$dg_start" ]; then
  echo "PASS: design-gap (preconditions) — semantic catch is AC7/AC8/manual"
else
  echo "RED:  design-gap — a precondition failed"
fi

# --- fixture: repair-gap (WS-6) ---------------------------------------------
# A PAIR of verify.md fixtures for the one-cycle autopilot repair-and-re-verify: `verify.md` has an
# AC failing with a CAPTURED non-success status (a genuine failure, not a pure gap) and NO `## Repair`
# section — the first-cycle-available precondition; `verify-capped.md` is the same failure WITH a
# `## Repair` section — the cap-detectable precondition (a second cycle must be refused). Asserts the
# MECHANICAL preconditions of the repair actuation; the SEMANTIC catch (autopilot attempting EXACTLY
# ONE cycle then stopping, AC13, and a passing verify NOT false-firing a cycle, AC14) is a manual
# fresh-session self-run, NOT assertable in bash. The 0.16.0 CHANGELOG names that as a known gap.
echo ""
echo "fixture: repair-gap"
rg_start=$fail
FXR="evals/fixtures/repair-gap/verify.md"
FXRC="evals/fixtures/repair-gap/verify-capped.md"
TPL_R="templates/verify.md"

# (1) first-cycle fixture: a genuine failure (captured non-success status), no ## Repair yet
if [ -f "$FXR" ]; then ok "first-cycle fixture exists ($FXR)"; else err "first-cycle fixture missing ($FXR)"; fi
grep -qE 'exit [1-9]' "$FXR" 2>/dev/null \
  && ok "first-cycle fixture carries a captured non-success status — a genuine failure, not a pure gap" \
  || err "first-cycle fixture must carry a captured non-success exit/HTTP status"
grep -q '^## Repair' "$FXR" 2>/dev/null \
  && err "first-cycle fixture must NOT already carry '## Repair' — that presence IS the cap-exhausted case" \
  || ok "first-cycle fixture has no '## Repair' yet — a first cycle is available"

# (2) capped variant: same failure, WITH a ## Repair section (a second cycle must be refused)
if [ -f "$FXRC" ]; then ok "capped fixture exists ($FXRC)"; else err "capped fixture missing ($FXRC)"; fi
grep -q '^## Repair' "$FXRC" 2>/dev/null \
  && ok "capped fixture carries '## Repair' — the cap is detectable, no second cycle" \
  || err "capped fixture must carry '## Repair' (the idempotency-detectable case)"

# (3) drift guard: the shipped verify template still defines the sections the fixtures mirror
for h in '^## Contract mapping' '^## Repair'; do
  grep -qE "$h" "$TPL_R" 2>/dev/null \
    && ok "shipped verify template defines '${h#^}' (fixtures not drifted)" \
    || err "shipped verify template must define '${h#^}' — regenerate the fixtures from $TPL_R"
done

# (4) the repair-cycle wiring the catch depends on exists in ff-verify
grep -qiF 'Autopilot repair-and-re-verify cycle' commands/ff-verify.md \
  && ok "commands/ff-verify.md carries the autopilot repair-and-re-verify branch" \
  || err "commands/ff-verify.md is missing the autopilot repair-and-re-verify branch"

if [ "$fail" -eq "$rg_start" ]; then
  echo "PASS: repair-gap (preconditions) — semantic catch is AC13/AC14/manual"
else
  echo "RED:  repair-gap — a precondition failed"
fi

# --- fixture: discovery-gap (WS-7) ------------------------------------------
# A PAIR of fixtures for the two discovery-field actuations: `spec.md` carries a labeled
# `## Success metrics` row (the thing ff-verify must turn into a `### SM<n>` contract item) and a
# `## Requirement graph` edge `AC2 depends-on AC1`; `plan.md`'s `## Dependency graph` DROPS the
# derived `Task 2 → Task 1` edge (Task 2 covers AC2, Task 1 covers AC1) — the hole ff-plan's
# derivation must catch. Asserts the MECHANICAL preconditions; the SEMANTIC catch (an unproven
# metric actually blocking `done`, AC6; the dropped edge actually surfacing at the Outcome gate,
# AC8) is a manual fresh-session self-run, NOT assertable in bash. The 0.17.0 CHANGELOG names it.
echo ""
echo "fixture: discovery-gap"
dv_start=$fail
FXDS="evals/fixtures/discovery-gap/spec.md"
FXDP="evals/fixtures/discovery-gap/plan.md"
TPL_DS="templates/spec.md"
TPL_DP="templates/plan.md"

# (1) fixture spec exists and carries a labeled Success-metrics row + the AC-edge
if [ -f "$FXDS" ]; then ok "fixture spec exists ($FXDS)"; else err "fixture spec missing ($FXDS)"; fi
awk '/^## Success metrics/{s=1;next} /^## /{s=0} s' "$FXDS" 2>/dev/null | grep -qE '^\- \[ \] SM1:' \
  && ok "fixture carries a labeled 'SM1:' success-metric row — the metric side is present and detectable" \
  || err "fixture §Success metrics must carry a labeled '- [ ] SM1:' row"
awk '/^## Requirement graph/{s=1;next} /^## /{s=0} s' "$FXDS" 2>/dev/null | grep -qE '^\| *AC2 *\| *AC1 *\|' \
  && ok "fixture Requirement graph carries the 'AC2 depends-on AC1' edge" \
  || err "fixture §Requirement graph must carry the '| AC2 | AC1 |' edge"

# (2) the deliberate hole: the plan's Task 2 (covers AC2) OMITS the Task 1 dependency the spec's
# AC2->AC1 edge implies — mirrors planning-gap's dropped-gating-task shape.
dvdep="$(awk '/^## Dependency graph/{s=1;next} /^## /{s=0} s' "$FXDP" 2>/dev/null)"
if [ -f "$FXDP" ]; then ok "fixture plan exists ($FXDP)"; else err "fixture plan missing ($FXDP)"; fi
printf '%s\n' "$dvdep" | grep -qE '^\| *Task 2 .*Task 1' \
  && err "fixture plan's Task 2 row must OMIT the Task 1 dependency the spec's AC2->AC1 edge implies — that omission IS the gap" \
  || ok "fixture plan drops the AC-derived Task 2 → Task 1 edge — the requirement-graph gap is present and detectable"

# (3) drift guard: the shipped spec/plan templates still define the sections the fixtures mirror,
# so a template restructure the fixtures no longer match is caught (not a silent stale pass).
for h in '^## Success metrics' '^## Requirement graph'; do
  grep -qE "$h" "$TPL_DS" 2>/dev/null \
    && ok "shipped spec template defines '${h#^## }' (fixture not drifted)" \
    || err "shipped spec template must define '${h#^## }' — regenerate the fixture from $TPL_DS"
done
grep -qE '^## Dependency graph' "$TPL_DP" 2>/dev/null \
  && ok "shipped plan template defines '## Dependency graph' (fixture not drifted)" \
  || err "shipped plan template must define '## Dependency graph' — regenerate the fixture from $TPL_DP"

# (4) the SM-mapping + requirement-graph-derivation wiring the catches depend on exists
grep -qE '### SM<n>' commands/ff-verify.md \
  && ok "commands/ff-verify.md maps each Success-metrics row into its own SM<n> contract item" \
  || err "commands/ff-verify.md is missing the '### SM<n>' contract-mapping instruction"
grep -qiF 'Derive requirement-graph task edges' commands/ff-plan.md \
  && ok "commands/ff-plan.md carries the requirement-graph task-edge derivation instruction" \
  || err "commands/ff-plan.md is missing the requirement-graph task-edge derivation instruction"

if [ "$fail" -eq "$dv_start" ]; then
  echo "PASS: discovery-gap (preconditions) — semantic catch is AC6/AC8/manual"
else
  echo "RED:  discovery-gap — a precondition failed"
fi

exit "$fail"
