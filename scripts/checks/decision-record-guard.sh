#!/usr/bin/env bash
# Regression guard: Structured Decision Records (record → recall → enforce) must be
# structurally wired. Pins the STRUCTURAL acceptance criteria of the decision-records
# feature (.feature-flow/decision-records, v0.10.0):
#   AC1  templates/decision.md carries its field/section headers (grepped against the
#        VERBATIM shipped template — no hand-typed fixture that could drift; the
#        pin-hook-checks-against-shipped-template lesson).
#   AC2  schema: `decision` in the durable list + the disk-inference tuple, and an
#        `artifacts.decision` absent-field-default note.
#   AC3/AC4  ff-design writes the decision + carries the prior-decision do-not-contradict STOP.
#   AC5  ff-implement has a '## Decision recall' section (between Cold-start and Do the work)
#        that reads via artifacts.decision, gates its cross-run half on toggles.kb, and STOPs.
#   AC6  ff-clarify's lite branch sets artifacts.decision (= the spec pointer).
#   AC7  the Autopilot mandatory-pauses table has an unconditional Decision-conflict row.
#   AC8  the do-not-contradict STOP INSTRUCTION survives in BOTH command files (a structural
#        regression guard against silent deletion — NOT proof the semantic catch fires; that
#        is AC13, manual/self-run, named in the 0.10.0 CHANGELOG).
#
# Behavioral ACs are NOT grep-checkable and this guard deliberately does not assert them:
# a full-tier run actually writes a promoted decision record (AC3 live), the recall actually
# surfaces it, and the STOP actually fires on a contradicting approach (AC13). Those are the
# Task 11 live self-run, manual-unverified until then — exactly like kb-guard's behavioral ACs.
set -u
cd "$(dirname "$0")/../.." || exit 2
fail=0
err() { echo "FAIL: $1"; fail=1; }
ok()  { echo "ok:   $1"; }

# section <file> <start-heading-ERE>: body of the first '## ' section whose heading matches,
# up to (excluding) the next '## '. '### ' sub-headings stay inside.
section() { awk -v re="$2" '$0 ~ "^## " && seen {exit} $0 ~ re {seen=1} seen' "$1"; }

SCHEMA="docs/manifest-schema.md"
TPL="templates/decision.md"

# --- (a) AC1: template headers/fields (verbatim shipped template) ------------
[ -f "$TPL" ] && ok "$TPL: present" || err "$TPL: template must exist"
for h in '^## Decision' '^## Context' '^## Options considered' '^## Trade-offs' \
         '^## Chosen \+ rationale' '^## Outcome' '^## Future considerations'; do
  grep -qE "$h" "$TPL" \
    && ok "$TPL: section '${h#^}' present" \
    || err "$TPL: must keep the '${h#^}' section"
done
for lit in '**Related ACs:**' '**Related files:**' '| Option | Effort | Risk | Reversibility |'; do
  grep -qF "$lit" "$TPL" \
    && ok "$TPL: carries '$lit'" \
    || err "$TPL: must carry '$lit'"
done
# frontmatter provenance the recall/tag-match machinery reads
for f in tags referencedFiles; do
  grep -q "$f" "$TPL" \
    && ok "$TPL: frontmatter field $f present" \
    || err "$TPL: frontmatter must carry the $f field (recall tag-match / staleness)"
done

# --- (b) AC2: schema wiring --------------------------------------------------
# durable-artifact list names `decision`
awk '/maps logical names/,/## Run resolution/' "$SCHEMA" | grep -qE 'Durable artifacts' \
  && ok "$SCHEMA: durable-artifacts list present" \
  || err "$SCHEMA: must have the Durable artifacts list"
grep -qE '`spec`, `design`, `decision`, `plan`' "$SCHEMA" \
  && ok "$SCHEMA: durable list includes decision" \
  || err "$SCHEMA: durable-artifacts list must include \`decision\`"
# disk-inference phase tuple names decision
section "$SCHEMA" '^## Disk inference procedure' | grep -q 'design`, `decision`' \
  && ok "$SCHEMA: disk-inference tuple includes decision" \
  || err "$SCHEMA: disk-inference phase tuple must include \`decision\`"
# artifacts.decision field note + absent-field default
grep -q 'artifacts.decision' "$SCHEMA" \
  && ok "$SCHEMA: documents artifacts.decision" \
  || err "$SCHEMA: must document artifacts.decision"
grep -qiE 'no decision recorded' "$SCHEMA" \
  && ok "$SCHEMA: artifacts.decision absent-field default documented" \
  || err "$SCHEMA: must document the artifacts.decision absent-field default (no decision recorded)"
# canonical Decision recall subsection
grep -q '^### Decision recall' "$SCHEMA" \
  && ok "$SCHEMA: '### Decision recall' canonical subsection present" \
  || err "$SCHEMA: must define the '### Decision recall' subsection"
# override recording string, canonical
grep -qF 'Decision override by user' "$SCHEMA" \
  && ok "$SCHEMA: names the Decision override by user (<date>) recording" \
  || err "$SCHEMA: must name the 'Decision override by user (<date>): <reason>' override recording"

