#!/usr/bin/env bash
set -u
cd "$(dirname "$0")/../.." || exit 2

if ! command -v go >/dev/null 2>&1; then
  echo "FAIL: Go toolchain is required for WP1 conformance" >&2
  exit 1
fi

go test ./... || exit 1
first="$(printf '%s' '{"schemaVersion":2}' | go run ./cmd/ff-integrity-classify)" || exit 1
second="$(printf '%s' '{"schemaVersion":2}' | TZ=Pacific/Honolulu LANG=C go run ./cmd/ff-integrity-classify)" || exit 1
[ "$first" = "$second" ] || { echo "FAIL: classifier output drifted across environment"; exit 1; }

echo "PASS: integrity conformance guard"
