#!/usr/bin/env bash
# Regression guard (v0.20.0): fresh-context hand-offs + clarify interview + spec
# Touchpoints / End-to-end check. Pins STRUCTURE against the shipped files:
#   FC1  §Progress strip carries the fresh-context hint rule: step-by-step phase-end hand-offs
#        only; never in autopilot, never at a sign-off / decision / blocking pause.
#   FC2  every phase command that hands off to a next phase routes its message ending through
#        §Progress strip (so the one rule reaches all of them).
#   IV1  ff-clarify uses AskUserQuestion for closed-choice questions in BOTH modes; open-ended
#        probes stay plain text.
#   TP1  templates/spec.md carries '## Touchpoints' and '## End-to-end check' for BOTH tiers
#        (no full-tier banner), End-to-end check right after Acceptance criteria.
#   TP2  ff-clarify fills both (lite included).
#   TP3  ff-verify maps the End-to-end check into an '### E2E' contract item by a presence check;
#        templates/verify.md carries the '### E2E:' block (same shape as AC/SM blocks).
#   TP4  ff-review's spec-conformance reviewer reads Touchpoints as its scope reference.
#   TP5  schema §Discovery fields documents both, with their actuations.
#   dist Codex dist parity for every touched packaged file.
#
# Whether the model actually emits the hint / asks via AskUserQuestion / proves the E2E check on a
# live run is behavioral and not grep-checkable; this guard does not claim it.
set -u
cd "$(dirname "$0")/../.." || exit 2
fail=0
err() { echo "FAIL: $1"; fail=1; }
ok()  { echo "ok:   $1"; }

section() { awk -v re="$2" '$0 ~ "^## " && seen {exit} $0 ~ re {seen=1} seen' "$1"; }
lineno()  { grep -nE "$2" "$1" | head -1 | cut -d: -f1; }
flat()    { tr '\n' ' ' | tr -s '[:space:]' ' '; }
# need <label> <text> <fixed-string, case-insensitive>
need()    { printf '%s' "$2" | flat | grep -qiF -- "$3" && ok "$1" || err "$1 — missing '$3'"; }

. scripts/checks/lib/schema.sh
schema_join  # SCHEMA = the joined contract (temp file); SCHEMA_LABEL names it in messages
TPL_S="templates/spec.md"
TPL_V="templates/verify.md"

# --- FC1: the rule ------------------------------------------------------------
ps="$(section "$SCHEMA" '^## Progress strip')"
need "FC1: §Progress strip carries the fresh-context hint"          "$ps" 'Fresh context: `/clear`, then'
need "FC1: hint names the on-disk state"                            "$ps" "the run's state is on disk"
need "FC1: hint is step-by-step phase-end hand-offs only"           "$ps" 'step-by-step phase-end hand-off'
need "FC1: never in autopilot"                                      "$ps" 'never in autopilot'
need "FC1: never at a sign-off / decision / blocking pause"         "$ps" 'never at a sign-off'

# --- FC2: every hand-off routes through §Progress strip ------------------------
for c in ff ff-explore ff-clarify ff-design ff-plan ff-diagnose ff-implement ff-review ff-verify ff-resume; do
  flat < "commands/$c.md" | grep -qF '**Progress strip**' \
    && ok "FC2: commands/$c.md ends its hand-off via §Progress strip" \
    || err "FC2: commands/$c.md must reference **Progress strip** for its hand-off"
done

# --- IV1: AskUserQuestion in both modes ----------------------------------------
cl="$(cat commands/ff-clarify.md)"
need "IV1: ff-clarify asks closed-choice questions via AskUserQuestion in both modes" "$cl" 'AskUserQuestion in both modes'
need "IV1: open-ended probes stay plain text"                                     "$cl" 'open-ended probes stay plain text'

# --- TP1: template sections, both tiers, placement -----------------------------
for h in 'Touchpoints' 'End-to-end check'; do
  grep -qE "^## $h\$" "$TPL_S" && ok "TP1: $TPL_S has '## $h'" || err "TP1: $TPL_S must have '## $h'"
  section "$TPL_S" "^## $h\$" | flat | grep -qiF 'full tier only' \
    && err "TP1: '## $h' must apply to BOTH tiers (no full-tier-only banner)" \
    || ok "TP1: '## $h' applies to both tiers"
done
la=$(lineno "$TPL_S" '^## Acceptance criteria'); le=$(lineno "$TPL_S" '^## End-to-end check'); lm=$(lineno "$TPL_S" '^## Success metrics')
if [ -n "$la" ] && [ -n "$le" ] && [ -n "$lm" ] && [ "$la" -lt "$le" ] && [ "$le" -lt "$lm" ]; then
  ok "TP1: End-to-end check sits between Acceptance criteria and Success metrics"
