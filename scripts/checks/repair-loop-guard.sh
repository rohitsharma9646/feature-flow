#!/usr/bin/env bash
# Regression guard: WS-6 Feedback/Repair loop (one autopilot repair-and-re-verify cycle on a
# genuine verify FAILURE — a captured non-success status — mirroring ff-review's fix-and-re-review
# cycle) must stay structurally wired. Pins the STRUCTURAL acceptance criteria
# (.feature-flow/ws6-repair-loop, v0.16.0):
#   AC1/AC2/AC4/AC5  commands/ff-verify.md carries the repair branch INSIDE "Refuse premature done",
#         BEFORE the fall-through gap-report STOP; names the full-tier precondition.
#   AC3   the scoped-re-verify ("only the named re-touched") + evidence-preservation exception in
#         ff-verify.md, and the "scoped repair re-verify" carve-out in agents/ff-test-runner.md.
#   AC6   negative check: no verify.repairCycles / new manifest field, no config toggle.
#   AC7   docs/manifest-schema.md §Autopilot gains the repair-cycle row (capped-then-stop, NOT
#         "unconditional") + a "Repair-and-re-verify cycle" subsection mirroring Fix-and-re-review.
#   AC8   templates/verify.md '## Repair' section headers present (DIGIT-FREE placeholders proven
#         end-to-end by enforce-gate-guard.sh's b-template fixture — NOT re-implemented here).
#   dist  Codex dist parity for every touched packaged file.
#
# Behavioral AC13/AC14 (the fired arm actually attempting exactly one cycle then stopping, and the
# control arm NOT false-firing) are NOT grep-checkable and this guard deliberately does not assert
# them — a fresh-session STOP-vs-control self-run, named in the 0.16.0 CHANGELOG (same posture as
# design-tradeoff-guard.sh AC7/AC8, assumption-guard.sh AC6-AC7, planning-intelligence-guard.sh AC15).
set -u
cd "$(dirname "$0")/../.." || exit 2
fail=0
err() { echo "FAIL: $1"; fail=1; }
ok()  { echo "ok:   $1"; }

section() { awk -v re="$2" '$0 ~ "^## " && seen {exit} $0 ~ re {seen=1} seen' "$1"; }
lineno()  { grep -nE "$2" "$1" | head -1 | cut -d: -f1; }
flat()    { tr '\n' ' ' | tr -s '[:space:]' ' '; }  # collapse newlines — prose may reflow across lines

. scripts/checks/lib/schema.sh
schema_join  # SCHEMA = the joined contract (temp file); SCHEMA_LABEL names it in messages
CMD="commands/ff-verify.md"
TPL="templates/verify.md"
RUNNER="agents/ff-test-runner.md"

# --- AC7: §Autopilot row (capped-then-stop, NOT "unconditional") + subsection --
ap="$(section "$SCHEMA" '^## Autopilot$')"
row="$(printf '%s\n' "$ap" | grep -iF 'Verify repair-and-re-verify cycle')"
if [ -n "$row" ]; then
  ok "$SCHEMA_LABEL §Autopilot: 'Verify repair-and-re-verify cycle' mandatory-pause row present"
  printf '%s\n' "$row" | grep -qi 'unconditional' \
    && err "$SCHEMA_LABEL §Autopilot: the repair-cycle row must NOT say 'unconditional' (capped-then-stop shape, not the do-not-contradict STOP)" \
    || ok "$SCHEMA_LABEL §Autopilot: repair-cycle row correctly avoids 'unconditional'"
else
  err "$SCHEMA_LABEL §Autopilot: must add the 'Verify repair-and-re-verify cycle' mandatory-pause row"
fi
grep -qF '**Repair-and-re-verify cycle' "$SCHEMA" \
  && ok "$SCHEMA_LABEL: 'Repair-and-re-verify cycle' subsection present (mirrors Fix-and-re-review cycle)" \
  || err "$SCHEMA_LABEL: must add a 'Repair-and-re-verify cycle' subsection mirroring Fix-and-re-review cycle"

# --- AC1/AC2/AC4/AC5: ff-verify.md branch placement --------------------------
lsec=$(lineno "$CMD" '^## Refuse premature')
lrep=$(lineno "$CMD" 'Autopilot repair-and-re-verify cycle')
lstop=$(lineno "$CMD" 'Verification found evidence gaps')
if [ -n "$lsec" ] && [ -n "$lrep" ] && [ -n "$lstop" ] && [ "$lsec" -lt "$lrep" ] && [ "$lrep" -lt "$lstop" ]; then
  ok "$CMD: repair branch ($lrep) sits inside 'Refuse premature done' ($lsec), before the fall-through STOP ($lstop)"
