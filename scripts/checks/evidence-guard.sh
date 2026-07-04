#!/usr/bin/env bash
# Regression guard: the v0.5.0 evidence guardrails must stay structurally wired.
# Pins the STRUCTURAL additions of the evidence-lean change
# (docs/feature-flow/2026-06-24-v0.5.0-evidence-lean): AC traceability (plan.md
# `**Covers:**` + Outcome-gate rule, ff-plan feature-scoped instruction), regression
# risk (verify.md section + ff-verify instruction), and root-cause candidate ranking
# (diagnosis.md candidates + confirmed split, ff-diagnose full-tier instruction). Also
# pins the AC4 invariant — the diagnosis sign-off echo still names "root cause" — and
# template dist parity (commands are already covered by durable-paths/kb guards).
#
# Behavioral quality (whether a planner actually maps every AC, whether candidates are
# genuinely weighed) is NOT grep-checkable; this guard only proves the scaffolding a
# later edit could silently delete is still present — same scope as the other guards.
set -u
cd "$(dirname "$0")/../.." || exit 2
fail=0
err() { echo "FAIL: $1"; fail=1; }
ok()  { echo "ok:   $1"; }

DIST="dist/codex/feature-flow"
parity() { # parity <repo-relative-path>
  cmp -s "$1" "$DIST/$1" \
    && ok "dist parity: $1" \
    || err "dist parity: $1 differs from $DIST/$1 (re-run scripts/package-codex-plugin.sh)"
}

# --- (a) AC traceability (feature track) ------------------------------------
grep -q '\*\*Covers:\*\*' templates/plan.md \
  && ok "templates/plan.md: task template has a **Covers:** field" \
  || err "templates/plan.md: task template must keep the **Covers:** AC field"
grep -qi 'every spec AC maps to' templates/plan.md \
  && ok "templates/plan.md: Outcome gate requires every AC mapped/flagged" \
  || err "templates/plan.md: Outcome gate must require every spec AC map to >=1 task"
grep -qi 'Map every AC (feature track)' commands/ff-plan.md \
  && ok "commands/ff-plan.md: AC-mapping instruction present, feature-scoped" \
  || err "commands/ff-plan.md: must instruct 'Map every AC (feature track)' (bugfix has no spec)"

# --- (b) regression risk in verification ------------------------------------
grep -q '^## Regression risk' templates/verify.md \
  && ok "templates/verify.md: '## Regression risk' section present" \
  || err "templates/verify.md: must keep the '## Regression risk' section"
grep -qi 'regression risk' commands/ff-verify.md \
  && ok "commands/ff-verify.md: regression-risk instruction present" \
  || err "commands/ff-verify.md: must instruct recording regression risk in verify.md"

# --- (c) root-cause candidate ranking (full tier) ---------------------------
grep -q '^## Root cause candidates' templates/diagnosis.md \
  && ok "templates/diagnosis.md: '## Root cause candidates' section present" \
  || err "templates/diagnosis.md: must keep the '## Root cause candidates' section"
grep -q '^## Confirmed root cause' templates/diagnosis.md \
  && ok "templates/diagnosis.md: '## Confirmed root cause' section present" \
  || err "templates/diagnosis.md: must keep '## Confirmed root cause' (AC4 sign-off echo)"
grep -qi 'root-cause candidates' commands/ff-diagnose.md \
  && ok "commands/ff-diagnose.md: full-tier candidate instruction present" \
  || err "commands/ff-diagnose.md: must instruct >=2 root-cause candidates on the full tier"

# --- (d) AC4 invariant: the diagnosis sign-off echo still names "root cause" -
grep -q 'root cause, fix surface, regression-test plan' commands/ff-diagnose.md \
  && ok "commands/ff-diagnose.md: sign-off echo still lists 'root cause' (AC4)" \
  || err "commands/ff-diagnose.md: sign-off echo must still name 'root cause' (maps to Confirmed root cause)"

# --- (e) template dist parity (commands covered by other guards) ------------
parity templates/plan.md
parity templates/verify.md
parity templates/diagnosis.md

# ============================================================================
# v0.9.0 evidence-based verification (docs/feature-flow/2026-07-04-evidence-
# based-verification): canonical §Evidence contract, widened ff-test-runner,
# client-grade verify.md, gap/waiver stop, Gate B content check. Same scope
# rule as above: structural pins only; behavioral quality is not grep-checkable.
# ============================================================================
SCHEMA="docs/manifest-schema.md"

# section <file> <start-heading-ERE> : print the body of the first '## ' section whose
# heading matches the regex, up to (excluding) the next '## ' heading. Scopes a grep to
# exactly that section. '### ' sub-headings stay inside (only '## ' ends a section).
section() { awk -v re="$2" '$0 ~ "^## " && seen {exit} $0 ~ re {seen=1} seen' "$1"; }

