#!/usr/bin/env bash
# Regression guard: the Critic inside ff-design and ff-plan (v0.25.0, .feature-flow/critic-plan-design).
#   AC1  agents/ff-critic.md: leaf, Write but no Edit/Bash, the distilled process, fixed one-line markers.
#   AC2  models.critic = opus in defaults, Known keys, README; both commands pass it (via §Critic).
#   AC3  ff-design: Critic after design.md, before decision.md; complete only after the Critic.
#   AC4  ff-plan: Critic after plan.md, before complete; both tracks' contracts named.
#   AC5  §Critic: Resolution before the revision, re-check appended with no report path, Critic stop, accept line.
#   AC6  §Critic screen: Dropped line, contract-is-wrong route, another-approach ask.
#   AC7  artifacts.critic-design/-plan documented; the Critic: closing line.
#   AC8  re-entry reuses the report; re-run discards it (both commands).
#   AC9  autopilot row, SKILL/codex-tools listing, templates untouched, dist parity.
# Whether the Critic actually catches a seeded defect and stays quiet on a sound artifact is the
# forward tests evals/forward/critic-design and critic-plan; cost/time is SM1/SM2 (critic-ratio.sh).
set -u
cd "$(dirname "$0")/../.." || exit 2
fail=0
err() { echo "FAIL: $1"; fail=1; }
ok()  { echo "ok:   $1"; }
flat() { tr '\n' ' ' | sed 's/ > / /g' | tr -s '[:space:]' ' '; }
need() { if flat < "$1" | grep -qF -- "$3"; then ok "$2: $1 has '$3'"; else err "$2: $1 must contain '$3'"; fi; }
lineno() { grep -nF -- "$2" "$1" | head -1 | cut -d: -f1; }
before() { # before <file> <label> <first> <second>
  local a b; a=$(lineno "$1" "$3"); b=$(lineno "$1" "$4")
  if [ -n "$a" ] && [ -n "$b" ] && [ "$a" -lt "$b" ]; then ok "$2: '$3' ($a) before '$4' ($b) in $1"
  else err "$2: '$3' must come before '$4' in $1"; fi
}

AG="agents/ff-critic.md"; CR="docs/schema/critic.md"; DES="commands/ff-design.md"; PLN="commands/ff-plan.md"
CORE="docs/manifest-schema.md"; AP="docs/schema/autopilot.md"; SK="skills/feature-flow/SKILL.md"
CX="skills/feature-flow/references/codex-tools.md"

# AC1
[ -f "$AG" ] && ok "AC1: $AG exists" || err "AC1: $AG missing"
grep -qE '^tools: Glob, Grep, LS, Read, Write, NotebookRead, WebFetch, WebSearch, TodoWrite$' "$AG" \
  && ok "AC1: critic tools line exact" || err "AC1: critic tools line must be exactly Glob, Grep, LS, Read, Write, NotebookRead, WebFetch, WebSearch, TodoWrite"
grep -E '^tools:' "$AG" | grep -qE '\b(Edit|MultiEdit|Bash)\b' && err "AC1: critic must not have Edit or Bash" || ok "AC1: critic has no Edit or Bash"
cmp -s <(sed -n 9p agents/ff-code-architect.md) <(sed -n 9p "$AG") && ok "AC1: leaf preamble verbatim" || err "AC1: line 9 must be the architect's leaf preamble"
cmp -s <(sed -n 11p agents/ff-code-architect.md) <(sed -n 11p "$AG") && ok "AC1: read budget verbatim" || err "AC1: line 11 must be the architect's read budget"
for p in '**Ground its claims in the repo.**' '**Do the arithmetic.**' \
         '**An unverified load-bearing assumption is a finding, not a to-do.**' \
         'If everything is Critical, nothing is' '**Report budget.**' 'about **400 words**' \
         '**When the caller names a report path**' 'never create or change any other file' \
         'one physical line — never wrap it' '`Verdict: ready`' '`Verdict: revise`' \
         '`Critical C<n>: <title> — <where> — basis: verified|from the contract|inferred`' \
         '`Important I<n>: <title> — <where> — basis: verified|from the contract|inferred`' \
         '`No findings — <why the artifact holds>`' 'you never ask for a different *what*'; do
  need "$AG" AC1 "$p"
done
# AC2
if command -v jq >/dev/null 2>&1; then
  [ "$(jq -r '.models.critic // empty' config/defaults.json)" = opus ] && ok "AC2: models.critic = opus" || err "AC2: config/defaults.json models.critic must be \"opus\""
