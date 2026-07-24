#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

index="integrity/testdata/revision/v1/index.json"
jq -e '
  .schemaVersion == 1 and
  (.cases | length >= 14) and
  ([.cases[].id] | length == (unique | length)) and
  ([.cases[].test] | length == (unique | length)) and
  (.platformDispositions.windowsSymlinkTarget == "unsupported-fail-closed")
' "$index" >/dev/null

pattern="$(jq -r '[.cases[].test] | join("|")' "$index")"
output="$(go test -count=1 -run "$pattern" \
  ./integrity/revision/... ./integrity/assurance ./integrity/wp3 ./cmd/ff-integrity)"
printf '%s\n' "$output"

for test_name in $(jq -r '.cases[].test' "$index"); do
  grep -qE '^(ok|\\?)' <<<"$output" ||
    { echo "FAIL: no Go package executed for $test_name" >&2; exit 1; }
  grep -R -q "func ${test_name}(" integrity cmd ||
    { echo "FAIL: indexed test is missing: $test_name" >&2; exit 1; }
done

echo "PASS: WP3 executable corpus is complete and green"
