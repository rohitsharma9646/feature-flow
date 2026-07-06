#!/usr/bin/env bash
# Regression guard: WS-5 Design-time Trade-off Matrix + Devil's Advocate (lean matrix +
# devil's-advocate pass -> FS<n> verify contract items -> evidence-gap stop) must stay
# structurally wired. Pins the STRUCTURAL acceptance criteria
# (.feature-flow/ws5-tradeoff-matrix, v0.15.0):
#   AC1   templates/design.md '## Trade-off matrix' with the core-axis header + adaptive-axis note.
#   AC2   templates/design.md '## Devil's advocate' with '### Failure scenarios' (an FS1 example,
#         the '>=1 required' note) and '### Edge cases & operational risk'.
#   AC3   commands/ff-design.md carries the Devil's-advocate pass, requiring >=1 concrete failure
#         scenario, strictly BETWEEN the do-not-contradict STOP and '## Write the artifact'.
#   AC4   commands/ff-design.md's decision-write states the derive-not-diverge rule; and
#         templates/decision.md's pinned Trade-offs header is UNTOUCHED (proves derive-don't-widen,
#         so decision-record-guard.sh stays green by construction).
#   AC5   commands/ff-verify.md resolves artifacts.design and maps each FS<n> "exactly as an AC".
#   AC6   templates/verify.md has the '### FS1:' contract block with DIGIT-FREE placeholders (the
#         unfilled template must not satisfy Gate B's status-token regex — v0.9.0 exit-0 bug class).
#   AC9   docs/manifest-schema.md '## Design trade-offs & devil's advocate' canonical section +
#         subsections, the confidence-ladder third contract-item class, and the no-new-Autopilot-row
#         statement.
#   AC10  no new config key / manifest field (targeted negative check, always-on posture).
#   dist  Codex dist parity for every touched packaged file.
#
# Behavioral AC7/AC8 (an unproven FS<n> actually BLOCKING done, and a covered one NOT false-firing)
# are NOT grep-checkable and this guard deliberately does not assert them — a fresh-session
# STOP-vs-control self-run, named in the 0.15.0 CHANGELOG (same posture as decision-record-guard.sh
# AC13 / planning-intelligence-guard.sh AC15 / assumption-guard.sh AC6-AC7).
set -u
cd "$(dirname "$0")/../.." || exit 2
fail=0
err() { echo "FAIL: $1"; fail=1; }
ok()  { echo "ok:   $1"; }

section() { awk -v re="$2" '$0 ~ "^## " && seen {exit} $0 ~ re {seen=1} seen' "$1"; }
lineno()  { grep -nE "$2" "$1" | head -1 | cut -d: -f1; }

SCHEMA="docs/manifest-schema.md"
TPL_D="templates/design.md"
TPL_V="templates/verify.md"

# --- AC1: design.md Trade-off matrix -----------------------------------------
[ -f "$TPL_D" ] || err "$TPL_D: template must exist"
grep -qF '| Option | Complexity | Risk / operational impact | Test effort |' "$TPL_D" \
  && ok "$TPL_D: Trade-off matrix carries the core 3-axis header" \
  || err "$TPL_D: Trade-off matrix must carry '| Option | Complexity | Risk / operational impact | Test effort |'"
tm="$(section "$TPL_D" '^## Trade-off matrix')"
printf '%s\n' "$tm" | grep -qiF 'only when it actually differentiates' \
  && ok "$TPL_D: Trade-off matrix states the adaptive-axis rule" \
  || err "$TPL_D: Trade-off matrix must state extra axes are added only when they differentiate"

# --- AC2: design.md Devil's advocate -----------------------------------------
da="$(section "$TPL_D" "^## Devil's advocate")"
if [ -z "$da" ]; then
  err "$TPL_D: missing the '## Devil's advocate' section"
