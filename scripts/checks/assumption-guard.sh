#!/usr/bin/env bash
# Regression guard: WS-4 Structured Assumption Records must stay structurally wired.
# Pins the STRUCTURAL acceptance criteria of the assumption-records feature
# (.feature-flow/ws4-assumption-records, v0.13.0) by grepping the VERBATIM SHIPPED
# templates/commands/schema — never a hand-typed fixture string (the pin-against-shipped
# lesson from evidence-based-verification):
#   AC1     templates/spec.md's '## Assumptions (WHAT-changing)' is the 5-column table.
#   AC2     templates/diagnosis.md gains an '## Assumptions' 5-column table, full-tier
#           banner, positioned after '## Fix approach' and before '## Fix surface'.
#   AC3     ff-clarify.md Beat 4 writes each assumption as a table row (five fields).
#   AC4     ff-diagnose.md surfaces rows on the full tier and explicitly skips on lite.
#   AC5     schema §Sign-off rendering is 'Three rules', with rule 3 echoing unvalidated
#           assumptions as a DISTINCT block 'never folded into' the AC checkboxes, and a
#           worked '### Unvalidated assumptions' example.
#   AC8     the verbatim waiver line 'Assumption validation waived by user (<date>):
#           <reason>' is present in the schema + both commands, and §Autopilot gains an
#           'Assumption validation stop' row.
#   AC9/AC10 templates/plan.md documents the '**Validates:** Assumption N' mapping rule
#           (+ a task example) and ff-plan.md emits the validation task, between the
#           AC-map bullet and 'Derive planning intelligence'.
#   canonical '## Assumption records' section + its subsections.
#   dist    per-file Codex dist parity for every edited packaged file.
#
# DELIBERATELY NOT ASSERTED: the word "unconditional" on the WS-4 §Autopilot row. WS-4's
# actuation is the Evidence-gap-stop SHAPE (turn-ending, waivable) — NOT the
# do-not-contradict STOP — so "unconditional" is the wrong marker for this row. This guard
# does not require it, and does not forbid it either (a legitimate negation could name the
# word); the row wording is policed by review + the spec's Task-1 Step-4 grep, not here.
#
# Behavioral AC6/AC7 (the echo actually RENDERS and BLOCKS a clean sign-off, and the clean
# control does NOT false-fire) are NOT grep-checkable and this guard deliberately does not
# assert them — a fresh-session STOP-vs-control self-run, named in the 0.13.0 CHANGELOG
# (same posture as planning-intelligence-guard.sh's AC15).
set -u
cd "$(dirname "$0")/../.." || exit 2
fail=0
err() { echo "FAIL: $1"; fail=1; }
ok()  { echo "ok:   $1"; }

# section <file> <start-heading-ERE>: body of the first '## ' section whose heading matches,
# up to (excluding) the next '## '. '### ' sub-headings stay inside.
section() { awk -v re="$2" '$0 ~ "^## " && seen {exit} $0 ~ re {seen=1} seen' "$1"; }
lineno()  { grep -nE "$2" "$1" | head -1 | cut -d: -f1; }
# flat: collapse newlines + repeated whitespace on stdin to single spaces, so a prose phrase
# that wrapped across a line break still matches — a guard over prose must survive a reflow.
flat()    { tr '\n' ' ' | tr -s '[:space:]' ' '; }

. scripts/checks/lib/schema.sh
schema_join  # SCHEMA = the joined contract (temp file); SCHEMA_LABEL names it in messages
HEADER='| Statement | Confidence | Basis / evidence | If-wrong impact | Validation-required |'

# --- AC1: spec template table ------------------------------------------------
sp="$(section templates/spec.md '^## Assumptions [(]WHAT-changing[)]')"  # [(] not \( — portable across mawk/gawk (mawk strips \( → regex group, breaking the match; see CI run #21)
if [ -z "$sp" ]; then
  err "templates/spec.md: missing the '## Assumptions (WHAT-changing)' section"
else
  printf '%s' "$sp" | grep -qF "$HEADER" \
    && ok "templates/spec.md: Assumptions is the 5-column table" \
    || err "templates/spec.md: Assumptions must carry the 5-column header ($HEADER)"
fi

# --- AC2: diagnosis template table, banner, placement ------------------------
dg="$(section templates/diagnosis.md '^## Assumptions')"
if [ -z "$dg" ]; then
  err "templates/diagnosis.md: missing the '## Assumptions' section"
