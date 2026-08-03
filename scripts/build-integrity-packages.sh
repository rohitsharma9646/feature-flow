#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

target="${1:-}"
[[ -n "$target" ]] || { echo "usage: $0 <target>" >&2; exit 2; }
IFS=$'\t' read -r goos goarch exe < <(
  go run ./cmd/ff-integrity-target release/targets.json "$target"
)
[[ -n "$goos" && -n "$goarch" && -n "$exe" ]] ||
  { echo "target metadata is incomplete: $target" >&2; exit 2; }

integrity_dist_root="${FF_INTEGRITY_DIST_ROOT:-dist/integrity}"
output="$integrity_dist_root/$target"
case "$exe" in
  *.exe) integrity_exe="ff-integrity.exe" ;;
  *) integrity_exe="ff-integrity" ;;
esac
rm -rf "$output"
mkdir -p "$output/payload/bin" "$output/payload/schemas" \
  "$output/payload/integrity/protocol/v1" "$output/payload/integrity/testdata/smoke" \
  "$output/payload/integrity/testdata/legacy" \
  "$output/payload/integrity/testdata/revision/v1" \
  "$output/payload/integrity/testdata/adapter/v1"

CGO_ENABLED=0 GOOS="$goos" GOARCH="$goarch" \
  go build -trimpath -ldflags='-s -w -buildid=' -o "$output/payload/bin/$exe" \
  ./cmd/ff-integrity-classify
CGO_ENABLED=0 GOOS="$goos" GOARCH="$goarch" \
  go build -trimpath -ldflags='-s -w -buildid=' -o "$output/payload/bin/$integrity_exe" \
  ./cmd/ff-integrity

cp schemas/manifest-v1.schema.json schemas/golden-vector-v1.schema.json \
  schemas/doctor-result-v1.schema.json schemas/migration-plan-v1.schema.json \
  schemas/code-revision-v1.schema.json schemas/attestation-v1.schema.json \
  schemas/wp3-corpus-v1.schema.json \
  schemas/preflight-request-v1.schema.json schemas/preflight-result-v1.schema.json \
  schemas/capability-report-v1.schema.json schemas/wp4-corpus-v1.schema.json \
  "$output/payload/schemas/"
cp integrity/protocol/v1/diagnostics.json "$output/payload/integrity/protocol/v1/"
cp integrity/testdata/manifests/current-feature.json "$output/payload/integrity/testdata/smoke/"
cp integrity/testdata/manifests/legacy.json "$output/payload/integrity/testdata/smoke/"
cp integrity/testdata/legacy/inventory-v1.json "$output/payload/integrity/testdata/legacy/"
cp -R integrity/testdata/revision/v1/. "$output/payload/integrity/testdata/revision/v1/"
cp -R integrity/testdata/adapter/v1/. "$output/payload/integrity/testdata/adapter/v1/"

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

bash scripts/package-codex-plugin.sh --output "$output/codex"

claude_paths=(
  ".claude-plugin"
  "skills"
  "commands"
  "agents"
  "templates"
  "config"
  "hooks"
  "docs/manifest-schema.md"
  "docs/grilling-playbook.md"
  "README.md"
  "LICENSE"
)
mkdir -p "$output/claude"
for rel in "${claude_paths[@]}"; do
  mkdir -p "$output/claude/$(dirname "$rel")"
  cp -R "$rel" "$output/claude/$rel"
done

for host in claude codex; do
  cp -R "$output/payload/." "$output/$host/"
done

for rel in \
  "bin/$exe" \
  "bin/$integrity_exe" \
  "schemas/manifest-v1.schema.json" \
  "schemas/golden-vector-v1.schema.json" \
  "schemas/doctor-result-v1.schema.json" \
  "schemas/migration-plan-v1.schema.json" \
  "schemas/code-revision-v1.schema.json" \
  "schemas/attestation-v1.schema.json" \
  "schemas/wp3-corpus-v1.schema.json" \
  "schemas/preflight-request-v1.schema.json" \
  "schemas/preflight-result-v1.schema.json" \
  "schemas/capability-report-v1.schema.json" \
  "schemas/wp4-corpus-v1.schema.json" \
  "integrity/protocol/v1/diagnostics.json" \
  "integrity/testdata/smoke/current-feature.json" \
  "integrity/testdata/smoke/legacy.json" \
  "integrity/testdata/legacy/inventory-v1.json" \
  "integrity/testdata/revision/v1/index.json" \
  "integrity/testdata/revision/v1/canonical/basic.json" \
  "integrity/testdata/revision/v1/convergence/ready.json"; do
  cmp "$output/claude/$rel" "$output/codex/$rel"
done

for rel in \
  "integrity/testdata/adapter/v1/index.json"; do
  cmp "$output/claude/$rel" "$output/codex/$rel"
done

test -f "$output/claude/.claude-plugin/plugin.json"
test -f "$output/codex/.codex-plugin/plugin.json"
test -f "$output/claude/hooks/hooks.json"
test -f "$output/codex/adapters/codex/hooks/hooks.json"
if find "$output/claude/schemas" "$output/claude/integrity/protocol" \
    "$output/codex/schemas" "$output/codex/integrity/protocol" \
    -type f -name '*.go' -print -quit | grep -q .; then
  echo "FAIL: Go source leaked into a runtime package" >&2
  exit 1
fi
echo "PASS: assembled installable $target Claude/Codex packages with byte-identical integrity payloads"
