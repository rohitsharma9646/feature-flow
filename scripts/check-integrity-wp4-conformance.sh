#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

index="integrity/testdata/adapter/v1/index.json"
jq -e '
  .schemaVersion == 1 and
  (.cases | length >= 10) and
  ([.cases[].id] | length == (unique | length)) and
  ([.cases[].test] | length == (unique | length)) and
  .executableParityVectors == [
    "allowed-feature","denied-feature","allowed-bugfix","denied-bugfix","legacy",
    "malformed-current","terminal-incomplete","duplicate","payload-spoof","unrelated"
  ] and
  .paths == ["direct","claude","codex","packaged-claude","packaged-codex"] and
  .failureScenarios == ["FS1","FS2","FS3","FS4","FS5","FS6","FS7","FS8","FS9","FS10"] and
  ([.failureScenarioCoverage["FS1","FS2","FS3","FS4","FS5","FS6","FS7","FS8","FS9","FS10"] | length > 0] | all)
' "$index" >/dev/null

pattern="$(jq -r \
  '[.cases[].test, (.failureScenarioCoverage[] | .[])] | unique | join("|")' \
  "$index" | tr -d '\r')"
output="$(go test -count=1 -run "$pattern" \
  ./integrity/preflight ./integrity/hostadapter ./integrity/wp3 \
  ./integrity/assurance ./cmd/ff-integrity)"
printf '%s\n' "$output"

for test_name in $(jq -r \
  '[.cases[].test, (.failureScenarioCoverage[] | .[])] | unique[]' \
  "$index" | tr -d '\r'); do
  grep -R -F -q --include='*.go' "func ${test_name}(" integrity cmd schemas ||
    { echo "FAIL: indexed WP4 test is missing: $test_name" >&2; exit 1; }
done

go test ./schemas
echo "PASS: WP4 source direct/Claude/Codex corpus is complete and green"
