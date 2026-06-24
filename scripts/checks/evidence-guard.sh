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

if [ "$fail" -eq 0 ]; then echo "GREEN: evidence guard passed"; else echo "RED: evidence guard failed"; exit 1; fi