else
  printf '%s' "$dg" | grep -qF "$HEADER" \
    && ok "templates/diagnosis.md: Assumptions is the identical 5-column table" \
    || err "templates/diagnosis.md: Assumptions must carry the 5-column header ($HEADER)"
  printf '%s' "$dg" | flat | grep -qiF 'full tier only' \
    && ok "templates/diagnosis.md: Assumptions carries the full-tier-only banner" \
    || err "templates/diagnosis.md: Assumptions must carry a full-tier-only banner"
fi
lfa=$(lineno templates/diagnosis.md '^## Fix approach')
las=$(lineno templates/diagnosis.md '^## Assumptions')
lfs=$(lineno templates/diagnosis.md '^## Fix surface')
if [ -n "$lfa" ] && [ -n "$las" ] && [ -n "$lfs" ] && [ "$lfa" -lt "$las" ] && [ "$las" -lt "$lfs" ]; then
  ok "templates/diagnosis.md: '## Assumptions' sits after '## Fix approach' and before '## Fix surface'"
else
  err "templates/diagnosis.md: '## Assumptions' must sit between '## Fix approach' ($lfa) and '## Fix surface' ($lfs); found $las"
fi

# --- AC3: ff-clarify writes rows ---------------------------------------------
flat < commands/ff-clarify.md | grep -qiF 'each surviving assumption as a table row' \
  && ok "commands/ff-clarify.md: Beat 4 writes each assumption as a table row" \
  || err "commands/ff-clarify.md: Beat 4 must instruct writing each assumption as a table row"
grep -qF 'Validation-required' commands/ff-clarify.md \
  && ok "commands/ff-clarify.md: names the Validation-required field" \
  || err "commands/ff-clarify.md: must name the Validation-required field"

# --- AC4: ff-diagnose full-tier rows + lite skip -----------------------------
flat < commands/ff-diagnose.md | grep -qiF 'record every WHAT-changing assumption' \
  && ok "commands/ff-diagnose.md: full-tier fix-approach step surfaces assumption rows" \
  || err "commands/ff-diagnose.md: must surface assumptions into the diagnosis table (full tier)"
flat < commands/ff-diagnose.md | grep -qiF 'skip this entirely' \
  && ok "commands/ff-diagnose.md: lite tier explicitly skips the assumptions table" \
  || err "commands/ff-diagnose.md: must explicitly skip the assumptions table on the lite tier"

# --- AC5: §Sign-off rendering rule 3 -----------------------------------------
sor="$(section "$SCHEMA" '^## Sign-off rendering')"
printf '%s' "$sor" | flat | grep -qiF 'Three rules' \
  && ok "$SCHEMA_LABEL §Sign-off rendering: is 'Three rules'" \
  || err "$SCHEMA_LABEL §Sign-off rendering: must be bumped to 'Three rules'"
printf '%s' "$sor" | flat | grep -qiF 'never folded into' \
  && ok "$SCHEMA_LABEL §Sign-off rendering: rule 3 echo is a distinct block, never folded into the AC checkboxes" \
  || err "$SCHEMA_LABEL §Sign-off rendering: rule 3 must state the echo is 'never folded into' the AC checkboxes"
printf '%s' "$sor" | grep -qF '### Unvalidated assumptions' \
  && ok "$SCHEMA_LABEL §Sign-off rendering: carries a worked '### Unvalidated assumptions' example" \
  || err "$SCHEMA_LABEL §Sign-off rendering: must show a worked '### Unvalidated assumptions' block"

# --- AC8: verbatim waiver line across surfaces + Autopilot row ---------------
WAIVER='Assumption validation waived by user (<date>): <reason>'
for f in "$SCHEMA" commands/ff-clarify.md commands/ff-diagnose.md; do
  l="$f"; [ "$f" = "$SCHEMA" ] && l="$SCHEMA_LABEL"
  flat < "$f" | grep -qF "$WAIVER" \
    && ok "$l: carries the verbatim waiver line" \
    || err "$l: must carry the verbatim '$WAIVER' line"
done
ap="$(section "$SCHEMA" '^## Autopilot')"
printf '%s' "$ap" | flat | grep -qiF 'Assumption validation stop' \
  && ok "$SCHEMA_LABEL §Autopilot: has the 'Assumption validation stop' row" \
  || err "$SCHEMA_LABEL §Autopilot: mandatory-pauses table must have an 'Assumption validation stop' row"

# --- canonical §Assumption records section + subsections ---------------------
grep -q '^## Assumption records' "$SCHEMA" \
  && ok "$SCHEMA_LABEL: '## Assumption records' canonical section present" \
  || err "$SCHEMA_LABEL: must define the '## Assumption records' canonical section"
