#!/usr/bin/env bash
# Regression guard: WS-7 Discovery field completeness must stay structurally wired.
# Pins the STRUCTURAL acceptance criteria of the discovery-fields feature
# (.feature-flow/ws7-discovery-fields, v0.17.0) by grepping the VERBATIM SHIPPED
# templates/commands/schema — never a hand-typed fixture string (the pin-against-shipped
# lesson from evidence-based-verification):
#   AC1   templates/spec.md carries optional '## Success metrics' + '## Requirement graph',
#         each with a full-tier-only banner; and NO '## Stakeholders' section (cut — no actuation).
#   AC2   Success metrics states the binary-threshold-with-measurement discipline and
#         cross-references (does not diverge from) the binary-AC discipline.
#   AC3   Requirement graph carries the '| AC | Depends on |' table and names its reuse of
#         §Planning intelligence's dependency notation (not a divergent grammar).
#   AC4   ff-clarify.md prompts for the two fields (full tier, non-trivial), explicitly skips
#         them on lite, and its spec fill-list names both.
#   AC5   ff-verify.md maps each Success-metrics row into its own '### SM<n>' contract item
#         "exactly as an acceptance criterion", by a PRESENCE check on the section (not a tier
#         check), resolved via the already-read artifacts.spec.
#   AC7   ff-plan.md derives task-dependency edges from the Requirement graph, in a bullet placed
#         between 'Map every AC' and 'Derive planning intelligence'; templates/plan.md's
#         '| Task | Depends on |' Dependency-graph header stays UNTOUCHED (derive-don't-widen).
#   AC8   templates/plan.md's Outcome gate carries the requirement-graph coverage/gap rule and
#         names the un-derivable same-task-covers-both-ACs gap format.
#   AC10  docs/manifest-schema.md '## Discovery fields' canonical section + subsections, and the
#         Confidence-ladder fourth contract-item class (success metric).
#   AC9   no new config key / manifest field / §Autopilot row (targeted negative checks).
#   dist  Codex dist parity for every touched packaged file.
#
# Behavioral AC6/AC8 (an unproven success metric actually BLOCKING done via the evidence-gap
# stop, and an un-derivable requirement-graph edge actually surfacing at the plan's Outcome gate)
# are NOT grep-checkable and this guard deliberately does not assert them — a fresh-session
# fired-vs-control self-run, named in the 0.17.0 CHANGELOG (same posture as
# design-tradeoff-guard.sh AC7/AC8 / assumption-guard.sh AC6-AC7 / repair-loop-guard.sh AC13-AC14).
#
# mawk portability: the new headings carry no literal parens, so no bracket-expr is needed here;
# any future pattern matching a parenthesised heading MUST use [(]/[)], never \(/\) (mawk strips
# \( → regex group, breaking the match; see assumption-guard.sh:52 / CI run #21).
set -u
cd "$(dirname "$0")/../.." || exit 2
fail=0
err() { echo "FAIL: $1"; fail=1; }
ok()  { echo "ok:   $1"; }

section() { awk -v re="$2" '$0 ~ "^## " && seen {exit} $0 ~ re {seen=1} seen' "$1"; }
lineno()  { grep -nE "$2" "$1" | head -1 | cut -d: -f1; }
flat()    { tr '\n' ' ' | tr -s '[:space:]' ' '; }

SCHEMA="docs/manifest-schema.md"
TPL_S="templates/spec.md"
TPL_V="templates/verify.md"
TPL_P="templates/plan.md"

# --- AC1: spec template headers + banners + no Stakeholders ------------------
[ -f "$TPL_S" ] || err "$TPL_S: template must exist"
grep -qE '^## Success metrics' "$TPL_S" \
  && ok "$TPL_S: '## Success metrics' present" \
  || err "$TPL_S: missing the '## Success metrics' section"
grep -qE '^## Requirement graph' "$TPL_S" \
  && ok "$TPL_S: '## Requirement graph' present" \
  || err "$TPL_S: missing the '## Requirement graph' section"
for h in '^## Success metrics' '^## Requirement graph'; do
  sec="$(section "$TPL_S" "$h")"
  printf '%s' "$sec" | flat | grep -qiF 'full tier only' \
    && ok "$TPL_S: '${h#^## }' carries the full-tier-only banner" \
    || err "$TPL_S: '${h#^## }' must carry a full-tier-only banner"
done
grep -qE '^## Stakeholders' "$TPL_S" \
  && err "$TPL_S: must NOT contain '## Stakeholders' (cut — no actuation)" \
  || ok "$TPL_S: no Stakeholders section (as required)"

