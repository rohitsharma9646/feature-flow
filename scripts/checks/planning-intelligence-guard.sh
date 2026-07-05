#!/usr/bin/env bash
# Regression guard: WS-2 Planning Intelligence (dependency graph -> derived critical path
# -> do-not-contradict STOP; risk register -> verify; rollback -> recovery) must stay
# structurally wired. Pins the STRUCTURAL acceptance criteria of the planning-intelligence
# feature (.feature-flow/ws2-planning-intelligence, v0.11.0):
#   AC1/AC2  both plan templates carry the four sections, in order, between '## Tasks' and
#            '## Status conventions', each with a '> ' guidance blockquote.
#   AC3      Risk register is a categorical table (Likelihood/Impact/Mitigation), no numeric.
#   AC4      Dependency graph rows reference Task N IDs.
#   AC5/AC6  ff-plan.md derives the sections between AC-mapping and Outcome-gate population,
#            and states the critical path is DERIVED (never hand-authored).
#   AC7/AC9  ff-implement.md has a '## Critical-path check' section (between '## Decision
#            recall' and '## Do the work - feature track') that resolves via artifacts.plan,
#            STOPs unconditionally, records the Critical-path override verbatim, and points
#            at the Rollback plan on a failed Verify step.
#   AC8      ff-verify.md cross-references the plan's Risk register.
#   AC10/AC11 schema has the canonical '## Planning intelligence' section + an unconditional
#            'Critical-path stop' Autopilot row.
#   AC13     no planning-intelligence config toggle, no new top-level manifest field.
#   AC12/AC14 Codex dist parity for every touched packaged file.
#
# Behavioral AC15 (the STOP actually FIRING on a critical-path-skipping approach) is NOT
# grep-checkable and this guard deliberately does not assert it — that is a fresh-session
# self-run, manual-unverified, named in the 0.11.0 CHANGELOG (same posture as
# decision-record-guard.sh's AC13).
set -u
cd "$(dirname "$0")/../.." || exit 2
fail=0
err() { echo "FAIL: $1"; fail=1; }
ok()  { echo "ok:   $1"; }

# section <file> <start-heading-ERE>: body of the first '## ' section whose heading matches,
# up to (excluding) the next '## '. '### ' sub-headings stay inside.
section() { awk -v re="$2" '$0 ~ "^## " && seen {exit} $0 ~ re {seen=1} seen' "$1"; }
lineno()  { grep -nE "$2" "$1" | head -1 | cut -d: -f1; }

SCHEMA="docs/manifest-schema.md"

# --- AC1/AC2/AC3/AC4: both templates ----------------------------------------
for tpl in templates/plan.md templates/plan-bugfix.md; do
  [ -f "$tpl" ] || { err "$tpl: template must exist"; continue; }
  lt=$(lineno "$tpl" '^## Tasks')
  ld=$(lineno "$tpl" '^## Dependency graph')
  lc=$(lineno "$tpl" '^## Critical path')
  lr=$(lineno "$tpl" '^## Risk register')
  lb=$(lineno "$tpl" '^## Rollback plan')
  ls=$(lineno "$tpl" '^## Status conventions')
  if [ -n "$lt" ] && [ -n "$ld" ] && [ -n "$lc" ] && [ -n "$lr" ] && [ -n "$lb" ] && [ -n "$ls" ] \
     && [ "$lt" -lt "$ld" ] && [ "$ld" -lt "$lc" ] && [ "$lc" -lt "$lr" ] \
     && [ "$lr" -lt "$lb" ] && [ "$lb" -lt "$ls" ]; then
    ok "$tpl: four sections present, in order, between '## Tasks' and '## Status conventions'"
  else
    err "$tpl: four sections must sit, in order, between '## Tasks' and '## Status conventions' (Tasks=$lt Dep=$ld Crit=$lc Risk=$lr Roll=$lb Status=$ls)"
  fi
  for h in '^## Dependency graph' '^## Critical path' '^## Risk register' '^## Rollback plan'; do
    printf '%s\n' "$(section "$tpl" "$h")" | grep -q '^> ' \
      && ok "$tpl: '${h#^## }' carries a '> ' guidance blockquote" \
      || err "$tpl: '${h#^## }' must carry a '> ' guidance blockquote"
  done
  # AC3: risk register categorical table, no numeric scores
  rr="$(section "$tpl" '^## Risk register')"
  printf '%s\n' "$rr" | grep -qF '| Risk | Likelihood | Impact | Mitigation |' \
    && ok "$tpl: Risk register has the categorical table header" \
    || err "$tpl: Risk register must carry '| Risk | Likelihood | Impact | Mitigation |'"
  printf '%s\n' "$rr" | grep -qi 'no numeric' \
    && ok "$tpl: Risk register states the no-numeric-score doctrine" \
    || err "$tpl: Risk register must state 'no numeric scores'"
  # AC4: dependency graph rows reference Task N IDs
  printf '%s\n' "$(section "$tpl" '^## Dependency graph')" | grep -qE '\| Task [0-9]' \
    && ok "$tpl: Dependency graph rows reference Task N IDs" \
    || err "$tpl: Dependency graph must reference Task N IDs"