else
  ok "$TPL_D: has the '## Devil's advocate' section"
  for h in '### Failure scenarios' '### Edge cases & operational risk'; do
    printf '%s\n' "$da" | grep -qF "$h" \
      && ok "$TPL_D: Devil's advocate carries '$h'" \
      || err "$TPL_D: Devil's advocate must carry '$h'"
  done
  printf '%s\n' "$da" | grep -qE '^\- \*\*FS1:\*\*' \
    && ok "$TPL_D: Failure scenarios carries a labeled '- **FS1:**' example row" \
    || err "$TPL_D: Failure scenarios must carry a '- **FS1:**' example row"
  printf '%s\n' "$da" | grep -qiF 'at least one failure scenario is required' \
    && ok "$TPL_D: states >=1 failure scenario required even for a single obvious option" \
    || err "$TPL_D: must state >=1 failure scenario is required even for a single-option design"
fi

# --- AC3: ff-design.md adversarial-beat content + placement ------------------
grep -qiE "Devil.s-advocate pass" commands/ff-design.md \
  && ok "commands/ff-design.md: carries the Devil's-advocate pass" \
  || err "commands/ff-design.md: must carry the Devil's-advocate pass"
grep -qiF 'at least one concrete failure' commands/ff-design.md \
  && ok "commands/ff-design.md: requires >=1 concrete failure scenario" \
  || err "commands/ff-design.md: must require naming >=1 concrete failure scenario"
lstop=$(lineno commands/ff-design.md 'proceed to write the artifacts below')
lbeat=$(lineno commands/ff-design.md "Devil.s-advocate pass")
lwrite=$(lineno commands/ff-design.md '^## Write the artifact')
if [ -n "$lstop" ] && [ -n "$lbeat" ] && [ -n "$lwrite" ] && [ "$lstop" -lt "$lbeat" ] && [ "$lbeat" -lt "$lwrite" ]; then
  ok "commands/ff-design.md: adversarial beat ($lbeat) sits between the do-not-contradict STOP ($lstop) and '## Write the artifact' ($lwrite)"
else
  err "commands/ff-design.md: adversarial beat must sit between the STOP (${lstop:-MISSING}) and '## Write the artifact' (${lwrite:-MISSING}); beat found at ${lbeat:-MISSING}"
fi

# --- AC4: derive-don't-widen (ff-design instruction + decision.md untouched) --
grep -qiF 'never a second, divergent scoring pass' commands/ff-design.md \
  && ok "commands/ff-design.md: states the derive-not-diverge rule for decision.md's Trade-offs" \
  || err "commands/ff-design.md: must state decision.md's Trade-offs cells are DERIVED from the matrix (never a second, divergent scoring pass)"
grep -qiF 'by reference' commands/ff-design.md \
  && ok "commands/ff-design.md: failure scenarios named in decision.md by reference" \
  || err "commands/ff-design.md: must name decision.md's failure scenarios by reference (not copied)"
grep -qF '| Option | Effort | Risk | Reversibility |' templates/decision.md \
  && ok "templates/decision.md: Trade-offs schema untouched (decision-record-guard.sh stays green)" \
  || err "templates/decision.md: the pinned '| Option | Effort | Risk | Reversibility |' header must stay untouched (derive-don't-widen)"

# --- AC5: ff-verify.md resolves artifacts.design + maps FS<n> ----------------
grep -q 'artifacts.design' commands/ff-verify.md \
  && ok "commands/ff-verify.md: resolves artifacts.design" \
  || err "commands/ff-verify.md: must resolve manifest.artifacts.design (full tier)"
grep -qE '### FS<n>|\*\*FS<n>:\*\*' commands/ff-verify.md \
  && ok "commands/ff-verify.md: maps each failure scenario into its own FS<n> contract item" \
  || err "commands/ff-verify.md: must map each failure scenario into its own '### FS<n>' contract item"
grep -qiF 'exactly as an acceptance criterion' commands/ff-verify.md \
  && ok "commands/ff-verify.md: FS mapping reuses the AC mapping discipline" \
  || err "commands/ff-verify.md: FS mapping must state it maps 'exactly as an acceptance criterion'"

