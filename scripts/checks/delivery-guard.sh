#!/usr/bin/env bash
# Regression guard: WS-3 Delivery Intelligence (v0.12.0). Pins the STRUCTURAL acceptance
# criteria of the delivery feature (.feature-flow/ws3-delivery-intelligence):
#   AC1/AC2  templates/delivery.md carries the six sections in order; each CONSUMING section
#            has a '> ' guidance blockquote naming its upstream source.
#   AC3      ff-deliver.md resolves upstream via manifest.artifacts.<name> pointers, writes
#            phases.deliver + artifacts.delivery, and leaves currentPhase = "done".
#   AC4      ff-deliver.md is manual / non-gated (never autopilot-chained, lite-off, never blocks done).
#   AC5      ff-deliver.md carries the non-blocking DELIVERY GAP detection with the
#            irreversible-with-mitigation exclusion.
#   AC6      schema has a '## Delivery' section (phases.deliver + artifacts.delivery, absent-
#            defaulted); the currentPhase enum is NOT extended with 'deliver'; the durable set
#            includes 'delivery'.
#   AC8      the delivery-gap eval fixture exists.
#   AC9      SKILL.md + README.md reference ff-deliver.
#   dist     Codex dist parity for every touched packaged file.
#
# Behavioral AC5 (ff-deliver actually WRITING the gap line on a live run) is NOT grep-checkable
# and this guard deliberately does not assert it — that is a fresh-session self-run,
# manual-unverified, named in the 0.12.0 CHANGELOG (same posture as decision-record-guard.sh
# and planning-intelligence-guard.sh).
set -u
cd "$(dirname "$0")/../.." || exit 2
fail=0
err() { echo "FAIL: $1"; fail=1; }
ok()  { echo "ok:   $1"; }

# body of the first '## ' section whose heading matches, up to (excluding) the next '## '.
section() { awk -v re="$2" '$0 ~ "^## " && seen {exit} $0 ~ re {seen=1} seen' "$1"; }
lineno()  { grep -nE "$2" "$1" | head -1 | cut -d: -f1; }

. scripts/checks/lib/schema.sh
schema_join  # SCHEMA = the joined contract (temp file); SCHEMA_LABEL names it in messages
TPL="templates/delivery.md"
CMD="commands/ff-deliver.md"

# --- AC1/AC2: template six sections, in order, consuming sections carry a '> ' blockquote ----
[ -f "$TPL" ] || err "$TPL: template must exist"
lr=$(lineno "$TPL" '^## Release notes')
ld=$(lineno "$TPL" '^## Deployment checklist')
lb=$(lineno "$TPL" '^## Rollback checklist')
lm=$(lineno "$TPL" '^## Migration notes')
lk=$(lineno "$TPL" '^## Known issues')
lv=$(lineno "$TPL" '^## Release validation steps')
if [ -n "$lr" ] && [ -n "$ld" ] && [ -n "$lb" ] && [ -n "$lm" ] && [ -n "$lk" ] && [ -n "$lv" ] \
   && [ "$lr" -lt "$ld" ] && [ "$ld" -lt "$lb" ] && [ "$lb" -lt "$lm" ] \
   && [ "$lm" -lt "$lk" ] && [ "$lk" -lt "$lv" ]; then
  ok "$TPL: six sections present, in order"
else
  err "$TPL: six sections must be present in order (RelNotes=$lr Deploy=$ld Rollback=$lb Migration=$lm Known=$lk Validation=$lv)"
fi
for h in '^## Release notes' '^## Rollback checklist' '^## Known issues' '^## Release validation steps'; do
  printf '%s\n' "$(section "$TPL" "$h")" | grep -q '^> ' \
    && ok "$TPL: '${h#^## }' carries a '> ' source blockquote" \
    || err "$TPL: '${h#^## }' must carry a '> ' blockquote naming its upstream source"
done

# --- AC3: command resolves via pointers, writes phases.deliver, leaves currentPhase done -----
[ -f "$CMD" ] || err "$CMD: command must exist"
for ptr in 'artifacts.spec' 'artifacts.plan' 'artifacts.verify'; do
  grep -qF "$ptr" "$CMD" && ok "$CMD: resolves via $ptr" || err "$CMD: must resolve upstream via $ptr"
