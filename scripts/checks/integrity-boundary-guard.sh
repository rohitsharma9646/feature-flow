#!/usr/bin/env bash
set -u
cd "$(dirname "$0")/../.." || exit 2

fail=0
err() { echo "FAIL: $1"; fail=1; }
ok() { echo "ok:   $1"; }

if rg -n 'ff-integrity-classify|integrity/classifier' commands hooks templates config >/dev/null; then
  err "current mutation/procedure surfaces invoke the WP1 kernel"
else
  ok "current commands/hooks/templates/config do not invoke the WP1 kernel"
fi

for file in schemas/manifest-v1.schema.json schemas/golden-vector-v1.schema.json \
  integrity/protocol/v1/diagnostics.json integrity/testdata/vectors/v1/index.json; do
  jq -e . "$file" >/dev/null && ok "$file parses" || err "$file is invalid JSON"
done

if [ "$fail" -eq 0 ]; then echo "PASS: integrity boundary guard"; else echo "RED: integrity boundary guard"; fi
exit "$fail"
