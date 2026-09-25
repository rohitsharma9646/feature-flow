#!/usr/bin/env bash
# Regression guard: forward-test cases (v0.18.0). Pins the STRUCTURAL acceptance criteria of the
# forward-testing feature (.feature-flow/retro-forward-testing):
#   AC12  every behavior (the 7 known-gap ones, plus implement-controller since v0.23.0 and
#         single-architect, architect-pick and architect-decline since v0.24.0) has a fired AND a
#         control arm, and each arm has all four parts: a non-empty sandbox/, prompt.txt, expected.md, an executable assert.sh.
#   AC18  the runner lives at scripts/forward-test.sh, NOT under scripts/checks/ (CI never runs it),
#         and evals/ is absent from the Codex dist (forward tests are repo-internal).
#   blind prompt.txt never states the expected outcome (a cheap lexical check for the words the
#         assertions look for — the real blindness review is human).
#
# Whether each behavior actually FIRES (fired arm) and stays quiet (control arm) is an LLM
# judgment that only a fresh paid session can observe. This guard deliberately does not assert
# it — that is `scripts/forward-test.sh`, run locally, never in CI.
set -u
cd "$(dirname "$0")/../.." || exit 2
fail=0
err() { echo "FAIL: $1"; fail=1; }
ok()  { echo "ok:   $1"; }

CASES="evals/forward"
BEHAVIORS="decision-conflict planning-gap delivery-gap assumption-gap design-gap repair-gap discovery-gap implement-controller single-architect architect-pick architect-decline"

[ -f "$CASES/README.md" ] && ok "$CASES/README.md present" || err "$CASES/README.md must document the case shape"
[ -f "$CASES/lib.sh" ]    && ok "$CASES/lib.sh present"    || err "$CASES/lib.sh (shared assert helpers) must exist"

# --- AC12: every behavior x 2 arms x 4 parts ----------------------------------------------------
for b in $BEHAVIORS; do
  for arm in fired control; do
    d="$CASES/$b/$arm"
    if [ ! -d "$d" ]; then err "$d: arm missing"; continue; fi
    if [ -d "$d/sandbox" ] && [ -n "$(find "$d/sandbox" -type f | head -1)" ]; then
      ok "$d: sandbox/ non-empty"
    else
      err "$d: sandbox/ missing or empty"
    fi
    [ -s "$d/prompt.txt" ]  && ok "$d: prompt.txt"  || err "$d: prompt.txt missing or empty"
    [ -s "$d/expected.md" ] && ok "$d: expected.md" || err "$d: expected.md missing or empty"
    if [ -f "$d/assert.sh" ] && [ -x "$d/assert.sh" ]; then
      ok "$d: assert.sh executable"
    else
      err "$d: assert.sh missing or not executable"
    fi
    # blind prompt: must not name the outcome the assertion checks for
    if [ -f "$d/prompt.txt" ] && grep -qiE 'expect|should (stop|fail|pass|block)|DELIVERY GAP|## Repair|unvalidated|override by user' "$d/prompt.txt"; then
      err "$d: prompt.txt leaks the expected outcome"
    else
      ok "$d: prompt.txt is blind"
    fi
    # planted manifests must set autopilot explicitly (absent silently means false)
    for mf in $(find "$d/sandbox/.feature-flow" -name manifest.json 2>/dev/null); do
      grep -q '"autopilot"' "$mf" && ok "$mf: autopilot explicit" || err "$mf: planted manifest must set autopilot explicitly"
    done
  done
done
# the planted sandboxes must be committable despite the repo-wide .feature-flow/ ignore
probe="$CASES/delivery-gap/fired/sandbox/.feature-flow/greeting-release/manifest.json"
if git check-ignore -q "$probe" 2>/dev/null; then
  err ".gitignore: planted sandbox run state is ignored ($probe) — keep the evals/forward negations"
else
  ok ".gitignore: planted sandbox run state is committable"
fi

# --- AC18: runner placement + not shipped ----------------------------------------------------
[ -x scripts/forward-test.sh ] && ok "scripts/forward-test.sh present + executable" || err "scripts/forward-test.sh must exist and be executable"
stray="$(ls scripts/checks/ 2>/dev/null | grep -i 'forward' | grep -v '^forward-test-guard\.sh$')"
[ -z "$stray" ] && ok "no forward-test runner under scripts/checks/" || err "scripts/checks/ must not hold the runner (CI would run it): $stray"
DIST="dist/codex/feature-flow"
if [ -d "$DIST" ]; then
  [ ! -e "$DIST/evals" ] && ok "Codex dist excludes evals/" || err "$DIST/evals exists — forward tests must not ship"
  [ ! -e "$DIST/scripts/forward-test.sh" ] && ok "Codex dist excludes the runner" || err "$DIST ships scripts/forward-test.sh"
else
  err "$DIST missing — run scripts/package-codex-plugin.sh first"
fi

if [ "$fail" -eq 0 ]; then echo "PASS: forward-test guard"; else echo "RED: forward-test guard failed"; fi
exit "$fail"