else
  err "TP1: End-to-end check must sit between Acceptance criteria (${la:-?}) and Success metrics (${lm:-?}); found ${le:-MISSING}"
fi

# --- TP2: clarify fills both ------------------------------------------------------
need "TP2: ff-clarify fill-list names Touchpoints"       "$cl" '**Touchpoints**'
need "TP2: ff-clarify fill-list names End-to-end check"  "$cl" '**End-to-end check**'
need "TP2: lite tier still fills the End-to-end check"   "$cl" 'lite included'

# --- TP3: verify maps E2E ----------------------------------------------------------
vf="$(cat commands/ff-verify.md)"
grep -qE '### E2E' commands/ff-verify.md && ok "TP3: ff-verify maps the End-to-end check into '### E2E'" \
  || err "TP3: ff-verify must map the End-to-end check into an '### E2E' contract item"
printf '%s' "$vf" | flat | grep -qiE 'E2E.{0,120}exactly as an acceptance criterion' \
  && ok "TP3: E2E mapped exactly as an acceptance criterion" \
  || err "TP3: ff-verify must map E2E 'exactly as an acceptance criterion'"
printf '%s' "$vf" | flat | grep -qiE 'End-to-end check.{0,200}presence check' \
  && ok "TP3: E2E gated by a presence check on the section" \
  || err "TP3: ff-verify must gate E2E by a presence check on the '## End-to-end check' section"
eb="$(awk '/^### E2E:/{s=1;print;next} s && /^### /{exit} s' "$TPL_V")"
if [ -z "$eb" ]; then
  err "TP3: $TPL_V must carry an '### E2E:' contract-mapping block"
else
  for f in '\*\*Method:\*\*' '\*\*Evidence:\*\*' '\*\*Confidence:\*\*' '\*\*Gap'; do
    printf '%s\n' "$eb" | grep -qE "$f" && ok "TP3: E2E block carries $f" || err "TP3: E2E block must carry $f"
  done
fi

# TP3b: the E2E command actually reaches the one agent that gathers evidence — on lite too.
need "TP3b: ff-verify passes the End-to-end check row to ff-test-runner" "$vf" 'pass it verbatim to the runner'
tr_="$(cat agents/ff-test-runner.md)"
need "TP3b: ff-test-runner runs a provided end-to-end check"            "$tr_" 'If an end-to-end check is provided'
need "TP3b: …on a lite dispatch too (carve-out from floor-only)"         "$tr_" 'lite-tier dispatch too'
need "TP3b: ff-test-runner maps the end-to-end check as a contract item" "$tr_" 'the end-to-end check'
# TP3c: no applicable flow → an explicit none, which verify treats as absent (never a placeholder row).
need "TP3c: spec template allows an explicit none"  "$(section "$TPL_S" '^## End-to-end check$')" 'E2E: none'
need "TP3c: ff-verify treats E2E: none as absent"   "$vf" 'E2E: none'
# TP3d: downstream consumers enumerate E2E with the other contract-item classes.
need "TP3d: retro signal list names E2E"            "$(section "$SCHEMA" '^## Retrospective')" '`E2E`'
need "TP3d: repair-cycle trigger decides E2E/SM"    "$(section "$SCHEMA" '^## Autopilot')" 'end-to-end check'

# --- TP4: review scope reference -------------------------------------------------
need "TP4: spec-conformance reviewer reads Touchpoints" "$(section commands/ff-review.md '^## Spec conformance')" 'Touchpoints'

# --- TP5: schema contract ----------------------------------------------------------
df="$(section "$SCHEMA" '^## Discovery fields')"
for h in 'Touchpoints' 'End-to-end check' 'Actuation 3'; do
  printf '%s' "$df" | grep -qF "### $h" && ok "TP5: §Discovery fields has '### $h'" \
    || err "TP5: §Discovery fields must have '### $h'"
done
ev="$(section "$SCHEMA" '^## Evidence$')"
need "TP5: Confidence ladder names the end-to-end check as a contract-item class" "$ev" 'end-to-end check'

# --- dist parity -------------------------------------------------------------------
DIST="dist/codex/feature-flow"
for rel in docs/manifest-schema.md docs/schema/*.md "$TPL_S" "$TPL_V" commands/ff-clarify.md commands/ff-verify.md commands/ff-review.md; do
  cmp -s "$rel" "$DIST/$rel" && ok "dist parity: $rel" \
    || err "dist parity: $rel differs from $DIST/$rel (re-run scripts/package-codex-plugin.sh)"
done

if [ "$fail" -eq 0 ]; then echo "PASS: fresh-context-interview guard"; else echo "RED: fresh-context-interview guard failed"; fi
exit "$fail"