# --- (f) canonical §Evidence section (AC1) -----------------------------------
EV="$(section "$SCHEMA" '^## Evidence$')"
[ -n "$EV" ] \
  && ok "$SCHEMA: '## Evidence' canonical section present" \
  || err "$SCHEMA: must contain the canonical '## Evidence' section"
for h in 'Evidence-kind taxonomy' 'Evidence record shape' 'Evidence directory' \
         'Confidence ladder' 'Detection and N/A rule' 'Evidence waiver' \
         'Tier scaling' 'Adding an evidence kind' 'v1 non-goals'; do
  printf '%s' "$EV" | grep -qF "### $h" \
    && ok "$SCHEMA §Evidence: '### $h' subsection present" \
    || err "$SCHEMA §Evidence: must keep the '### $h' subsection"
done
printf '%s' "$EV" | grep -qF '{kind, command, actual exit/HTTP status, excerpt, artifact paths}' \
  && ok "$SCHEMA §Evidence: evidence record shape stated literally" \
  || err "$SCHEMA §Evidence: must state the record shape {kind, command, actual exit/HTTP status, excerpt, artifact paths}"
for k in executed-test build/static-analysis e2e/browser http/api db cli-output logs before/after; do
  printf '%s' "$EV" | grep -qF "$k" \
    && ok "$SCHEMA §Evidence: taxonomy names '$k'" \
    || err "$SCHEMA §Evidence: taxonomy must name the '$k' kind"
done

# --- (g) the four confidence tokens, schema AND template (AC6) ---------------
for t in 'Verified (multi-source)' 'Verified (single-source)' 'Partially verified' 'Unverified'; do
  printf '%s' "$EV" | grep -qF "$t" \
    && ok "$SCHEMA §Evidence: confidence token '$t' present" \
    || err "$SCHEMA §Evidence: confidence ladder must name '$t'"
  grep -qF "$t" templates/verify.md \
    && ok "templates/verify.md: confidence token '$t' present" \
    || err "templates/verify.md: must carry the confidence token '$t'"
done

# --- (h) client-grade report structure (AC5) ---------------------------------
for h in '## Evidence coverage matrix' '## Evidence artifacts index' '## Limitations & remaining risks' '## Contract mapping'; do
  grep -qF "$h" templates/verify.md \
    && ok "templates/verify.md: '$h' section present" \
    || err "templates/verify.md: must keep the '$h' section"
done
grep -qi 'full tier only' templates/verify.md \
  && ok "templates/verify.md: lite-tier skip note present on the coverage matrix" \
  || err "templates/verify.md: coverage matrix must carry the full-tier-only / lite skip note"

# --- (i) widened detection + evidence-dir discipline (AC2/AC3/AC4) -----------
for t in 'composer.json' 'phpunit.xml' 'playwright.config' 'bin/magento' 'MFTF'; do
  grep -qF "$t" agents/ff-test-runner.md \
    && ok "agents/ff-test-runner.md: detects '$t'" \
    || err "agents/ff-test-runner.md: detection must name '$t'"
done
grep -qF '<run dir>/evidence/' agents/ff-test-runner.md \
  && ok "agents/ff-test-runner.md: evidence-dir write scope stated" \
  || err "agents/ff-test-runner.md: must confine writes to <run dir>/evidence/"
grep -qi 'clear' agents/ff-test-runner.md \
  && ok "agents/ff-test-runner.md: clears evidence/ before writing (re-run hygiene)" \
  || err "agents/ff-test-runner.md: must clear evidence/ at the start of a run"

# --- (j) Autopilot mandatory-pause row (AC9) ----------------------------------
section "$SCHEMA" '^## Autopilot$' | grep -qF 'Evidence gap stop' \
  && ok "$SCHEMA §Autopilot: 'Evidence gap stop' pause row present" \
  || err "$SCHEMA §Autopilot: mandatory-pauses table must carry the 'Evidence gap stop' row"

# --- (k) ff-verify wiring: canonical reference + waiver line (AC7/AC8) --------
grep -qE '§Evidence|\*\*Evidence\*\*' commands/ff-verify.md \
  && ok "commands/ff-verify.md: references the Evidence contract by name" \
  || err "commands/ff-verify.md: must reference docs/manifest-schema.md §Evidence by name"
grep -qF 'Evidence gap accepted by user' commands/ff-verify.md \
  && ok "commands/ff-verify.md: waiver line format stated" \
  || err "commands/ff-verify.md: must state the exact waiver line 'Evidence gap accepted by user (<date>): <reason>'"
grep -qF 'Evidence gap accepted by user' "$SCHEMA" \
  && ok "$SCHEMA: waiver line format stated" \
  || err "$SCHEMA: must state the exact waiver line format"

# --- (l) dist parity for this feature's newly-pinned files --------------------
# (templates/verify.md covered in (e); docs/manifest-schema.md by kb-guard +
# durable-paths-guard; commands/README/SKILL by other guards.)
parity agents/ff-test-runner.md

if [ "$fail" -eq 0 ]; then echo "GREEN: evidence guard passed"; else echo "RED: evidence guard failed"; exit 1; fi