ar="$(section "$SCHEMA" '^## Assumption records')"
for h in 'Row schema' 'Tier / track scope' 'Trigger' 'Actuation 1' 'Actuation 2' 'Waiver' 'v1 non-goals'; do
  printf '%s' "$ar" | grep -qF "### $h" \
    && ok "$SCHEMA_LABEL §Assumption records: '### $h' present" \
    || err "$SCHEMA_LABEL §Assumption records: must keep '### $h'"
done
# Reconciliation (2026-07-06): Actuation 1 must name the THIRD gate exit (acknowledge-open),
# not the binary validate-or-waive rule — pins the fix for the AC6-vs-AC9/AC10 contradiction
# so the gate cannot silently regress and strand Actuation 2's plan-task path.
printf '%s' "$ar" | flat | grep -qiF 'acknowledge it stays open' \
  && ok "$SCHEMA_LABEL §Assumption records: Actuation 1 names the third gate exit (acknowledge-open)" \
  || err "$SCHEMA_LABEL §Assumption records: Actuation 1 must name the third gate exit (acknowledge-open), not a binary validate-or-waive gate"
# Waiver disambiguation (2026-07-06, fix (a)): a waiver marks the row `n`, so validate+waive both
# collapse to `n` and a surviving `validation-required: y` is unambiguously an acknowledged-open row.
# Pins the fix for the waived-vs-acknowledged-open on-disk ambiguity (Actuation 2 could otherwise
# strand an assumption — WS-4's own anti-pattern) so the gate cannot silently regress to a `y`-waiver.
printf '%s' "$ar" | flat | grep -qiF 'waive both set `n`' \
  && ok "$SCHEMA_LABEL §Assumption records: Waiver marks the row \`n\` (waived vs acknowledged-open disambiguated on disk)" \
  || err "$SCHEMA_LABEL §Assumption records: Waiver must mark the row \`n\` (validate and waive both set \`n\`) so a surviving \`y\` is unambiguously acknowledged-open"

# --- AC9: templates/plan.md mapping rule + example ---------------------------
flat < templates/plan.md | grep -qF '**Validates:** Assumption N' \
  && ok "templates/plan.md: documents the '**Validates:** Assumption N' mapping rule" \
  || err "templates/plan.md: must document the '**Validates:** Assumption N' mapping rule"
grep -qE '\*\*Validates:\*\* Assumption [0-9]' templates/plan.md \
  && ok "templates/plan.md: carries a '**Validates:** Assumption <n>' task example" \
  || err "templates/plan.md: must carry a '**Validates:** Assumption <n>' task example"

# --- AC10: ff-plan emits the validation task, correctly placed ---------------
flat < commands/ff-plan.md | grep -qF '**Validates:** Assumption N' \
  && ok "commands/ff-plan.md: emits a '**Validates:** Assumption N' validation task" \
  || err "commands/ff-plan.md: must emit a '**Validates:** Assumption N' validation task"
lam=$(lineno commands/ff-plan.md 'Map every AC')
lvm=$(lineno commands/ff-plan.md 'Map every unvalidated assumption')
ldp=$(lineno commands/ff-plan.md 'Derive planning intelligence')
if [ -n "$lam" ] && [ -n "$lvm" ] && [ -n "$ldp" ] && [ "$lam" -lt "$lvm" ] && [ "$lvm" -lt "$ldp" ]; then
  ok "commands/ff-plan.md: assumption-mapping bullet sits between AC-map ($lam) and Derive planning intelligence ($ldp)"
else
  err "commands/ff-plan.md: assumption-mapping bullet must sit between AC-map (${lam:-?}) and Derive planning intelligence (${ldp:-?}); found ${lvm:-MISSING}"
fi

# --- dist parity: every edited packaged file ---------------------------------
DIST="dist/codex/feature-flow"
for rel in templates/spec.md templates/diagnosis.md templates/plan.md \
           docs/manifest-schema.md commands/ff-clarify.md commands/ff-diagnose.md commands/ff-plan.md; do
  if cmp -s "$rel" "$DIST/$rel"; then
    ok "dist parity: $rel"
  else
    err "dist parity: $rel differs from $DIST/$rel (re-run scripts/package-codex-plugin.sh)"
  fi
done

if [ "$fail" -eq 0 ]; then echo "PASS: assumption-records guard"; else echo "RED: assumption-records guard failed"; fi
exit "$fail"
