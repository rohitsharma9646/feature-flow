#!/usr/bin/env bash
# Behavioral guard for the M1 enforcement hook (hooks/enforce-gate).
# Feeds crafted PreToolUse JSON to the hook and asserts allow / deny / warn.
# Unlike the structural grep guards, this exercises real decision logic.
set -u
cd "$(dirname "$0")/../.." || exit 2
HOOK="hooks/enforce-gate"
fail=0
err() { echo "FAIL: $1"; fail=1; }
ok()  { echo "ok:   $1"; }

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

# payload <file_path> <content-string> <cwd> : build a PreToolUse Write payload.
# `content` is a STRING (Write passes file content as a string), matching reality.
payload() { jq -cn --arg fp "$1" --arg c "$2" --arg cwd "$3" \
  '{tool_name:"Write", tool_input:{file_path:$fp, content:$c}, cwd:$cwd}'; }

mkrun() { local d="$TMP/.feature-flow/$1"; mkdir -p "$d"; printf '%s' "$d"; }

assert_deny()  { printf '%s' "$2" | grep -q '"permissionDecision":"deny"' \
  && printf '%s' "$2" | grep -q 'Gate [AB]' \
  && ok "$1" || err "$1 — expected DENY naming a gate, got: ${2:-<empty>}"; }   # AC7: reason names the gate
assert_allow() { [ -z "$2" ] \
  && ok "$1" || err "$1 — expected ALLOW (no output), got: $2"; }
assert_warn()  { printf '%s' "$2" | grep -q '"systemMessage"' \
  && ok "$1" || err "$1 — expected systemMessage warn, got: ${2:-<empty>}"; }

run() { payload "$1" "$2" "${3:-$TMP}" | bash "$HOOK"; }  # echoes hook stdout

# ---- Gate A: enter implement -------------------------------------------------
rd="$(mkrun a-feat)"
m='{"track":"feature","tier":"full","currentPhase":"implement","phases":{"implement":{"status":"in_progress"}},"signOff":{"signed":false},"artifacts":{}}'
assert_deny  "GateA: feature unsigned → implement" "$(run "$rd/manifest.json" "$m")"
m='{"track":"feature","tier":"full","currentPhase":"implement","phases":{"implement":{"status":"in_progress"}},"signOff":{"signed":true},"artifacts":{}}'
assert_allow "GateA: feature signed → implement"   "$(run "$rd/manifest.json" "$m")"
m='{"track":"bugfix","tier":"lite","currentPhase":"implement","phases":{"diagnose":{"status":"in_progress"},"implement":{"status":"in_progress"}},"signOff":{"signed":false}}'
assert_deny  "GateA: bugfix-lite diagnose incomplete → implement" "$(run "$rd/manifest.json" "$m")"
m='{"track":"bugfix","tier":"lite","currentPhase":"implement","phases":{"diagnose":{"status":"complete"},"implement":{"status":"in_progress"}},"signOff":{"signed":false}}'
assert_allow "GateA: bugfix-lite diagnose complete → implement (no sign-off needed)" "$(run "$rd/manifest.json" "$m")"
m='{"track":"bugfix","tier":"full","currentPhase":"implement","phases":{"implement":{"status":"in_progress"}},"signOff":{"signed":false}}'
assert_deny  "GateA: bugfix-full unsigned → implement" "$(run "$rd/manifest.json" "$m")"
# feature/lite is covered by the feature/* arm with NO hook change (M2/AC8)
m='{"track":"feature","tier":"lite","currentPhase":"implement","phases":{"implement":{"status":"in_progress"}},"signOff":{"signed":false},"artifacts":{}}'
assert_deny  "GateA: feature-lite unsigned → implement (feature/* arm covers lite)" "$(run "$rd/manifest.json" "$m")"
m='{"track":"feature","tier":"lite","currentPhase":"implement","phases":{"implement":{"status":"in_progress"}},"signOff":{"signed":true},"artifacts":{}}'
assert_allow "GateA: feature-lite signed → implement" "$(run "$rd/manifest.json" "$m")"

