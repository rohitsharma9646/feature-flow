#!/usr/bin/env bash
set -euo pipefail

if [[ "$#" -ne 6 ]]; then
  echo "usage: $0 <fixture-root> <direct> <source-claude> <source-codex> <packaged-claude> <packaged-codex>" >&2
  exit 2
fi

fixture_root="$1"
direct_bin="$2"
source_claude_bin="$3"
source_codex_bin="$4"
packaged_claude_bin="$5"
packaged_codex_bin="$6"
mkdir -p "$fixture_root"
fixture_root="$(cd "$fixture_root" && pwd)"
repository="$fixture_root/repo"
run_root="$repository/.feature-flow/run"
manifest="$run_root/manifest.json"
mkdir -p "$run_root"

projection_direct() {
  jq -r '[.applicable,.allowed,([(.diagnostics // [])[].code] | join(","))] | @tsv' "$1"
}

projection_host() {
  local output="$1"
  if [[ ! -s "$output" ]]; then
    printf 'false\ttrue\t\n'
    return
  fi
  jq -r '
    if .systemMessage then
      [true,true,(.systemMessage | sub("^Feature Flow integrity observe-only: ";""))]
    elif .hookSpecificOutput then
      [true,false,(.hookSpecificOutput.permissionDecisionReason |
        sub("^Feature Flow integrity preflight denied: ";""))]
    else error("unknown host response")
    end | @tsv
  ' "$output"
}

make_patch() {
  local current="$1" proposed="$2" output="$3"
  {
    printf '%s\n' '*** Begin Patch' '*** Update File: .feature-flow/run/manifest.json' '@@'
    sed 's/^/-/' "$current"
    sed 's/^/+/' "$proposed"
    printf '%s\n' '*** End Patch'
  } > "$output"
}

run_manifest_vector() {
  local id="$1" current="$2" proposed="$3"
  cp "$current" "$manifest"
  jq -n \
    --arg repo "$repository" --arg run "$run_root" --arg target ".feature-flow/run/manifest.json" \
    --slurpfile proposed "$proposed" \
    '{
      schemaVersion:1,host:"direct",event:"command_preflight",
      operation:"manifest_mutation",toolClass:"file_write",target:$target,
      context:{repositoryRoot:$repo,runRoot:$run},
      proposedManifest:$proposed[0],
      requiredCapabilities:["command_preflight","kernel","schema","json_output"],
      enforcementMode:"observe"
    }' > "$fixture_root/$id-direct.json"
  jq -n \
    --arg cwd "$repository" --arg path "$manifest" --rawfile content "$proposed" \
    '{hook_event_name:"PreToolUse",cwd:$cwd,tool_name:"Write",
      tool_input:{file_path:$path,content:$content}}' > "$fixture_root/$id-claude.json"
  make_patch "$current" "$proposed" "$fixture_root/$id.patch"
  jq -n \
    --arg cwd "$repository" --rawfile command "$fixture_root/$id.patch" \
    '{hook_event_name:"PreToolUse",cwd:$cwd,tool_name:"apply_patch",
      tool_input:{command:$command}}' > "$fixture_root/$id-codex.json"

  "$direct_bin" preflight --input "$fixture_root/$id-direct.json" --format json \
    > "$fixture_root/$id-direct.out"
  "$source_claude_bin" host-preflight --host claude --mode observe \
    < "$fixture_root/$id-claude.json" > "$fixture_root/$id-source-claude.out"
  "$source_codex_bin" host-preflight --host codex --mode observe \
    < "$fixture_root/$id-codex.json" > "$fixture_root/$id-source-codex.out"
  "$packaged_claude_bin" host-preflight --host claude --mode observe \
    < "$fixture_root/$id-claude.json" > "$fixture_root/$id-packaged-claude.out"
  "$packaged_codex_bin" host-preflight --host codex --mode observe \
    < "$fixture_root/$id-codex.json" > "$fixture_root/$id-packaged-codex.out"

  projection_direct "$fixture_root/$id-direct.out" > "$fixture_root/$id.expected"
  for path in source-claude source-codex packaged-claude packaged-codex; do
    projection_host "$fixture_root/$id-$path.out" > "$fixture_root/$id-$path.projection"
    cmp "$fixture_root/$id.expected" "$fixture_root/$id-$path.projection" ||
      { echo "FAIL: five-path drift for $id on $path" >&2; exit 1; }
  done
  echo "ok:   five-path vector $id"
}

cp integrity/testdata/manifests/current-feature.json "$fixture_root/current.json"
jq '.' "$fixture_root/current.json" > "$fixture_root/allowed-feature.json"
jq '.currentPhase="implement" |
    .phases.implement={"status":"in_progress","artifact":null}' \
  "$fixture_root/current.json" > "$fixture_root/denied-feature.json"
cp integrity/testdata/manifests/current-bugfix.json "$fixture_root/current-bugfix.json"
jq '.currentPhase="implement" |
    .phases.diagnose={"status":"complete","artifact":"diagnosis.md"} |
    .phases.implement={"status":"in_progress","artifact":null}' \
  "$fixture_root/current-bugfix.json" > "$fixture_root/allowed-bugfix.json"
jq '.currentPhase="implement" |
    .phases.implement={"status":"in_progress","artifact":null}' \
  "$fixture_root/current-bugfix.json" > "$fixture_root/denied-bugfix.json"
cp integrity/testdata/manifests/legacy.json "$fixture_root/legacy.json"
printf '%s\n' '{"schemaVersion":1,"track":"feature"}' > "$fixture_root/malformed-current.json"
jq '.currentPhase="done"' "$fixture_root/current.json" > "$fixture_root/terminal-incomplete.json"

