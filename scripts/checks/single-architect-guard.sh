#!/usr/bin/env bash
# Regression guard: one architect in ff-design (v0.24.0, .feature-flow/single-architect-design).
#   AC1   ff-design dispatches exactly ONE ff-code-architect; no architectAgents; no three-focus list.
#   AC2/3 ff-code-architect.md: weighing lenses, best-only, fixed report markers; no sibling wording.
#   AC4   architect.md written before the choice pause (artifacts.architect, repo-relative);
#         re-entry reads it instead of re-dispatching.  FS2: file first, then pointer; sandbox path too.
#   AC5   a picked rejected approach -> one re-dispatch, appended; the autopilot pause row unchanged.
#         FS3: the appended report is the one the design and decision records derive from.
#   AC6   derive-not-diverge kept; "every option the architect considered" wording.
#   AC7   architectAgents gone from defaults, Known keys, README; no "architects fan out" wording.
#   AC10  (v0.25.0) the Re-entry check re-runs the rejected-list screen before the choice pause.
# Whether one architect actually reports without padding, and the pause holding with the report on
# disk, is the forward test evals/forward/single-architect; cost is SM1 (sm1-ratio.sh), by hand.
set -u
cd "$(dirname "$0")/../.." || exit 2
fail=0
err() { echo "FAIL: $1"; fail=1; }
ok()  { echo "ok:   $1"; }
flat() { tr '\n' ' ' | sed 's/ > / /g' | tr -s '[:space:]' ' '; }
need() { if flat < "$1" | grep -qF -- "$3"; then ok "$2: $1 has '$3'"; else err "$2: $1 must contain '$3'"; fi; }
lacks() { if flat < "$1" | grep -qiE -- "$3"; then err "$2: $1 must not match /$3/"; else ok "$2: $1 has no /$3/"; fi; }
lineno() { grep -nF -- "$2" "$1" | head -1 | cut -d: -f1; }

DES="commands/ff-design.md"; AG="agents/ff-code-architect.md"; CORE="docs/manifest-schema.md"
TPL="templates/design.md"; DT="docs/schema/design-tradeoffs.md"

# AC1
need "$DES" AC1 'dispatch **exactly ONE** `ff-code-architect`'
lacks "$DES" AC1 'architectAgents'
lacks "$DES" AC1 '\*\*minimal\*\* —'
# AC2/AC3
for p in '## Weighing approaches' '## Report format' '`Recommended: <name of the chosen approach>`' \
         'complexity: low|med|high, risk: low|med|high, test effort: low|med|high' \
         '`one obvious approach — <why>`' 'Develop **only the best approach in full**' 'never a strawman'; do
  need "$AG" AC2 "$p"
done
need "$AG" FS1 'A variant of a detail inside the chosen approach'
need "$AG" FS1 '**Report budget.**'
need "$AG" FS1 'about **400 words**'
need "$AG" FS1 '**Last check before returning.**'
need "$AG" FS1 'mentions the spec, a requirement, a constraint or a non-goal at all'
need "$AG" AC2 'one physical line — never wrap it'
need "$DES" FS1 'suggest candidate approaches or design sub-choices'
need "$DES" FS1 'Name `<run dir>/architect.md` as its **report path**'
need "$DES" FS1 '**do not re-emit it**'
need "$DES" FS1 'only if it does not (the write failed'
need "$DES" FS1 '**Screen the rejected list.**'
need "$DES" FS1 'Dropped (contradicts the spec): <name> — <the clause it breaks>'
need "$DES" AC5 'and **no report path**, to develop that'
need "$DES" AC5 'naming no report path'
need "$AG" FS1 '**When the caller names a report path**'
need "$AG" FS1 'never create or change any other file'
grep -qE '^tools:.*\bWrite\b' "$AG" && ok 'FS1: architect has the Write tool for its report' || err 'FS1: architect needs the Write tool for its report'
grep -E '^tools:' "$AG" | grep -qE '\b(Edit|MultiEdit|Bash)\b' && err 'FS1: architect must not have Edit or Bash' || ok 'FS1: architect has no Edit or Bash'
lacks "$AG" AC3 'sibling'
# AC4 + FS2
for p in '**Re-entry check.**' 'or `<run dir>/architect.md` exists' 'never re-dispatch for a report that is already on disk' \
         '**Write the report before the pause.**' 'Then write its repo-relative path (`<base>/<slug>/architect.md`)' 'manifest.artifacts.architect'; do
  need "$DES" AC4 "$p"
