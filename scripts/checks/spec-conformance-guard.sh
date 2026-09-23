#!/usr/bin/env bash
# Regression guard: spec-conformance review (v0.19.0). Pins the STRUCTURAL wiring of the
# review phase's contract check and its over-engineering guard:
#   SC1  ff-review.md dispatches a dedicated spec-conformance reviewer, IN ADDITION to the
#        `reviewerAgents` focus fan-out (never counted against it).
#   SC2  it is handed the run's contract via manifest.artifacts pointers (spec / plan on the
#        feature track, diagnosis / plan on bugfix), never a bare filename.
#   SC3  severity mapping: an unimplemented / partially implemented criterion is Critical;
#        out-of-scope change and an unrealized plan task are Important.
#   SC4  over-engineering guard — "report only gaps that affect correctness or the stated
#        requirements; style / speculative hardening is never Critical" — lives in BOTH the
#        dispatch (ff-review.md) and the agent (ff-code-reviewer.md).
#   SC5  templates/review.md carries a '## Spec conformance' section before '## Critical'.
#   SC6  SKILL.md + README.md mention the conformance check.
#   dist Codex dist parity for every touched packaged file.
#
# Whether the conformance reviewer actually CATCHES a missing criterion on a live run is
# behavioral and not grep-checkable; this guard does not claim it.
set -u
cd "$(dirname "$0")/../.." || exit 2
fail=0
err() { echo "FAIL: $1"; fail=1; }
ok()  { echo "ok:   $1"; }

# body of the first '## ' section whose heading matches, up to (excluding) the next '## '.
section() { awk -v re="$2" '$0 ~ "^## " && seen {exit} $0 ~ re {seen=1} seen' "$1"; }
lineno()  { grep -nE "$2" "$1" | head -1 | cut -d: -f1; }
# need <label> <text> <ERE>: match against the text with lines joined (prose wraps mid-phrase).
need()    { printf '%s' "$2" | tr '\n' ' ' | grep -qiE "$3" && ok "$1" || err "$1"; }

CMD="commands/ff-review.md"
AGENT="agents/ff-code-reviewer.md"
TPL="templates/review.md"
GUARD_RE='correctness or the stated requirements'

sc="$(section "$CMD" '^## Spec conformance')"
[ -n "$sc" ] && ok "$CMD: has a '## Spec conformance' section" \
  || err "$CMD: must have a '## Spec conformance' section"

# SC1 — dedicated dispatch, outside the reviewerAgents count
need "SC1: dispatches a dedicated ff-code-reviewer for spec conformance" "$sc" 'ff-code-reviewer'
need "SC1: not counted against reviewerAgents" "$sc" 'in addition to.*reviewerAgents|not counted against .?reviewerAgents'

# SC2 — contract resolved via manifest pointers
for p in 'artifacts\.spec' 'artifacts\.plan' 'artifacts\.diagnosis'; do
  need "SC2: resolves the contract via manifest.$p" "$sc" "$p"
done
need "SC2: passes the same diff the focus reviewers get" "$sc" 'same (diff|change)'

# SC3 — severity mapping
need "SC3: unimplemented / partial criterion → Critical" "$sc" '(not implemented|unimplemented|partially implemented)[^.]*\*\*Critical\*\*'
need "SC3: out-of-scope change → Important" "$sc" 'out[- ]of[- ]scope[^.]*\*\*Important\*\*'
need "SC3: unrealized plan task → Important" "$sc" 'plan task[^.]*\*\*Important\*\*'

# SC4 — over-engineering guard in the dispatch AND the agent
grep -qF "$GUARD_RE" "$CMD" && ok "SC4: $CMD carries the over-engineering guard" \
  || err "SC4: $CMD must carry '$GUARD_RE'"
grep -qF "$GUARD_RE" "$AGENT" && ok "SC4: $AGENT carries the over-engineering guard" \
  || err "SC4: $AGENT must carry '$GUARD_RE'"
grep -qiE 'never (be )?(rated |classed |marked )?\*\*Critical\*\*|never Critical' "$AGENT" \
  && ok "SC4: $AGENT says style / speculative hardening is never Critical" \
  || err "SC4: $AGENT must say style / speculative hardening is never Critical"

# SC5 — template section, placed before the Critical findings
ls=$(lineno "$TPL" '^## Spec conformance'); lc=$(lineno "$TPL" '^## Critical')
if [ -n "$ls" ] && [ -n "$lc" ] && [ "$ls" -lt "$lc" ]; then
  ok "SC5: $TPL has '## Spec conformance' before '## Critical'"
else
  err "SC5: $TPL needs '## Spec conformance' before '## Critical' (spec=$ls critical=$lc)"
fi

# SC6 — discoverability
for f in skills/feature-flow/SKILL.md README.md; do
  grep -qiE 'spec[- ]conformance' "$f" && ok "SC6: $f mentions spec conformance" \
    || err "SC6: $f must mention the spec-conformance review"
done

# dist parity — every touched packaged file
DIST="dist/codex/feature-flow"
for rel in "$CMD" "$AGENT" "$TPL" skills/feature-flow/SKILL.md README.md; do
  if diff -q "$rel" "$DIST/$rel" >/dev/null 2>&1; then
    ok "dist parity: $rel"
  else
    err "dist parity: $rel differs from $DIST/$rel (re-run scripts/package-codex-plugin.sh)"
  fi
done

if [ "$fail" -eq 0 ]; then echo "PASS: spec-conformance guard"; else echo "RED: spec-conformance guard failed"; fi
exit "$fail"