# --- AC6: verify.md FS block present + DIGIT-FREE placeholders ----------------
fsb="$(awk '/^### FS1:/{s=1} /^\*\*Bugfix track\*\*/{s=0} s' "$TPL_V")"
if [ -z "$fsb" ]; then
  err "$TPL_V: must carry a '### FS1:' contract-mapping block"
else
  ok "$TPL_V: FS1 contract-mapping block present"
  for f in '\*\*Method:\*\*' '\*\*Evidence:\*\*' '\*\*Confidence:\*\*' '\*\*Gap'; do
    printf '%s\n' "$fsb" | grep -qE "$f" \
      && ok "$TPL_V: FS block carries $f" \
      || err "$TPL_V: FS block must carry $f (same shape as the AC block)"
  done
  # AC6 digit-free invariant (unfilled FS placeholder must still DENY Gate B) is enforced
  # end-to-end against the REAL hook by enforce-gate-guard.sh's 'b-template' fixture, which
  # copies the whole templates/verify.md through hooks/enforce-gate — not re-implemented here
  # with a hand-copied regex that could drift (WS-5 review, simplicity finding 1).
fi

# --- AC9: schema canonical section + subsections + ladder class + no-new-row --
grep -q "^## Design trade-offs" "$SCHEMA" \
  && ok "$SCHEMA: '## Design trade-offs & devil's advocate' canonical section present" \
  || err "$SCHEMA: must define the '## Design trade-offs & devil's advocate' canonical section"
dt="$(section "$SCHEMA" '^## Design trade-offs')"
for h in '### Trade-off matrix' '### Devil' '### Actuation' '### decision.md reconciliation' '### v1 non-goals'; do
  printf '%s\n' "$dt" | grep -qF "$h" \
    && ok "$SCHEMA §Design trade-offs: '$h' present" \
    || err "$SCHEMA §Design trade-offs: must keep '$h'"
done
printf '%s\n' "$dt" | grep -qiF 'no new §Autopilot row' \
  && ok "$SCHEMA §Design trade-offs: states no new §Autopilot row (reuses Evidence gap stop)" \
  || err "$SCHEMA §Design trade-offs: must state no new §Autopilot row is added"
ev="$(section "$SCHEMA" '^## Evidence$')"
printf '%s\n' "$ev" | grep -qiF 'design-time failure scenario' \
  && ok "$SCHEMA §Evidence: Confidence ladder names the design-time-failure-scenario class" \
  || err "$SCHEMA §Evidence: Confidence ladder must name 'design-time failure scenario' as a third contract-item class"

# --- AC10: no new config key / manifest field (targeted negative check) ------
grep -qiE 'tradeoffmatrix|devilsadvocate|failurescenario' config/defaults.json \
  && err "config/defaults.json: must NOT gain a trade-off/devil's-advocate key (always-on)" \
  || ok "config/defaults.json: no new config key (always-on, as required)"
schema_json="$(awk '/^## Schema/{s=1;next} /^## Field notes/{s=0} s' "$SCHEMA")"
printf '%s\n' "$schema_json" | grep -qiE '"(tradeOffMatrix|devilsAdvocate|failureScenarios)"' \
  && err "$SCHEMA: manifest JSON schema must NOT gain a new top-level field for this workstream" \
  || ok "$SCHEMA: no new top-level manifest field"

# --- dist: Codex dist parity for every touched packaged file -----------------
DIST="dist/codex/feature-flow"
for rel in templates/design.md templates/verify.md docs/manifest-schema.md \
           commands/ff-design.md commands/ff-verify.md; do
  if diff -q "$rel" "$DIST/$rel" >/dev/null 2>&1; then
    ok "dist parity: $rel"
  else
    err "dist parity: $rel differs from $DIST/$rel (re-run scripts/package-codex-plugin.sh)"
  fi
done

if [ "$fail" -eq 0 ]; then echo "PASS: design-tradeoff guard"; else echo "RED: design-tradeoff guard failed"; fi
exit "$fail"