# ---- Gate B: reach done ------------------------------------------------------
# v0.9.0/AC10: the historic stub (heading but no evidence content) must now DENY.
rd="$(mkrun b-ok)"; printf '# Verify\n\n## Verdict\npass\n' > "$rd/verify.md"
m='{"track":"feature","currentPhase":"done","phases":{"verify":{"status":"complete"}},"artifacts":{"verify":"verify.md"}}'
assert_deny  "GateB/AC10: legacy stub verify.md (no Contract mapping) → denied" "$(run "$rd/manifest.json" "$m")"

rd="$(mkrun b-filled)"
printf '# Verify\n\n## Contract mapping\n\n### AC1: thing works\n- **Evidence:** `make test` — exit 0 — all green\n\n## Verdict\npass\n' > "$rd/verify.md"
assert_allow "GateB/AC10: filled report (Contract mapping + status token) → allowed" "$(run "$rd/manifest.json" "$m")"

rd="$(mkrun b-headingonly)"; printf '# Verify\n\n## Contract mapping\n\nlooks fine to me\n' > "$rd/verify.md"
assert_deny  "GateB/AC10: Contract mapping without a captured status token → denied" "$(run "$rd/manifest.json" "$m")"

# The SHIPPED TEMPLATE itself (verbatim, unfilled) must never pass Gate B — pins the
# placeholder-contains-a-real-status-token regression class (a bare digit in a skeleton
# line would make the content check vacuous).
rd="$(mkrun b-template)"; cp templates/verify.md "$rd/verify.md"
assert_deny  "GateB/AC10: verbatim unfilled template → denied" "$(run "$rd/manifest.json" "$m")"

rd="$(mkrun b-missing)"
m='{"track":"feature","currentPhase":"done","phases":{"verify":{"status":"complete"}},"artifacts":{"verify":"verify.md"}}'
assert_deny  "GateB: feature done, verify.md absent" "$(run "$rd/manifest.json" "$m")"

rd="$(mkrun b-empty)"; : > "$rd/verify.md"
assert_deny  "GateB: feature done, verify.md empty" "$(run "$rd/manifest.json" "$m")"

rd="$(mkrun b-noheading)"; printf 'plain text, no heading\n' > "$rd/verify.md"
assert_deny  "GateB: feature done, verify.md has no heading" "$(run "$rd/manifest.json" "$m")"

rd="$(mkrun b-status)"; printf '# Verify\n' > "$rd/verify.md"
m='{"track":"feature","currentPhase":"done","phases":{"verify":{"status":"in_progress"}},"artifacts":{"verify":"verify.md"}}'
assert_deny  "GateB: feature done but verify.status != complete" "$(run "$rd/manifest.json" "$m")"

# AC5: renamed pointer honored (no hardcoded filename)
# (content enriched for v0.9.0/AC10 — this fixture tests the pointer, not content depth)
rd="$(mkrun b-renamed)"; printf '# Verify\n\n## Contract mapping\n\nAC1 — exit 0\n' > "$rd/verify-out.md"
m='{"track":"feature","currentPhase":"done","phases":{"verify":{"status":"complete"}},"artifacts":{"verify":"verify-out.md"}}'
assert_allow "GateB/AC5: honors renamed artifacts.verify pointer" "$(run "$rd/manifest.json" "$m")"

# bugfix needs BOTH verify + review. review.md stays a bare heading on purpose —
# the AC10 content check is verify-specific and must NOT apply to review.
rd="$(mkrun b-bugfix-ok)"; printf '# Verify\n\n## Contract mapping\n\nRED then GREEN — exit 0\n' > "$rd/verify.md"; printf '# Review\n' > "$rd/review.md"
m='{"track":"bugfix","currentPhase":"done","phases":{"verify":{"status":"complete"},"review":{"status":"complete"}},"artifacts":{"verify":"verify.md","review":"review.md"}}'
assert_allow "GateB: bugfix done + verify + review" "$(run "$rd/manifest.json" "$m")"
rd="$(mkrun b-bugfix-noreview)"; printf '# Verify\n\n## Contract mapping\n\nRED then GREEN — exit 0\n' > "$rd/verify.md"
assert_deny  "GateB: bugfix done, review.md absent" "$(run "$rd/manifest.json" "$m")"