else err "AC2: needs jq"; fi
need "$CORE" AC2 'escalation,critic}'
need README.md AC2 '| `models.critic` | `"opus"` |'
need "$CR" AC2 'passing `models.critic`'
# AC3
need "$DES" AC3 '## Critic — before the decision record'
need "$DES" AC3 '§Critic in `${CLAUDE_PLUGIN_ROOT}/docs/schema/critic.md`'
need "$DES" AC3 '`phases.design.status` stays `"in_progress"`'
before "$DES" AC3 "## Devil's-advocate pass" '## Critic — before the decision record'
before "$DES" AC3 '## Critic — before the decision record' '**Then record the decision.**'
before "$DES" AC3 '**Then record the decision.**' 'Then set `phases.design = { status: "complete"'
# AC4
need "$PLN" AC4 '## Critic — before the plan completes'
need "$PLN" AC4 '§Critic in `${CLAUDE_PLUGIN_ROOT}/docs/schema/critic.md`'
need "$PLN" AC4 '(**bugfix**, via `artifacts.diagnosis`)'
need "$PLN" AC4 'Only once the Critic step is clear, set `phases.plan'
before "$PLN" AC4 '**No Placeholders self-check' '## Critic — before the plan completes'
before "$PLN" AC4 '## Critic — before the plan completes' '## Update manifest'
# AC5
for p in 'dispatch **exactly one** `ff-critic`' '**before** changing anything' 'and **no report path**' \
         'append its return value under `## Re-check` — never overwrite' '**Critic stop**' \
         '`Critic finding accepted by user (<date>): <reason>`' 'never self-authored, never written by autopilot' \
         'There is no second cycle, in either mode' 'The cycle runs in **both modes**' '**no manifest field**' \
         '`**Ruling:** I<n> — <why it stands>`'; do
  need "$CR" AC5 "$p"
done
# review C1 (second fix, user-directed): a Critic stop clears only by the accept line or a user-confirmed fresh critique;
# plain re-entry never re-dispatches (AC8).
for p in '**At a Critic stop.**' 'never re-dispatches on its own' 'counts as ruled' '**re-critique the current artifact**' \
         "a new first critique with its own revise cycle, at the user's request" 'Keep → end the turn at the Critic stop again' \
         '`## Re-check` present with a Critical still open → **At a Critic stop**'; do
  need "$CR" AC5 "$p"
done
if flat < "$CR" | grep -qF 'Re-run after a Critic stop'; then err "AC8: the removed auto re-dispatch rule is back"; else ok "AC8: no automatic re-dispatch rule"; fi
flat < "$CR" | grep -qF -- 'append `## Resolution` to the report' && flat < "$CR" | grep -qE -- 'append .## Resolution. to the report.*\(2\) revise the artifact in place' && ok "AC5: Resolution is appended before the revision" || err "AC5: §Critic must append ## Resolution before (2) revising the artifact"
# AC6
for p in '`Dropped (contradicts the spec): <finding> — <the clause it breaks>`' '**The contract is wrong.**' \
         'never edit the signed contract' '**Another approach.**' 'never switch the approach yourself' \
         'route to `/feature-flow:ff-design`' 'The screen is idempotent'; do
  need "$CR" AC6 "$p"
done
# AC7
need "$CORE" AC7 '"critic-design": ".feature-flow/add-oauth/critic-design.md"'
need "$CORE" AC7 '**`artifacts.critic-design`** / **`artifacts.critic-plan`** (added v0.25.0)'
need "$CORE" AC7 '`critic-design` and `critic-plan` (the Critic'"'"'s reports)'
need "$CR" AC7 '`Critic: <ready | revised | stopped> — <n> Critical, <n> Important (<report path>)`'
need "$DES" AC7 '**Closing line**'
need "$PLN" AC7 '**Closing line**'
# AC8
need "$CR" AC8 'never re-dispatches the first critique'
need "$CR" AC8 'deletes `<run dir>/critic-<phase>.md` and clears its pointer'
need "$DES" AC8 'delete `<run dir>/architect.md` and `<run dir>/critic-design.md`'
need "$DES" AC8 'skip to **Critic — before the decision record** below'
need "$PLN" AC8 'delete `<run dir>/critic-plan.md` and clear `manifest.artifacts.critic-plan`'
need "$PLN" AC8 'skip to **Critic — before the plan completes** below'
# AC9
need "$AP" AC9 '| Critic stop (`ff-design`, `ff-plan`) | cross-turn |'
need "$CORE" AC9 '| Critic | `docs/schema/critic.md` |'
need "$SK" AC9 '`ff-code-architect` and `ff-critic` never edit code and write only their own report file'
need "$SK" AC9 'an independent **Critic** (`ff-critic`)'
need "$CX" AC9 '- `ff-critic`: design and plan critique'
if flat < "$SK" | grep -qF '`ff-code-architect`, `ff-code-reviewer`, `ff-diagnostician`) are strictly read-only'; then
  err "AC9: SKILL.md still lists ff-code-architect as strictly read-only"; else ok "AC9: SKILL.md no longer calls the architect read-only"; fi
for t in templates/design.md templates/plan.md templates/plan-bugfix.md templates/decision.md; do
  grep -qiwE 'critic|ff-critic' "$t" && err "AC9: $t must stay unchanged (no Critic section)" || ok "AC9: $t has no Critic section"
done
DIST="dist/codex/feature-flow"
for rel in "$AG" "$CR" "$DES" "$PLN" "$CORE" "$AP" "$SK" "$CX" config/defaults.json README.md; do
  cmp -s "$rel" "$DIST/$rel" && ok "dist parity: $rel" \
    || err "dist parity: $rel differs from or is missing in $DIST/$rel (re-run scripts/package-codex-plugin.sh)"
done

if [ "$fail" -eq 0 ]; then echo "PASS: critic guard"; else echo "RED: critic guard failed"; fi
exit "$fail"
