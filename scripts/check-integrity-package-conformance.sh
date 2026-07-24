#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

target="${1:?usage: $0 <target>}"
case "$target" in
  windows-*) exe=ff-integrity-classify.exe; integrity_exe=ff-integrity.exe ;;
  *) exe=ff-integrity-classify; integrity_exe=ff-integrity ;;
esac

package_root="dist/integrity/$target"
source_exe="$package_root/source/$exe"
claude_exe="$package_root/claude/bin/$exe"
codex_exe="$package_root/codex/bin/$exe"
source_integrity="$package_root/source/$integrity_exe"
claude_integrity="$package_root/claude/bin/$integrity_exe"
codex_integrity="$package_root/codex/bin/$integrity_exe"

mkdir -p "$package_root/source"
go build -trimpath -ldflags='-s -w -buildid=' -o "$source_exe" ./cmd/ff-integrity-classify
go build -trimpath -ldflags='-s -w -buildid=' -o "$source_integrity" ./cmd/ff-integrity

for candidate in "$source_exe" "$claude_exe" "$codex_exe" \
  "$source_integrity" "$claude_integrity" "$codex_integrity"; do
  [[ -f "$candidate" ]] || { echo "FAIL: missing executable $candidate" >&2; exit 1; }
  chmod +x "$candidate" 2>/dev/null || true
done

for input in integrity/testdata/manifests/*; do
  vector="$(basename "$input")"
  "$source_exe" < "$input" > "$package_root/source.out"
  "$claude_exe" < "$input" > "$package_root/claude.out"
  "$codex_exe" < "$input" > "$package_root/codex.out"
  cmp "$package_root/source.out" "$package_root/claude.out" ||
    { echo "FAIL: source/Claude output drift for $vector on $target" >&2; exit 1; }
  cmp "$package_root/source.out" "$package_root/codex.out" ||
    { echo "FAIL: source/Codex output drift for $vector on $target" >&2; exit 1; }
done

fixture_root="$package_root/wp2-fixture"
rm -rf "$fixture_root"
mkdir -p "$fixture_root/legacy"
cp integrity/testdata/manifests/legacy.json "$fixture_root/legacy/manifest.json"
for format in human json; do
  "$source_integrity" doctor --root "$fixture_root" --format "$format" legacy > "$package_root/source-doctor.out" || test "$?" -eq 1
  "$claude_integrity" doctor --root "$fixture_root" --format "$format" legacy > "$package_root/claude-doctor.out" || test "$?" -eq 1
  "$codex_integrity" doctor --root "$fixture_root" --format "$format" legacy > "$package_root/codex-doctor.out" || test "$?" -eq 1
  cmp "$package_root/source-doctor.out" "$package_root/claude-doctor.out"
  cmp "$package_root/source-doctor.out" "$package_root/codex-doctor.out"
done
"$source_integrity" migrate --root "$fixture_root" --to 1 --dry-run --format json legacy > "$package_root/source-plan.out"
"$claude_integrity" migrate --root "$fixture_root" --to 1 --dry-run --format json legacy > "$package_root/claude-plan.out"
"$codex_integrity" migrate --root "$fixture_root" --to 1 --dry-run --format json legacy > "$package_root/codex-plan.out"
cmp "$package_root/source-plan.out" "$package_root/claude-plan.out"
cmp "$package_root/source-plan.out" "$package_root/codex-plan.out"

for operation in revision converge; do
  case "$operation" in
    revision) input="integrity/testdata/revision/v1/canonical/basic.json" ;;
    converge) input="integrity/testdata/revision/v1/convergence/ready.json" ;;
  esac
  "$source_integrity" "$operation" --input "$input" > "$package_root/source-wp3-$operation.out"
  "$claude_integrity" "$operation" --input "$input" > "$package_root/claude-wp3-$operation.out"
  "$codex_integrity" "$operation" --input "$input" > "$package_root/codex-wp3-$operation.out"
  cmp "$package_root/source-wp3-$operation.out" "$package_root/claude-wp3-$operation.out"
  cmp "$package_root/source-wp3-$operation.out" "$package_root/codex-wp3-$operation.out"
done

echo "PASS: source, Claude package, and Codex package match for WP1, WP2, and WP3 vectors on $target"
