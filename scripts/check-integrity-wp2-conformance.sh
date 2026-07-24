#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

command -v go >/dev/null 2>&1 ||
  { echo "FAIL: Go toolchain is required for WP2 conformance" >&2; exit 1; }

for id in X-LOSSLESS X-IDEMPOTENT X-AMBIGUOUS X-POINTER X-POINTER-DRIFT \
  X-LEGACY-DONE X-PREVIEW-NOWRITE X-POLICY-EQUIVALENCE; do
  jq -e --arg id "$id" '.cases[] | select(.id == $id)' \
    integrity/testdata/migration/v1/index.json >/dev/null
done

go test ./integrity/jsonstrict ./integrity/diagnostics ./integrity/pathpolicy \
  ./integrity/observe ./integrity/doctor ./integrity/migration ./integrity/storage \
  ./cmd/ff-integrity

before="$(git status --porcelain=v1)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/legacy"
cp integrity/testdata/manifests/legacy.json "$tmp/legacy/manifest.json"
go run ./cmd/ff-integrity doctor --root "$tmp" --format json legacy >/dev/null || test "$?" -eq 1
go run ./cmd/ff-integrity migrate --root "$tmp" legacy --to 1 --dry-run --format json >/dev/null
test ! -e "$tmp/legacy/migration"
after="$(git status --porcelain=v1)"
test "$before" = "$after"

echo "PASS: WP2 doctor and migration conformance"