# ---- Fast-exit + fail-open ---------------------------------------------------
assert_allow "non-manifest write → fast-exit allow" "$(run "$TMP/src/foo.js" 'console.log(1)')"
rd="$(mkrun fo-parse)"
assert_allow "unparseable proposed content → fail-open" "$(run "$rd/manifest.json" '{not valid json')"
m='{"currentPhase":"implement","phases":{"implement":{"status":"in_progress"}}}'
assert_allow "missing track → fail-open" "$(run "$rd/manifest.json" "$m")"

# kill switch: enforce=false allows an otherwise-illegal transition
printf '{"toggles":{"enforce":false}}' > "$TMP/.feature-flow.json"
m='{"track":"feature","tier":"full","currentPhase":"implement","phases":{"implement":{"status":"in_progress"}},"signOff":{"signed":false}}'
assert_allow "kill switch: toggles.enforce=false → allow" "$(run "$rd/manifest.json" "$m")"
rm -f "$TMP/.feature-flow.json"

# jq absent → warn + allow. Restricted PATH (coreutils shim, NO jq); absolute bash.
shim="$TMP/shim"; mkdir -p "$shim"
for b in cat dirname grep sed; do ln -sf "$(command -v "$b")" "$shim/$b"; done
out="$(payload "$rd/manifest.json" "$m" "$TMP" | PATH="$shim" "$(command -v bash)" "$HOOK")"
assert_warn "jq absent → systemMessage warning (fail-open)" "$out"

# ---- Dispatch seam: route a deny case through the run-hook.cmd WRAPPER, not the
# script directly. A chmod/path/wrapper regression would leave every other fixture
# green while enforcement is silently off in production — this is the only check
# that exercises hooks.json's actual dispatch target.
rd="$(mkrun seam)"
m='{"track":"feature","tier":"full","currentPhase":"implement","phases":{"implement":{"status":"in_progress"}},"signOff":{"signed":false}}'
out="$(payload "$rd/manifest.json" "$m" "$TMP" | bash hooks/run-hook.cmd enforce-gate)"
assert_deny "dispatch seam: run-hook.cmd → enforce-gate denies" "$out"

# ---- Edit / MultiEdit (v0.19.0): the gates judge the POST-edit manifest -----------
# Before v0.19.0 hooks.json matched only Write, so an Edit that flipped currentPhase to
# "done" bypassed both gates. The hook now reconstructs the proposed manifest from the
# on-disk file + the edit(s), then runs the same Gate A/B logic.
# payload_edit <file_path> <old> <new> <replace_all:true|false> [cwd]
payload_edit() { jq -cn --arg fp "$1" --arg o "$2" --arg n "$3" --argjson ra "$4" --arg cwd "${5:-$TMP}" \
  '{tool_name:"Edit", tool_input:{file_path:$fp, old_string:$o, new_string:$n, replace_all:$ra}, cwd:$cwd}'; }
# payload_multi <file_path> <edits-json-array> [cwd]
payload_multi() { jq -cn --arg fp "$1" --argjson e "$2" --arg cwd "${3:-$TMP}" \
  '{tool_name:"MultiEdit", tool_input:{file_path:$fp, edits:$e}, cwd:$cwd}'; }
redit()  { payload_edit "$@" | bash "$HOOK"; }
rmulti() { payload_multi "$@" | bash "$HOOK"; }

# E1: Edit flips a verify-phase run to done with no verify evidence on disk → Gate B.
rd="$(mkrun e-done)"
printf '{\n  "track": "feature",\n  "tier": "full",\n  "currentPhase": "verify",\n  "phases": {"verify": {"status": "complete"}},\n  "artifacts": {"verify": "verify.md"}\n}\n' > "$rd/manifest.json"
assert_deny  "Edit: currentPhase verify→done without verify.md → Gate B" \
  "$(redit "$rd/manifest.json" '"currentPhase": "verify"' '"currentPhase": "done"' false)"