else
  err "$CMD: repair branch must sit between the section start (${lsec:-MISSING}) and the fall-through STOP (${lstop:-MISSING}); branch at ${lrep:-MISSING}"
fi
grep -qF 'tier == "full"' "$CMD" \
  && ok "$CMD: repair branch names the full-tier-only precondition" \
  || err "$CMD: repair branch must name tier == \"full\" as a precondition"

# --- AC3: scoped-re-verify + evidence-preservation strings (flattened — prose reflows) --
cmd_flat="$(flat < "$CMD")"
printf '%s' "$cmd_flat" | grep -qiF 'only the named re-touched' \
  && ok "$CMD: re-verify is scoped to only the named re-touched ACs" \
  || err "$CMD: must scope the re-verify to only the named re-touched ACs"
printf '%s' "$cmd_flat" | grep -qiF 'scoped repair re-verify' \
  && ok "$CMD: names the 'scoped repair re-verify' the runner keys off" \
  || err "$CMD: must tell the runner this is a 'scoped repair re-verify'"
printf '%s' "$cmd_flat" | grep -qiF 'exception to the start-of-verify evidence-clear rule' \
  && ok "$CMD: states the evidence-preservation exception" \
  || err "$CMD: must state the exception to the start-of-verify evidence-clear rule"
flat < "$RUNNER" | grep -qiF 'scoped repair re-verify' \
  && ok "$RUNNER: carries the scoped-repair carve-out (do not clear evidence/)" \
  || err "$RUNNER: must carry the scoped-repair-re-verify carve-out so it does not clear evidence/"

# --- AC8: templates/verify.md '## Repair' section headers --------------------
rep="$(awk '/^## Repair$/{s=1} s' "$TPL")"
if [ -z "$rep" ]; then
  err "$TPL: missing the '## Repair' section"
else
  ok "$TPL: '## Repair' section present"
  for f in '\*\*Triggering item:\*\*' '\*\*Captured failure:\*\*' '\*\*Diagnosis:\*\*' \
           '\*\*Fix applied:\*\*' '\*\*Re-touched items' '\*\*Re-verify outcome:\*\*'; do
    printf '%s\n' "$rep" | grep -qE "$f" \
      && ok "$TPL: '## Repair' carries $f" \
      || err "$TPL: '## Repair' must carry $f"
  done
  # bugfix-track terminology must not be silently excluded (design.md edge case): the
  # Re-touched line generalizes beyond AC-only numbering.
  printf '%s\n' "$rep" | grep -qiF 'bugfix item' \
    && ok "$TPL: '## Repair' Re-touched line names the bugfix track too (not AC-only)" \
    || err "$TPL: '## Repair' must generalize re-touched items to the bugfix track (not hard-code AC)"
  # Digit-free / Gate-B-safe invariant proven end-to-end against the REAL hook by
  # enforce-gate-guard.sh's 'b-template' fixture (copies the whole templates/verify.md
  # through hooks/enforce-gate) — not re-implemented here with a hand-copied regex.
fi

# --- AC6: no new manifest field / config toggle (targeted negative check) ----
grep -qiE 'repaircycle' config/defaults.json \
  && err "config/defaults.json: must NOT gain a repair-cycle config key (autopilot-gated, not toggled)" \
  || ok "config/defaults.json: no new repair config key"
schema_json="$(awk '/^## Schema/{s=1;next} /^## Field notes/{s=0} s' "$SCHEMA")"
printf '%s\n' "$schema_json" | grep -qiE '"repaircycles"' \
  && err "$SCHEMA_LABEL: manifest JSON schema must NOT gain a 'repairCycles' field (artifact-resident cap, no manifest footprint)" \
  || ok "$SCHEMA_LABEL: no new top-level manifest field for repair cycles"

# --- dist: Codex dist parity for every touched packaged file -----------------
DIST="dist/codex/feature-flow"
for rel in "$CMD" "$TPL" "$RUNNER" docs/manifest-schema.md skills/feature-flow/SKILL.md README.md; do
  if diff -q "$rel" "$DIST/$rel" >/dev/null 2>&1; then
    ok "dist parity: $rel"
  else
    err "dist parity: $rel differs from $DIST/$rel (re-run scripts/package-codex-plugin.sh)"
  fi
done

if [ "$fail" -eq 0 ]; then echo "PASS: repair-loop guard"; else echo "RED: repair-loop guard failed"; fi
exit "$fail"