done

# --- AC10: canonical schema section + subsections ----------------------------
grep -q '^## Planning intelligence' "$SCHEMA" \
  && ok "$SCHEMA: '## Planning intelligence' canonical section present" \
  || err "$SCHEMA: must define the '## Planning intelligence' canonical section"
pi="$(section "$SCHEMA" '^## Planning intelligence')"
for h in 'Dependency graph notation' 'Critical-path derivation' 'Critical-path check' \
         'Risk register' 'Rollback plan'; do
  printf '%s\n' "$pi" | grep -qF "### $h" \
    && ok "$SCHEMA §Planning intelligence: '### $h' present" \
    || err "$SCHEMA §Planning intelligence: must keep '### $h'"
done
# AC6 (schema half): derivation is 'longest' chain over a 'lower-numbered' graph
printf '%s\n' "$pi" | grep -qi 'longest' \
  && ok "$SCHEMA §Planning intelligence: derivation names the longest chain" \
  || err "$SCHEMA §Planning intelligence: derivation must name the longest chain"
printf '%s\n' "$pi" | grep -qi 'lower-numbered' \
  && ok "$SCHEMA §Planning intelligence: states the lower-numbered dependency invariant" \
  || err "$SCHEMA §Planning intelligence: must state the lower-numbered dependency invariant"
printf '%s\n' "$pi" | grep -qF 'Critical-path override by user' \
  && ok "$SCHEMA §Planning intelligence: names the Critical-path override recording" \
  || err "$SCHEMA §Planning intelligence: must name 'Critical-path override by user (<date>): <reason>'"

# --- AC11: Autopilot mandatory-pauses row ------------------------------------
ap="$(section "$SCHEMA" '^## Autopilot')"
printf '%s\n' "$ap" | grep -qi 'Critical-path stop' \
  && ok "$SCHEMA §Autopilot: has the Critical-path stop row" \
  || err "$SCHEMA §Autopilot: mandatory-pauses table must have a Critical-path stop row"
printf '%s\n' "$ap" | awk 'tolower($0) ~ /critical-path stop/' | grep -qi 'unconditional' \
  && ok "$SCHEMA §Autopilot: Critical-path stop is unconditional" \
  || err "$SCHEMA §Autopilot: the Critical-path stop row must state it is unconditional"

# --- AC5/AC6: ff-plan.md derive instruction + placement ----------------------
grep -qi 'Derive planning intelligence' commands/ff-plan.md \
  && ok "commands/ff-plan.md: has the derive-planning-intelligence instruction" \
  || err "commands/ff-plan.md: must instruct deriving the planning-intelligence sections"
grep -qi 'never hand-author' commands/ff-plan.md \
  && ok "commands/ff-plan.md: states the critical path is derived, not hand-authored" \
  || err "commands/ff-plan.md: must state the critical path is derived (never hand-authored)"
la=$(lineno commands/ff-plan.md 'Map every AC')
ldp=$(grep -niE 'derive planning intelligence' commands/ff-plan.md | head -1 | cut -d: -f1)
lo=$(lineno commands/ff-plan.md 'Populate the Outcome gate')
if [ -n "$la" ] && [ -n "$ldp" ] && [ -n "$lo" ] && [ "$la" -lt "$ldp" ] && [ "$ldp" -lt "$lo" ]; then
  ok "commands/ff-plan.md: derive instruction sits between AC-mapping ($la) and Outcome-gate population ($lo)"
else
  err "commands/ff-plan.md: derive instruction must sit between AC-mapping (${la:-?}) and Outcome-gate population (${lo:-?}); found ${ldp:-MISSING}"