# --- AC2: Success metrics binary-threshold discipline, cross-referenced -------
sm="$(section "$TPL_S" '^## Success metrics')"
printf '%s' "$sm" | flat | grep -qiF 'binary threshold with a named measurement method' \
  && ok "$TPL_S: Success metrics states the binary-threshold-with-measurement discipline" \
  || err "$TPL_S: Success metrics must state 'binary threshold with a named measurement method'"
printf '%s' "$sm" | flat | grep -qiF 'not a divergent grammar' \
  && ok "$TPL_S: Success metrics cross-references (not diverges from) the binary-AC discipline" \
  || err "$TPL_S: Success metrics must cross-reference the binary-AC discipline ('not a divergent grammar')"

# --- AC3: Requirement graph notation + reuse statement -----------------------
rg="$(section "$TPL_S" '^## Requirement graph')"
printf '%s' "$rg" | grep -qF '| AC | Depends on |' \
  && ok "$TPL_S: Requirement graph carries the '| AC | Depends on |' header" \
  || err "$TPL_S: Requirement graph must carry the '| AC | Depends on |' header"
printf '%s' "$rg" | flat | grep -qiF 'Planning intelligence' \
  && ok "$TPL_S: Requirement graph names its reuse of §Planning intelligence's notation" \
  || err "$TPL_S: Requirement graph must name its reuse of the §Planning intelligence notation"

# --- AC4: ff-clarify prompts full-tier + non-trivial; lite skip; fill-list ----
flat < commands/ff-clarify.md | grep -qiF 'Success metrics' \
  && ok "commands/ff-clarify.md: names the Success metrics field" \
  || err "commands/ff-clarify.md: must name the Success metrics field"
flat < commands/ff-clarify.md | grep -qiF 'Requirement graph' \
  && ok "commands/ff-clarify.md: names the Requirement graph field" \
  || err "commands/ff-clarify.md: must name the Requirement graph field"
flat < commands/ff-clarify.md | grep -qiF 'Lite tier skips them entirely' \
  && ok "commands/ff-clarify.md: lite branch explicitly skips the two fields" \
  || err "commands/ff-clarify.md: lite branch must explicitly state it skips the two fields ('Lite tier skips them entirely')"

# --- AC5: ff-verify.md SM mapping bullet, presence-not-tier -------------------
grep -qE '### SM<n>' commands/ff-verify.md \
  && ok "commands/ff-verify.md: maps each Success-metrics row into its own '### SM<n>'" \
  || err "commands/ff-verify.md: must map each Success-metrics row into its own '### SM<n>' contract item"
flat < commands/ff-verify.md | grep -qiF 'presence check on the section' \
  && ok "commands/ff-verify.md: states presence-not-tier gating for SM" \
  || err "commands/ff-verify.md: must state SM is gated by a presence check on the section, not by tier"

# --- AC5 (template): verify.md SM1 block, digit-free (same shape as FS1) ------
smb="$(awk '/^### SM1:/{s=1} /^\*\*Bugfix track\*\*/{s=0} s' "$TPL_V")"
if [ -z "$smb" ]; then
  err "$TPL_V: must carry a '### SM1:' contract-mapping block"
else
  ok "$TPL_V: SM1 contract-mapping block present"
  for f in '\*\*Method:\*\*' '\*\*Evidence:\*\*' '\*\*Confidence:\*\*' '\*\*Gap'; do
    printf '%s\n' "$smb" | grep -qE "$f" \
      && ok "$TPL_V: SM block carries $f" \
      || err "$TPL_V: SM block must carry $f (same shape as the AC/FS block)"
  done
  # AC5/AC6 digit-free invariant (an unfilled SM placeholder must still DENY Gate B) is enforced
  # end-to-end against the REAL hook by enforce-gate-guard.sh's 'b-template' fixture, which copies
  # the whole templates/verify.md through hooks/enforce-gate — not re-implemented here with a
  # hand-copied regex that could drift (the WS-5 pin-against-shipped-template lesson).
fi

# --- AC7: ff-plan.md derivation bullet placement + plan.md table untouched ----
grep -qiF 'Derive requirement-graph task edges' commands/ff-plan.md \
  && ok "commands/ff-plan.md: carries the requirement-graph derivation bullet" \
  || err "commands/ff-plan.md: must carry the 'Derive requirement-graph task edges' bullet"
