#!/usr/bin/env bash
set -u
cd "$(dirname "$0")/../.." || exit 2

fail=0
err() { echo "FAIL: $1"; fail=1; }
ok() { echo "ok:   $1"; }

if rg -n 'ff-integrity (?:doctor|migrate)|integrity/(?:doctor|migration|storage)' \
    hooks adapters/codex/hooks >/dev/null; then
  err "host adapters invoke WP2 diagnosis, migration, or storage paths"
else
  ok "host adapters invoke no WP2 diagnosis, migration, or storage path"
fi

if rg -n 'signOff|artifacts|assurance|revision|currentPhase|Gate [AB]|jq ' \
    hooks/enforce-gate hooks/run-hook.cmd adapters/codex/hooks >/dev/null; then
  err "host adapters duplicate workflow policy"
else
  ok "host launch assets contain no workflow policy"
fi

for file in commands/ff.md commands/ff-explore.md commands/ff-clarify.md \
  commands/ff-design.md commands/ff-plan.md commands/ff-diagnose.md \
  commands/ff-implement.md commands/ff-review.md commands/ff-verify.md \
  commands/ff-deliver.md commands/ff-close.md commands/ff-abandon.md \
  commands/ff-resume.md; do
  marker_count="$(rg -c 'Integrity boundary — before every .*state write|Integrity boundary — before every manifest creation or state write|Integrity boundary — before every terminal state write' "$file" || true)"
  marker_line="$(rg -n -m1 'Integrity boundary — before every' "$file" | cut -d: -f1 || true)"
  mutation_line="$(rg -n -m1 'Set `phases\.|Set `closedAt|Set `currentPhase|then create one|write a manifest|write the manifest|reconstruct.*manifest' "$file" | cut -d: -f1 || true)"
  if [[ "$marker_count" == "1" && -n "$marker_line" &&
        ( -z "$mutation_line" || "$marker_line" -lt "$mutation_line" ) ]]; then
    ok "$file invokes canonical command preflight before its first manifest write"
  else
    err "$file lacks one canonical command preflight before its first manifest write"
  fi
done

for file in schemas/manifest-v1.schema.json schemas/golden-vector-v1.schema.json \
  schemas/doctor-result-v1.schema.json schemas/migration-plan-v1.schema.json \
  schemas/preflight-request-v1.schema.json schemas/preflight-result-v1.schema.json \
  schemas/capability-report-v1.schema.json schemas/wp4-corpus-v1.schema.json \
  integrity/protocol/v1/diagnostics.json integrity/testdata/vectors/v1/index.json \
  integrity/testdata/legacy/inventory-v1.json; do
  jq -e . "$file" >/dev/null && ok "$file parses" || err "$file is invalid JSON"
done

if [ "$fail" -eq 0 ]; then echo "PASS: integrity boundary guard"; else echo "RED: integrity boundary guard"; fi
exit "$fail"