run_manifest_vector allowed-feature "$fixture_root/current.json" "$fixture_root/allowed-feature.json"
run_manifest_vector denied-feature "$fixture_root/current.json" "$fixture_root/denied-feature.json"
run_manifest_vector allowed-bugfix "$fixture_root/current-bugfix.json" "$fixture_root/allowed-bugfix.json"
run_manifest_vector denied-bugfix "$fixture_root/current-bugfix.json" "$fixture_root/denied-bugfix.json"
run_manifest_vector legacy "$fixture_root/legacy.json" "$fixture_root/legacy.json"
run_manifest_vector malformed-current "$fixture_root/current.json" "$fixture_root/malformed-current.json"
run_manifest_vector terminal-incomplete "$fixture_root/current.json" "$fixture_root/terminal-incomplete.json"
run_manifest_vector duplicate "$fixture_root/current.json" "$fixture_root/allowed-feature.json"
cp "$fixture_root/duplicate.expected" "$fixture_root/duplicate-first.expected"
run_manifest_vector duplicate "$fixture_root/current.json" "$fixture_root/allowed-feature.json"
cmp "$fixture_root/duplicate-first.expected" "$fixture_root/duplicate.expected"

jq -n \
  --arg repo "$repository" --arg run "$run_root" \
  '{
    schemaVersion:1,host:"direct",event:"command_preflight",
    operation:"manifest_mutation",toolClass:"file_write",target:"README.md",
    context:{repositoryRoot:$repo,runRoot:$run},proposedManifest:{},
    requiredCapabilities:["command_preflight","kernel","schema","json_output"],
    enforcementMode:"observe"
  }' > "$fixture_root/unrelated-direct.json"
jq -n --arg cwd "$repository" \
  '{hook_event_name:"PreToolUse",cwd:$cwd,tool_name:"Write",
    tool_input:{file_path:"README.md",content:"text"}}' > "$fixture_root/unrelated-claude.json"
jq -n --arg cwd "$repository" \
  '{hook_event_name:"PreToolUse",cwd:$cwd,tool_name:"apply_patch",
    tool_input:{command:"*** Begin Patch\n*** Add File: README.md\n+text\n*** End Patch\n"}}' \
  > "$fixture_root/unrelated-codex.json"
cp "$fixture_root/unrelated-direct.json" "$fixture_root/payload-spoof-direct.json"
jq -n --arg cwd "$repository" \
  '{hook_event_name:"PreToolUse",cwd:$cwd,tool_name:"Write",
    tool_input:{file_path:"README.md",content:".feature-flow/run/manifest.json"}}' \
  > "$fixture_root/payload-spoof-claude.json"
jq -n --arg cwd "$repository" \
  '{hook_event_name:"PreToolUse",cwd:$cwd,tool_name:"apply_patch",
    tool_input:{command:"*** Begin Patch\n*** Add File: README.md\n+.feature-flow/run/manifest.json\n*** End Patch\n"}}' \
  > "$fixture_root/payload-spoof-codex.json"

"$direct_bin" preflight --input "$fixture_root/unrelated-direct.json" --format json \
  > "$fixture_root/unrelated-direct.out"
"$source_claude_bin" host-preflight --host claude --mode observe \
  < "$fixture_root/unrelated-claude.json" > "$fixture_root/unrelated-source-claude.out"
"$source_codex_bin" host-preflight --host codex --mode observe \
  < "$fixture_root/unrelated-codex.json" > "$fixture_root/unrelated-source-codex.out"
"$packaged_claude_bin" host-preflight --host claude --mode observe \
  < "$fixture_root/unrelated-claude.json" > "$fixture_root/unrelated-packaged-claude.out"
"$packaged_codex_bin" host-preflight --host codex --mode observe \
  < "$fixture_root/unrelated-codex.json" > "$fixture_root/unrelated-packaged-codex.out"
projection_direct "$fixture_root/unrelated-direct.out" > "$fixture_root/unrelated.expected"
for path in source-claude source-codex packaged-claude packaged-codex; do
  projection_host "$fixture_root/unrelated-$path.out" > "$fixture_root/unrelated-$path.projection"
  cmp "$fixture_root/unrelated.expected" "$fixture_root/unrelated-$path.projection"
done
echo "ok:   five-path vector unrelated"

cp "$fixture_root/unrelated-direct.out" "$fixture_root/payload-spoof-direct.out"
"$source_claude_bin" host-preflight --host claude --mode observe \
  < "$fixture_root/payload-spoof-claude.json" > "$fixture_root/payload-spoof-source-claude.out"
"$source_codex_bin" host-preflight --host codex --mode observe \
  < "$fixture_root/payload-spoof-codex.json" > "$fixture_root/payload-spoof-source-codex.out"
"$packaged_claude_bin" host-preflight --host claude --mode observe \
  < "$fixture_root/payload-spoof-claude.json" > "$fixture_root/payload-spoof-packaged-claude.out"
"$packaged_codex_bin" host-preflight --host codex --mode observe \
  < "$fixture_root/payload-spoof-codex.json" > "$fixture_root/payload-spoof-packaged-codex.out"
cp "$fixture_root/unrelated.expected" "$fixture_root/payload-spoof.expected"
for path in source-claude source-codex packaged-claude packaged-codex; do
  projection_host "$fixture_root/payload-spoof-$path.out" \
    > "$fixture_root/payload-spoof-$path.projection"
  cmp "$fixture_root/payload-spoof.expected" "$fixture_root/payload-spoof-$path.projection"
done
echo "ok:   five-path vector payload-spoof"

echo "PASS: every executable WP4 parity vector matches across all five paths"
