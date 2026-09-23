#!/usr/bin/env bash
# Behavioral guard for the SessionStart hook (hooks/session-start), v0.19.0.
# Feeds crafted SessionStart JSON ({source, cwd}) and asserts on the emitted context:
# the static discovery pointer always; plus, when active runs exist, a compact
# active-run block so a compacted / cleared session re-anchors on on-disk state.
set -u
cd "$(dirname "$0")/../.." || exit 2
HOOK="hooks/session-start"
fail=0
err() { echo "FAIL: $1"; fail=1; }
ok()  { echo "ok:   $1"; }

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
export CLAUDE_PLUGIN_ROOT="$PWD"
unset CURSOR_PLUGIN_ROOT COPILOT_CLI

# ctx <source> <cwd> : run the hook, print the additionalContext string (or RAW:<output>
# when the output is not the expected JSON shape, so assertions fail loudly).
ctx() {
  local out
  out="$(jq -cn --arg s "$1" --arg c "$2" '{hook_event_name:"SessionStart", source:$s, cwd:$c}' | bash "$HOOK")"
  printf '%s' "$out" | jq -er '.hookSpecificOutput.additionalContext' 2>/dev/null || printf 'RAW:%s' "$out"
}
has()    { case "$2" in *"$3"*) ok "$1" ;; *) err "$1 — missing '$3' in: $2" ;; esac; }
hasnot() { case "$2" in *"$3"*) err "$1 — unexpected '$3' in: $2" ;; *) ok "$1" ;; esac; }

# mkrun <project> <slug> <manifest-json> [base]
mkrun() { local d="$TMP/$1/${4:-.feature-flow}/$2"; mkdir -p "$d"; printf '%s\n' "$3" > "$d/manifest.json"; }

POINTER='feature-flow plugin is installed'
ACTIVE='Active feature-flow run'

# S1: no runs → the static pointer only (unchanged behavior).
mkdir -p "$TMP/empty"
c="$(ctx startup "$TMP/empty")"
has    "no runs: pointer present" "$c" "$POINTER"
hasnot "no runs: no active-run block" "$c" "$ACTIVE"

# S2: one active run after compaction → re-anchor block with the run's state.
mkrun p1 add-csv '{"slug":"add-csv","track":"feature","tier":"full","autopilot":true,"currentPhase":"design","updatedAt":"2026-09-20T10:00:00Z","closedAt":null,"phases":{"design":{"status":"in_progress"}},"signOff":{"signed":true},"artifacts":{"spec":"spec.md","decision":"docs/ff/2026-09-20-add-csv/decision.md"}}'
c="$(ctx compact "$TMP/p1")"
has "compact: pointer still present"        "$c" "$POINTER"
has "compact: active-run block"             "$c" "$ACTIVE"
has "compact: slug"                         "$c" "add-csv"
has "compact: track/tier"                   "$c" "feature/full"
has "compact: phase + status"               "$c" "design (in_progress)"
has "compact: autopilot"                    "$c" "autopilot: on"
has "compact: sign-off"                     "$c" "signed off: yes"
has "compact: resume command"               "$c" "/feature-flow:ff-resume add-csv"
has "compact: bare artifact → run-dir path" "$c" "spec=.feature-flow/add-csv/spec.md"
has "compact: slashed artifact → as-is"     "$c" "decision=docs/ff/2026-09-20-add-csv/decision.md"
has "compact: mid-run wording"              "$c" "You were mid-run"
has "compact: re-read-from-disk directive"  "$c" "re-read"

# S3: startup / clear use the conditional wording, not "mid-run".
for s in startup clear; do
  c="$(ctx "$s" "$TMP/p1")"
  has    "$s: active-run block"        "$c" "$ACTIVE"
  has    "$s: conditional wording"     "$c" "If the user's request relates"
  hasnot "$s: no mid-run assertion"    "$c" "You were mid-run"
done

