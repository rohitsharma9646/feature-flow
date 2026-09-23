#!/usr/bin/env bash
set -u
cd "$(dirname "$0")/../.." || exit 2

fail=0
err() { echo "FAIL: $1"; fail=1; }
ok() { echo "ok:   $1"; }

inventory="integrity/testdata/legacy/inventory-v1.json"
if jq -e '. as $root |
  (.sources | length) > 0 and
  all(.sources[];
    (.disposition | type == "string" and length > 0) and
    (if .disposition == "supported"
     then .profileId as $id | any($root.profiles[]; .profileId == $id and .disposition == "supported")
     else true end)
  )
' "$inventory" >/dev/null; then
  ok "every inventoried legacy source has one registered profile or explicit rationale"
else
  err "legacy inventory has an undisposed or unknown-profile source"
fi

duplicates="$(jq -r '.sources[] | [.reference,.digest] | @tsv' "$inventory" | sort | uniq -d)"
if [ -z "$duplicates" ]; then
  ok "legacy inventory source identities are unique"
else
  err "legacy inventory contains duplicate source identities"
fi

for id in X-LOSSLESS X-IDEMPOTENT X-AMBIGUOUS X-POINTER X-POINTER-DRIFT \
  X-LEGACY-DONE X-PREVIEW-NOWRITE X-POLICY-EQUIVALENCE; do
  if jq -e --arg id "$id" '.cases[] | select(.id == $id)' \
      integrity/testdata/migration/v1/index.json >/dev/null; then
    ok "migration corpus contains $id"
  else
    err "migration corpus missing $id"
  fi
done

if rg -n 'ff-integrity (?:doctor|migrate)|integrity/(?:doctor|migration|storage)' \
    hooks adapters/codex/hooks >/dev/null; then
  err "WP4 lifecycle surface activates WP2 diagnosis, migration, or storage"
else
  ok "WP2 doctor and migration remain directly invocable only"
fi

if [ "$fail" -eq 0 ]; then
  echo "PASS: WP2 integrity guard"
else
  echo "RED: WP2 integrity guard"
fi
exit "$fail"
