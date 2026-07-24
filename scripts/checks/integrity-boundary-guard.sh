#!/usr/bin/env bash
set -u
cd "$(dirname "$0")/../.." || exit 2

fail=0
err() { echo "FAIL: $1"; fail=1; }
ok() { echo "ok:   $1"; }

if rg -n 'ff-integrity(?:-classify)?|integrity/(?:classifier|doctor|migration|storage)' \
    commands hooks templates config >/dev/null; then
  err "current mutation/procedure surfaces invoke the integrity runtime"
else
  ok "current commands/hooks/templates/config do not invoke doctor or migration"
fi

for file in schemas/manifest-v1.schema.json schemas/golden-vector-v1.schema.json \
  schemas/doctor-result-v1.schema.json schemas/migration-plan-v1.schema.json \
  integrity/protocol/v1/diagnostics.json integrity/testdata/vectors/v1/index.json \
  integrity/testdata/legacy/inventory-v1.json; do
  jq -e . "$file" >/dev/null && ok "$file parses" || err "$file is invalid JSON"
done

if [ "$fail" -eq 0 ]; then echo "PASS: integrity boundary guard"; else echo "RED: integrity boundary guard"; fi
exit "$fail"