# S4: done / abandoned / closed runs are never listed.
mkrun p2 finished  '{"slug":"finished","track":"feature","currentPhase":"done","updatedAt":"2026-09-20T10:00:00Z"}'
mkrun p2 dropped   '{"slug":"dropped","track":"bugfix","currentPhase":"abandoned","updatedAt":"2026-09-20T10:00:00Z"}'
mkrun p2 shut      '{"slug":"shut","track":"feature","currentPhase":"done","closedAt":"2026-09-21T10:00:00Z","updatedAt":"2026-09-21T10:00:00Z"}'
mkrun p2 stale-closed '{"slug":"stale-closed","track":"feature","currentPhase":"verify","closedAt":"2026-09-21T10:00:00Z","updatedAt":"2026-09-21T10:00:00Z"}'
c="$(ctx compact "$TMP/p2")"
hasnot "terminal runs only: no active-run block" "$c" "$ACTIVE"

# S5: corrupt manifest is skipped; valid siblings still listed.
mkrun p3 good '{"slug":"good","track":"bugfix","tier":"lite","currentPhase":"diagnose","updatedAt":"2026-09-20T10:00:00Z","phases":{"diagnose":{"status":"in_progress"}}}'
mkdir -p "$TMP/p3/.feature-flow/broken"; printf '{not json' > "$TMP/p3/.feature-flow/broken/manifest.json"
c="$(ctx compact "$TMP/p3")"
has    "corrupt sibling: valid run listed" "$c" "good"
hasnot "corrupt sibling: broken run skipped" "$c" "broken"
has    "bugfix lite: signed-off n/a"      "$c" "signed off: n/a"

# S6: cap at 3, newest updatedAt first.
for i in 1 2 3 4; do
  mkrun p4 "run-$i" "{\"slug\":\"run-$i\",\"track\":\"feature\",\"tier\":\"full\",\"currentPhase\":\"plan\",\"updatedAt\":\"2026-09-0${i}T10:00:00Z\"}"
done
c="$(ctx compact "$TMP/p4")"
hasnot "cap: oldest run dropped" "$c" "run-1"
has    "cap: overflow noted"     "$c" "/feature-flow:ff-list"
first="$(printf '%s' "$c" | grep -o 'run-[0-9]' | head -1)"
[ "$first" = "run-4" ] && ok "cap: newest run listed first" || err "cap: expected run-4 first, got '$first'"

# S7: paths.base override in .feature-flow.json is honored.
mkrun p5 custom '{"slug":"custom","track":"feature","tier":"lite","currentPhase":"clarify","updatedAt":"2026-09-20T10:00:00Z","signOff":{"signed":false},"artifacts":{"spec":"spec.md"}}' .ff-runs
printf '{"paths":{"base":".ff-runs"}}' > "$TMP/p5/.feature-flow.json"
c="$(ctx compact "$TMP/p5")"
has "paths.base: run found"            "$c" "custom"
has "paths.base: path uses custom base" "$c" "spec=.ff-runs/custom/spec.md"
has "unsigned feature: signed off: no" "$c" "signed off: no"

# S8: jq absent → static pointer only, still valid JSON (fail-open, never breaks startup).
shim="$TMP/shim"; mkdir -p "$shim"
for b in cat dirname grep sed; do ln -sf "$(command -v "$b")" "$shim/$b"; done
out="$(jq -cn --arg c "$TMP/p1" '{source:"compact", cwd:$c}' | PATH="$shim" "$(command -v bash)" "$HOOK")"
c="$(printf '%s' "$out" | jq -er '.hookSpecificOutput.additionalContext' 2>/dev/null || printf 'RAW:%s' "$out")"
has    "jq absent: pointer present, valid JSON" "$c" "$POINTER"
hasnot "jq absent: no active-run block"         "$c" "$ACTIVE"

# S9: no stdin payload at all (older harness) → static pointer, valid JSON.
out="$(bash "$HOOK" </dev/null)"
printf '%s' "$out" | jq -e '.hookSpecificOutput.additionalContext' >/dev/null 2>&1 \
  && ok "empty stdin: valid JSON pointer" || err "empty stdin: invalid output: $out"

# S10: hooks.json still fires SessionStart on compact + clear (the re-anchor moments).
m="$(jq -r '.hooks.SessionStart[].matcher' hooks/hooks.json)"
for s in startup clear compact; do
  printf '%s' "$s" | grep -qxE "$m" && ok "hooks.json SessionStart matcher covers $s" \
    || err "hooks.json SessionStart matcher '$m' misses $s"
done

if [ "$fail" -eq 0 ]; then echo "PASS: session-start guard"; else echo "RED: session-start guard failed"; fi
exit "$fail"