done
w=$(lineno "$DES" '**Write the report before the pause.**'); c=$(lineno "$DES" '**The choice pause.**'); d=$(lineno "$DES" "## Devil's-advocate pass")
if [ -n "$w" ] && [ -n "$c" ] && [ -n "$d" ] && [ "$w" -lt "$c" ] && [ "$c" -lt "$d" ]; then
  ok "AC4: report written ($w) before the choice pause ($c), before the devil's-advocate pass ($d)"
else err "AC4: order must be write report < choice pause < devil's-advocate pass"; fi
need "$CORE" AC4 '"architect": ".feature-flow/add-oauth/architect.md"'
need "$CORE" AC4 '**`artifacts.architect`** (added v0.24.0)'
need "$CORE" AC4 '`architect` (`ff-design`'"'"'s architect report)'
# AC5 + FS3
need "$DES" AC5 'Re-dispatch the same `ff-code-architect` **once**'
need "$DES" AC5 '## Developed on request: <name>'
need "$DES" FS3 'That appended report is the one the design and decision writes below derive from.'
need "$DES" AC5 'ask the user only to confirm it'
need "$DES" AC5 'if they do not, re-dispatch the same'
need "$DES" AC4 'A confirmed re-run also discards the previous'
need "$DES" AC4 'delete `<run dir>/architect.md` and `<run dir>/critic-design.md` and clear `manifest.artifacts.architect`'
need "$DES" AC4 'skip the pause and resume at the **Do-not-contradict'
need "$DES" AC10 're-run **Screen the rejected list** below (idempotent'
r=$(lineno "$DES" 're-run **Screen the rejected list** below'); p=$(lineno "$DES" 'then go to **The choice pause**')
if [ -n "$r" ] && [ -n "$p" ] && [ "$r" -le "$p" ]; then ok "AC10: re-entry screens ($r) before the pause ($p)"
else err "AC10: the Re-entry check must re-run the screen before going to the choice pause"; fi
lacks docs/schema/knowledge-base.md AC7 'fan-out'
lacks skills/feature-flow/SKILL.md AC7 'before each fan-out'
grep -qF 'Design option choice (`ff-design`) | in-session | ask (AskUserQuestion), then continue the chain in the same turn' docs/schema/autopilot.md \
  && ok "AC5: the autopilot design-choice row is unchanged" || err "AC5: the autopilot design-choice row must stay unchanged"
# AC6
need "$DES" AC6 'never a second, divergent scoring pass'
need "$TPL" AC6 'Score **every option** the architect considered (chosen + rejected)'
need "$DT" AC6 'scores **every** option the architect considered'
lacks "$TPL" AC6 'fan-out surfaced'
lacks "$DT" AC6 'fanned-out option'
# AC7
if command -v jq >/dev/null 2>&1; then
  jq -e 'has("architectAgents") | not' config/defaults.json >/dev/null \
    && ok "AC7: config/defaults.json has no architectAgents" || err "AC7: config/defaults.json still has architectAgents"
else err "AC7: needs jq"; fi
lacks "$CORE" AC7 '`architectAgents`'
lacks README.md AC7 'architectAgents'
for f in "$DES" README.md skills/feature-flow/SKILL.md "$TPL" "$DT"; do lacks "$f" AC7 'architects? fan[- ]?out'; done

# dist parity
DIST="dist/codex/feature-flow"
for rel in "$DES" "$AG" "$CORE" "$TPL" "$DT" config/defaults.json README.md skills/feature-flow/SKILL.md; do
  cmp -s "$rel" "$DIST/$rel" && ok "dist parity: $rel" \
    || err "dist parity: $rel differs from or is missing in $DIST/$rel (re-run scripts/package-codex-plugin.sh)"
done

if [ "$fail" -eq 0 ]; then echo "PASS: single-architect guard"; else echo "RED: single-architect guard failed"; fi
exit "$fail"
