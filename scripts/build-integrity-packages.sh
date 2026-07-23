#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

target="${1:-}"
case "$target" in
  linux-x86_64) goos=linux; goarch=amd64; exe=ff-integrity-classify ;;
  linux-arm64) goos=linux; goarch=arm64; exe=ff-integrity-classify ;;
  macos-x86_64) goos=darwin; goarch=amd64; exe=ff-integrity-classify ;;
  macos-arm64) goos=darwin; goarch=arm64; exe=ff-integrity-classify ;;
  windows-x86_64) goos=windows; goarch=amd64; exe=ff-integrity-classify.exe ;;
  windows-arm64) goos=windows; goarch=arm64; exe=ff-integrity-classify.exe ;;
  *) echo "usage: $0 <linux-x86_64|linux-arm64|macos-x86_64|macos-arm64|windows-x86_64|windows-arm64>" >&2; exit 2 ;;
esac

output="dist/integrity/$target"
rm -rf "$output"
mkdir -p "$output/payload/bin" "$output/payload/schemas" \
  "$output/payload/integrity/protocol/v1" "$output/payload/integrity/testdata/smoke"

CGO_ENABLED=0 GOOS="$goos" GOARCH="$goarch" \
  go build -trimpath -ldflags='-s -w -buildid=' -o "$output/payload/bin/$exe" \
  ./cmd/ff-integrity-classify

cp schemas/manifest-v1.schema.json schemas/golden-vector-v1.schema.json "$output/payload/schemas/"
cp integrity/protocol/v1/diagnostics.json "$output/payload/integrity/protocol/v1/"
cp integrity/testdata/manifests/current-feature.json "$output/payload/integrity/testdata/smoke/"

(
  cd "$output/payload"
  find . -type f -print | LC_ALL=C sort | while IFS= read -r file; do
    if command -v sha256sum >/dev/null 2>&1; then
      sha256sum "$file"
    else
      shasum -a 256 "$file"
    fi
  done
) > "$output/checksums.sha256"

for host in claude codex; do
  mkdir -p "$output/$host"
  cp -R "$output/payload/." "$output/$host/"
done

diff -qr "$output/claude" "$output/codex"
echo "PASS: assembled $target Claude/Codex payloads are byte-identical"