# E2: same Edit once real evidence exists → allowed (the gate, not the tool, decides).
printf '# Verify\n\n## Contract mapping\n\nAC1 — exit 0\n' > "$rd/verify.md"
assert_allow "Edit: currentPhase verify→done with valid verify.md → allowed" \
  "$(redit "$rd/manifest.json" '"currentPhase": "verify"' '"currentPhase": "done"' false)"

# E3: Edit enters implement on an unsigned spec → Gate A.
rd="$(mkrun e-impl)"
printf '{"track":"feature","tier":"full","currentPhase":"plan","phases":{},"signOff":{"signed":false}}\n' > "$rd/manifest.json"
assert_deny  "Edit: currentPhase plan→implement unsigned → Gate A" \
  "$(redit "$rd/manifest.json" '"currentPhase":"plan"' '"currentPhase":"implement"' false)"

# E4: MultiEdit applies edits IN ORDER — entering implement without signing → Gate A;
# signing in the same MultiEdit → allowed.
assert_deny  "MultiEdit: enter implement, sign-off untouched → Gate A" \
  "$(rmulti "$rd/manifest.json" '[{"old_string":"\"currentPhase\":\"plan\"","new_string":"\"currentPhase\":\"implement\""}]')"
assert_allow "MultiEdit: sign off + enter implement → allowed" \
  "$(rmulti "$rd/manifest.json" '[{"old_string":"\"signed\":false","new_string":"\"signed\":true"},{"old_string":"\"currentPhase\":\"plan\"","new_string":"\"currentPhase\":\"implement\""}]')"

# E5: an unrelated Edit on a legal manifest → allowed.
rd="$(mkrun e-benign)"
printf '{"track":"feature","tier":"full","currentPhase":"implement","phases":{"implement":{"status":"in_progress"}},"signOff":{"signed":true},"updatedAt":"a"}\n' > "$rd/manifest.json"
assert_allow "Edit: unrelated field change on a legal manifest → allowed" \
  "$(redit "$rd/manifest.json" '"updatedAt":"a"' '"updatedAt":"b"' false)"

# E6: replace_all is honored. The first "verify" occurrence is lastNote, not currentPhase:
# replace_all=false changes only lastNote (currentPhase stays verify → allow);
# replace_all=true also rewrites currentPhase to done (no evidence → Gate B).
rd="$(mkrun e-replaceall)"
printf '{"lastNote":"verify","track":"feature","currentPhase":"verify","phases":{},"artifacts":{}}\n' > "$rd/manifest.json"
assert_allow "Edit: replace_all=false rewrites only the first occurrence → allowed" \
  "$(redit "$rd/manifest.json" '"verify"' '"done"' false)"
assert_deny  "Edit: replace_all=true rewrites currentPhase too → Gate B" \
  "$(redit "$rd/manifest.json" '"verify"' '"done"' true)"

# E7: fail-open on indeterminate edits (Claude Code rejects these edits itself).
assert_allow "Edit: old_string not found → fail-open" \
  "$(redit "$rd/manifest.json" '"no-such-text"' '"currentPhase":"done"' false)"
assert_allow "Edit: manifest file missing on disk → fail-open" \
  "$(redit "$TMP/.feature-flow/e-absent/manifest.json" '"currentPhase":"verify"' '"currentPhase":"done"' false)"
assert_allow "Edit: non-manifest file → fast-exit allow" \
  "$(redit "$TMP/src/foo.js" 'a' 'b' false)"

# E8: the dispatch surface itself — hooks.json must route Edit and MultiEdit to the gate,
# or every fixture above is green while production never calls the hook.
matcher="$(jq -r '.hooks.PreToolUse[] | select(.hooks[].command | test("enforce-gate")) | .matcher' hooks/hooks.json)"
for t in Write Edit MultiEdit; do
  printf '%s' "$t" | grep -qxE "$matcher" \
    && ok "hooks.json PreToolUse matcher routes $t to enforce-gate" \
    || err "hooks.json PreToolUse matcher '$matcher' does not match $t"
done

if [ "$fail" -eq 0 ]; then echo "PASS: enforce-gate guard"; else echo "RED: enforce-gate guard failed"; fi
exit "$fail"