fi

# --- AC7/AC9: ff-implement.md '## Critical-path check' section + placement ----
cp="$(section commands/ff-implement.md '^## Critical-path check')"
if [ -z "$cp" ]; then
  err "commands/ff-implement.md: missing the '## Critical-path check' section"
else
  ok "commands/ff-implement.md: has a '## Critical-path check' section"
  printf '%s\n' "$cp" | grep -q 'artifacts.plan' \
    && ok "commands/ff-implement.md §Critical-path check: resolves via artifacts.plan" \
    || err "commands/ff-implement.md §Critical-path check: must resolve via artifacts.plan"
  printf '%s\n' "$cp" | grep -qi 'unconditional' \
    && ok "commands/ff-implement.md §Critical-path check: STOP is unconditional in both modes" \
    || err "commands/ff-implement.md §Critical-path check: STOP must be unconditional in both modes"
  printf '%s\n' "$cp" | grep -qF 'Critical-path override by user' \
    && ok "commands/ff-implement.md §Critical-path check: override recorded verbatim" \
    || err "commands/ff-implement.md §Critical-path check: override must record 'Critical-path override by user (<date>): <reason>'"
  printf '%s\n' "$cp" | grep -qi 'Rollback plan' \
    && ok "commands/ff-implement.md §Critical-path check: names the Rollback plan as recovery" \
    || err "commands/ff-implement.md §Critical-path check: must name the plan's Rollback plan as recovery on a failed Verify step"
fi
ldr=$(lineno commands/ff-implement.md '^## Decision recall')
lcc=$(lineno commands/ff-implement.md '^## Critical-path check')
ldw=$(lineno commands/ff-implement.md '^## Do the work — feature track')
if [ -n "$ldr" ] && [ -n "$lcc" ] && [ -n "$ldw" ] && [ "$ldr" -lt "$lcc" ] && [ "$lcc" -lt "$ldw" ]; then
  ok "commands/ff-implement.md: '## Critical-path check' sits between Decision recall and Do the work — feature track"
else
  err "commands/ff-implement.md: '## Critical-path check' must sit between '## Decision recall' (${ldr:-?}) and '## Do the work — feature track' (${ldw:-?}); found ${lcc:-MISSING}"
fi

# --- AC8: ff-verify.md cross-references the risk register ---------------------
grep -qi 'risk register' commands/ff-verify.md \
  && ok "commands/ff-verify.md: cross-references the plan's Risk register" \
  || err "commands/ff-verify.md: must cross-reference the plan's Risk register into Regression risk"
grep -q 'artifacts.plan' commands/ff-verify.md \
  && ok "commands/ff-verify.md: resolves the plan via artifacts.plan" \
  || err "commands/ff-verify.md: risk cross-reference must resolve via artifacts.plan"

# --- AC13: no new config key / manifest field (targeted negative check) ------
grep -qiE 'planningintelligence|dependencygraph|criticalpath|riskregister|rollbackplan' config/defaults.json \
  && err "config/defaults.json: must NOT gain a planning-intelligence key (always-on)" \
  || ok "config/defaults.json: no planning-intelligence config key (always-on, as required)"
schema_json="$(awk '/^## Schema/{s=1;next} /^## Field notes/{s=0} s' "$SCHEMA")"
printf '%s\n' "$schema_json" | grep -qiE '"(dependencyGraph|criticalPath|riskRegister|rollbackPlan)"' \
  && err "$SCHEMA: manifest JSON schema must NOT gain a new top-level planning-intelligence field" \
  || ok "$SCHEMA: no new top-level manifest field for planning intelligence"

# --- AC12/AC14: Codex dist parity for every touched packaged file ------------
DIST="dist/codex/feature-flow"
for rel in templates/plan.md templates/plan-bugfix.md docs/manifest-schema.md \
           commands/ff-plan.md commands/ff-implement.md commands/ff-verify.md; do
  if diff -q "$rel" "$DIST/$rel" >/dev/null 2>&1; then
    ok "dist parity: $rel"
  else
    err "dist parity: $rel differs from $DIST/$rel (re-run scripts/package-codex-plugin.sh)"
  fi
done

if [ "$fail" -eq 0 ]; then echo "PASS: planning-intelligence guard"; else echo "RED: planning-intelligence guard failed"; fi
exit "$fail"
