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

# ---- Gate B: reach done ------------------------------------------------------
rd="$(mkrun b-ok)"; printf '# Verify\n\n## Verdict\npass\n' > "$rd/verify.md"
m='{"track":"feature","currentPhase":"done","phases":{"verify":{"status":"complete"}},"artifacts":{"verify":"verify.md"}}'
assert_allow "GateB: feature done + valid verify.md" "$(run "$rd/manifest.json" "$m")"

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
rd="$(mkrun b-renamed)"; printf '# Verify\n' > "$rd/verify-out.md"
m='{"track":"feature","currentPhase":"done","phases":{"verify":{"status":"complete"}},"artifacts":{"verify":"verify-out.md"}}'
assert_allow "GateB/AC5: honors renamed artifacts.verify pointer" "$(run "$rd/manifest.json" "$m")"

# bugfix needs BOTH verify + review
rd="$(mkrun b-bugfix-ok)"; printf '# Verify\n' > "$rd/verify.md"; printf '# Review\n' > "$rd/review.md"
m='{"track":"bugfix","currentPhase":"done","phases":{"verify":{"status":"complete"},"review":{"status":"complete"}},"artifacts":{"verify":"verify.md","review":"review.md"}}'
assert_allow "GateB: bugfix done + verify + review" "$(run "$rd/manifest.json" "$m")"
rd="$(mkrun b-bugfix-noreview)"; printf '# Verify\n' > "$rd/verify.md"
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

if [ "$fail" -eq 0 ]; then echo "PASS: enforce-gate guard"; else echo "RED: enforce-gate guard failed"; fi
exit "$fail"
