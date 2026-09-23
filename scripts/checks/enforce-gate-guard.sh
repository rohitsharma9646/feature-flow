#!/usr/bin/env bash
# Behavioral and structural guard for the thin native Claude lifecycle adapter.
set -euo pipefail
cd "$(dirname "$0")/../.."

go_tool="${GO:-go}"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/package/bin" "$tmp/package/hooks" "$tmp/repo/.feature-flow/run"
"$go_tool" build -o "$tmp/package/bin/ff-integrity" ./cmd/ff-integrity
cp hooks/enforce-gate "$tmp/package/hooks/enforce-gate"
chmod +x "$tmp/package/hooks/enforce-gate"

payload() {
  jq -cn --arg fp "$1" --arg content "$2" --arg cwd "$tmp/repo" \
    '{hook_event_name:"PreToolUse",tool_name:"Write",cwd:$cwd,
      tool_input:{file_path:$fp,content:$content}}'
}

manifest="$(jq \
  '.currentPhase="implement"
   | .phases.implement={"status":"in_progress","artifact":null}
   | .signOff.signed=false
   | .signOff.date=null
   | .signOff.actor=null
   | .signOff.evidenceRef=null' \
  integrity/testdata/manifests/current-feature.json)"
target="$tmp/repo/.feature-flow/run/manifest.json"
printf '%s\n' "$manifest" > "$target"

out="$(payload "$target" "$manifest" |
  "$tmp/package/bin/ff-integrity" host-preflight --host claude --mode enforce)"
grep -q '"permissionDecision":"deny"' <<<"$out"
grep -q 'FFI_TERMINAL_INCONSISTENT' <<<"$out"

signed="$(jq '.signOff.signed=true | .signOff.date="2026-08-03"' <<<"$manifest")"
out="$(payload "$target" "$signed" |
  "$tmp/package/bin/ff-integrity" host-preflight --host claude --mode enforce)"
test -z "$out"

out="$(payload "$target" '{not-json' |
  "$tmp/package/bin/ff-integrity" host-preflight --host claude --mode enforce)"
grep -q '"permissionDecision":"deny"' <<<"$out"
grep -q 'FFI_SCHEMA_INVALID' <<<"$out"

out="$(payload "$tmp/repo/README.md" '.feature-flow/run/manifest.json' |
  "$tmp/package/hooks/enforce-gate")"
test -z "$out"

out="$(payload "$target" "$manifest" | "$tmp/package/hooks/enforce-gate")"
grep -q '"systemMessage"' <<<"$out"
grep -q 'FFI_CAPABILITY_DEGRADED' <<<"$out"

mv "$tmp/package/bin/ff-integrity" "$tmp/package/bin/ff-integrity.missing"
out="$(payload "$target" "$signed" | "$tmp/package/hooks/enforce-gate")"
grep -q '"systemMessage"' <<<"$out"
if grep -q '"permissionDecision":"deny"' <<<"$out"; then
  echo "FAIL: observe-mode missing binary must not deny" >&2
  exit 1
fi
grep -q 'FFI_CAPABILITY_DEGRADED' <<<"$out"

out="$(payload "$tmp/repo/notes.txt" 'unrelated' | "$tmp/package/hooks/enforce-gate")"
if [[ -n "$out" ]]; then
  echo "FAIL: missing binary must stay silent for unrelated calls: $out" >&2
  exit 1
fi

cp -R adapters "$tmp/package/adapters"
mv "$tmp/package/bin/ff-integrity.missing" "$tmp/package/bin/ff-integrity.absent"
out="$(payload "$tmp/repo/notes.txt" 'unrelated' |
  PLUGIN_ROOT="$tmp/package" "$tmp/package/adapters/codex/hooks/run-integrity")"
if [[ -n "$out" ]]; then
  echo "FAIL: Codex launcher without binary must stay silent for unrelated calls: $out" >&2
  exit 1
fi
out="$(payload "$target" "$signed" |
  PLUGIN_ROOT="$tmp/package" "$tmp/package/adapters/codex/hooks/run-integrity")"
grep -q 'FFI_CAPABILITY_DEGRADED' <<<"$out"

if grep -E -n 'signOff|artifacts|assurance|revision|currentPhase|Gate [AB]|jq ' \
  hooks/enforce-gate hooks/run-hook.cmd; then
  echo "FAIL: host launch assets contain workflow policy" >&2
  exit 1
fi

"$go_tool" test ./integrity/hostadapter ./integrity/preflight
echo "PASS: native Claude adapter enforces on demand, stages observe-only, and ignores unrelated writes"