# --- (c) AC3: ff-design writes the decision ---------------------------------
grep -q 'artifacts.decision' commands/ff-design.md \
  && ok "commands/ff-design.md: records artifacts.decision" \
  || err "commands/ff-design.md: must record the decision path in artifacts.decision"
grep -qF 'templates/decision.md' commands/ff-design.md \
  && ok "commands/ff-design.md: writes the decision from templates/decision.md" \
  || err "commands/ff-design.md: must write the decision from templates/decision.md"

# --- (d) AC4 + (i) AC8: do-not-contradict STOP survives in BOTH commands -----
grep -qiF 'do-not-contradict' commands/ff-design.md \
  && ok "commands/ff-design.md: do-not-contradict STOP instruction present (AC4/AC8)" \
  || err "commands/ff-design.md: the do-not-contradict STOP instruction must survive (AC4/AC8)"
grep -qiF 'do-not-contradict' commands/ff-implement.md \
  && ok "commands/ff-implement.md: do-not-contradict STOP instruction present (AC5/AC8)" \
  || err "commands/ff-implement.md: the do-not-contradict STOP instruction must survive (AC5/AC8)"

# --- (e) AC5: ff-implement '## Decision recall' section + placement ----------
dr="$(section commands/ff-implement.md '^## Decision recall')"
if [ -z "$dr" ]; then
  err "commands/ff-implement.md: missing the '## Decision recall' section"
else
  ok "commands/ff-implement.md: has a '## Decision recall' section"
  printf '%s\n' "$dr" | grep -q 'artifacts.decision' \
    && ok "commands/ff-implement.md §Decision recall: resolves via artifacts.decision" \
    || err "commands/ff-implement.md §Decision recall: must resolve via artifacts.decision (not a bare filename)"
  printf '%s\n' "$dr" | grep -q 'toggles.kb' \
    && ok "commands/ff-implement.md §Decision recall: cross-run half gates on toggles.kb" \
    || err "commands/ff-implement.md §Decision recall: cross-run half must gate on toggles.kb"
  printf '%s\n' "$dr" | grep -qi 'unconditional' \
    && ok "commands/ff-implement.md §Decision recall: STOP is unconditional in both modes" \
    || err "commands/ff-implement.md §Decision recall: STOP must be unconditional in both modes"
fi
# placement: '## Decision recall' strictly between '## Cold-start' and '## Do the work'
lc=$(grep -nE '^## Cold-start' commands/ff-implement.md | head -1 | cut -d: -f1)
ld=$(grep -nE '^## Decision recall' commands/ff-implement.md | head -1 | cut -d: -f1)
lw=$(grep -nE '^## Do the work' commands/ff-implement.md | head -1 | cut -d: -f1)
if [ -n "$lc" ] && [ -n "$ld" ] && [ -n "$lw" ] && [ "$lc" -lt "$ld" ] && [ "$ld" -lt "$lw" ]; then
  ok "commands/ff-implement.md: '## Decision recall' ($ld) sits between Cold-start ($lc) and Do the work ($lw)"
else
  err "commands/ff-implement.md: '## Decision recall' must sit between '## Cold-start' (${lc:-?}) and '## Do the work' (${lw:-?}); found ${ld:-MISSING}"
fi

# --- (f) AC6: ff-clarify lite sets artifacts.decision -----------------------
grep -q 'artifacts.decision' commands/ff-clarify.md \
  && ok "commands/ff-clarify.md: lite branch sets artifacts.decision" \
  || err "commands/ff-clarify.md: lite branch must set artifacts.decision (= the spec pointer)"

# --- (g) AC7: Autopilot mandatory-pauses row --------------------------------
ap="$(section "$SCHEMA" '^## Autopilot')"
printf '%s\n' "$ap" | grep -qi 'Decision conflict stop' \
  && ok "$SCHEMA §Autopilot: has the Decision conflict stop row" \
  || err "$SCHEMA §Autopilot: mandatory-pauses table must have a Decision conflict stop row"
printf '%s\n' "$ap" | grep -qi 'Decision conflict stop' && \
printf '%s\n' "$ap" | awk 'tolower($0) ~ /decision conflict stop/' | grep -qi 'unconditional' \
  && ok "$SCHEMA §Autopilot: Decision conflict stop is unconditional" \
  || err "$SCHEMA §Autopilot: the Decision conflict stop row must state it is unconditional"

# --- (h) Codex dist parity: the new template + edited packaged files ---------
# scripts/ is excluded from the package, so this guard is never in dist/.
DIST="dist/codex/feature-flow"
for rel in \
  templates/decision.md \
  docs/manifest-schema.md \
  commands/ff-design.md \
  commands/ff-implement.md \
  commands/ff-clarify.md
do
  if diff -q "$rel" "$DIST/$rel" >/dev/null 2>&1; then
    ok "dist parity: $rel"
  else
    err "dist parity: $rel differs from $DIST/$rel (re-run scripts/package-codex-plugin.sh)"
  fi
done

if [ "$fail" -eq 0 ]; then echo "PASS: decision-record guard"; else echo "RED: decision-record guard failed"; fi
exit "$fail"