lmac=$(lineno commands/ff-plan.md 'Map every AC')
lrg=$(lineno commands/ff-plan.md 'Derive requirement-graph task edges')
ldpi=$(lineno commands/ff-plan.md 'Derive planning intelligence')
if [ -n "$lmac" ] && [ -n "$lrg" ] && [ -n "$ldpi" ] && [ "$lmac" -lt "$lrg" ] && [ "$lrg" -lt "$ldpi" ]; then
  ok "commands/ff-plan.md: requirement-graph bullet ($lrg) sits between 'Map every AC' ($lmac) and 'Derive planning intelligence' ($ldpi)"
else
  err "commands/ff-plan.md: requirement-graph bullet must sit between 'Map every AC' (${lmac:-?}) and 'Derive planning intelligence' (${ldpi:-?}); found ${lrg:-MISSING}"
fi
grep -qF '| Task | Depends on |' "$TPL_P" \
  && ok "$TPL_P: Dependency graph header UNCHANGED (no new column — derive-don't-widen)" \
  || err "$TPL_P: Dependency graph header must stay '| Task | Depends on |' unchanged"

# --- AC8: plan.md Outcome-gate requirement-graph coverage/gap rule ------------
flat < "$TPL_P" | grep -qiF 'Requirement-graph coverage' \
  && ok "$TPL_P: Outcome gate carries the requirement-graph coverage/gap rule" \
  || err "$TPL_P: Outcome gate must carry the requirement-graph coverage/gap rule"
flat < "$TPL_P" | grep -qiF 'covered by the same Task' \
  && ok "$TPL_P: names the un-derivable same-task-covers-both-ACs gap format" \
  || err "$TPL_P: must name the same-task-covers-both-ACs gap format"

# --- AC10: schema canonical section + subsections + ladder class -------------
grep -q '^## Discovery fields' "$SCHEMA" \
  && ok "$SCHEMA: '## Discovery fields' canonical section present" \
  || err "$SCHEMA: must define the '## Discovery fields' canonical section"
df="$(section "$SCHEMA" '^## Discovery fields')"
for h in 'Success metrics' 'Requirement graph' 'Actuation 1' 'Actuation 2' 'Tier / track scope' 'v1 non-goals'; do
  printf '%s' "$df" | grep -qF "### $h" \
    && ok "$SCHEMA §Discovery fields: '### $h' present" \
    || err "$SCHEMA §Discovery fields: must keep '### $h'"
done
ev="$(section "$SCHEMA" '^## Evidence$')"
printf '%s' "$ev" | flat | grep -qiF 'success metric' \
  && ok "$SCHEMA §Evidence: Confidence ladder names 'success metric' as a fourth contract-item class" \
  || err "$SCHEMA §Evidence: Confidence ladder must name 'success metric' as a contract-item class"

# --- AC9: no new config key / manifest field / §Autopilot row (negative) -----
grep -qiE 'successmetric|requirementgraph|discoveryfield' config/defaults.json \
  && err "config/defaults.json: must NOT gain a discovery-fields key (always-on)" \
  || ok "config/defaults.json: no new config key (always-on, as required)"
schema_json="$(awk '/^## Schema/{s=1;next} /^## Field notes/{s=0} s' "$SCHEMA")"
printf '%s\n' "$schema_json" | grep -qiE '"(successMetrics|requirementGraph|discoveryFields)"' \
  && err "$SCHEMA: manifest JSON schema must NOT gain a new top-level field for this workstream" \
  || ok "$SCHEMA: no new top-level manifest field"
ap="$(section "$SCHEMA" '^## Autopilot')"
printf '%s' "$ap" | flat | grep -qiE 'success metric stop|requirement graph stop' \
  && err "$SCHEMA §Autopilot: must NOT gain a new discovery-fields row (reuses Evidence gap stop / Outcome-gate gap)" \
  || ok "$SCHEMA §Autopilot: no new discovery-fields row (as required)"

# --- dist: Codex dist parity for every touched packaged file -----------------
DIST="dist/codex/feature-flow"
for rel in templates/spec.md templates/verify.md templates/plan.md \
           docs/manifest-schema.md commands/ff-clarify.md commands/ff-verify.md commands/ff-plan.md \
           skills/feature-flow/SKILL.md README.md; do
  if cmp -s "$rel" "$DIST/$rel"; then
    ok "dist parity: $rel"
  else
    err "dist parity: $rel differs from $DIST/$rel (re-run scripts/package-codex-plugin.sh)"
  fi
done

if [ "$fail" -eq 0 ]; then echo "PASS: discovery-fields guard"; else echo "RED: discovery-fields guard failed"; fi
exit "$fail"