done
grep -qF 'phases.deliver' "$CMD" && ok "$CMD: writes phases.deliver" || err "$CMD: must set phases.deliver"
grep -qF 'artifacts.delivery' "$CMD" && ok "$CMD: records artifacts.delivery" || err "$CMD: must record artifacts.delivery"
grep -qiE 'currentPhase = "done"|currentPhase.*stays.*done|stays .*"done"' "$CMD" \
  && ok "$CMD: leaves currentPhase = \"done\"" \
  || err "$CMD: must state currentPhase stays \"done\" (never re-enters a phase)"

# --- AC4: manual / non-gated ----------------------------------------------------------------
grep -qiE 'never chain|autopilot never|invoked by hand|non-gated' "$CMD" \
  && ok "$CMD: manual / non-gated (autopilot never chains it)" \
  || err "$CMD: must state it is non-gated and never autopilot-chained"
grep -qi 'lite' "$CMD" && ok "$CMD: gates off tier: lite unless requested" || err "$CMD: must gate off tier: lite unless requested"
grep -qi 'never blocks' "$CMD" && ok "$CMD: states it never blocks done" || err "$CMD: must state it never blocks done"

# --- AC5: delivery-gap detection (non-blocking) + irreversible-mitigation exclusion ---------
grep -qiF 'DELIVERY GAP' "$CMD" && ok "$CMD: carries the DELIVERY GAP detection" || err "$CMD: must carry the DELIVERY GAP detection"
grep -qi 'irreversible: mitigation' "$CMD" \
  && ok "$CMD: excludes an irreversible-with-mitigation task from the gap" \
  || err "$CMD: must exclude an 'irreversible: mitigation is <X>' task from the gap"

# --- AC6: schema §Delivery + fields + enum unchanged + durable set --------------------------
grep -q '^## Delivery' "$SCHEMA" && ok "$SCHEMA_LABEL: '## Delivery' section present" || err "$SCHEMA_LABEL: must define '## Delivery'"
dv="$(section "$SCHEMA" '^## Delivery')"
printf '%s\n' "$dv" | grep -qF 'phases.deliver'    && ok "$SCHEMA_LABEL §Delivery: documents phases.deliver"    || err "$SCHEMA_LABEL §Delivery: must document phases.deliver"
printf '%s\n' "$dv" | grep -qF 'artifacts.delivery' && ok "$SCHEMA_LABEL §Delivery: documents artifacts.delivery" || err "$SCHEMA_LABEL §Delivery: must document artifacts.delivery"
printf '%s\n' "$dv" | grep -qi 'absent'             && ok "$SCHEMA_LABEL §Delivery: states the absent-field default" || err "$SCHEMA_LABEL §Delivery: must state the absent-field default"
enum="$(grep -E '"currentPhase":' "$SCHEMA" | head -1)"
printf '%s\n' "$enum" | grep -q 'deliver' \
  && err "$SCHEMA_LABEL: currentPhase enum must NOT contain 'deliver' (done is the immutable terminal)" \
  || ok "$SCHEMA_LABEL: currentPhase enum correctly omits 'deliver'"
grep -qF '`verify`, `delivery`' "$SCHEMA" \
  && ok "$SCHEMA_LABEL: durable-eligible set includes 'delivery'" \
  || err "$SCHEMA_LABEL: durable-eligible artifact set must include 'delivery'"

# --- AC9: SKILL + README reference ff-deliver -----------------------------------------------
grep -q 'ff-deliver' skills/feature-flow/SKILL.md && ok "SKILL.md references ff-deliver" || err "SKILL.md must reference ff-deliver"
grep -q 'ff-deliver' README.md                    && ok "README.md references ff-deliver" || err "README.md command table must reference ff-deliver"

# --- AC8: eval fixture present --------------------------------------------------------------
[ -f evals/fixtures/delivery-gap/plan.md ] \
  && ok "delivery-gap eval fixture present" \
  || err "evals/fixtures/delivery-gap/plan.md must exist (WS-8 fixture for the gap actuation)"

# --- dist parity: every touched packaged file -----------------------------------------------
DIST="dist/codex/feature-flow"
for rel in commands/ff-deliver.md templates/delivery.md docs/manifest-schema.md \
           skills/feature-flow/SKILL.md README.md; do
  if diff -q "$rel" "$DIST/$rel" >/dev/null 2>&1; then
    ok "dist parity: $rel"
  else
    err "dist parity: $rel differs from $DIST/$rel (re-run scripts/package-codex-plugin.sh)"
  fi
done

if [ "$fail" -eq 0 ]; then echo "PASS: delivery guard"; else echo "RED: delivery guard failed"; fi
exit "$fail"
